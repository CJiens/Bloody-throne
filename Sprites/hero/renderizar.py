bl_info = {
    "name": "Render Multi-Vistas (Modal)",
    "author": "Rolando",
    "version": (1, 7, 7),
    "blender": (4, 5, 0),
    "location": "Topbar > Procesar (Render); Properties > Output",
    "description": "Renderiza animaciones desde múltiples posiciones.",
    "category": "Render",
}

import bpy
import os
import traceback
from mathutils import Euler
from math import radians

# --- CONFIG POR DEFECTO ---
BASE_OUTPUT_DIR_DEFAULT = "//renders"

RENDER_CONFIGS = {
    "N":  {"pos": (0, 15),   "rot_z": -180},
    "S":  {"pos": (0, -15),  "rot_z": 0},
    "E":  {"pos": (-15, 0),  "rot_z": -90},
    "W":  {"pos": (15, 0),   "rot_z": 90},
    "NE": {"pos": (-10, 10), "rot_z": -135},
    "SE": {"pos": (-10, -10),"rot_z": -45},
    "NW": {"pos": (10, 10),  "rot_z": 135},
    "SW": {"pos": (10, -10), "rot_z": 45},
}

# --- PROPS (panel/state) ---
class MultiVistasProps(bpy.types.PropertyGroup):
    current_direction: bpy.props.StringProperty(name="Dirección actual", default="")
    current_frame: bpy.props.IntProperty(name="Frame actual", default=0)
    total_frames: bpy.props.IntProperty(name="Total frames", default=0)
    status: bpy.props.StringProperty(name="Estado", default="Esperando…")
    progress: bpy.props.FloatProperty(name="Progreso", default=0.0, min=0.0, max=1.0)
    base_output: bpy.props.StringProperty(name="Carpeta base", default=BASE_OUTPUT_DIR_DEFAULT, subtype='DIR_PATH')
    disable_constraints: bpy.props.BoolProperty(name="Deshabilitar constraints de cámara", default=False)

# --- UTILIDADES ---
def resolve_base_output_dir(relpath: str) -> str:
    try:
        return os.path.normpath(bpy.path.abspath(relpath))
    except Exception:
        home = os.path.expanduser("~") or os.getcwd()
        return os.path.join(home, "renders_blender")

def ensure_dir(path: str):
    os.makedirs(path, exist_ok=True)

def _redraw_ui():
    wm = bpy.context.window_manager
    for window in wm.windows:
        for area in window.screen.areas:
            if area.type in {'VIEW_3D', 'PROPERTIES', 'IMAGE_EDITOR'}:
                area.tag_redraw()

def disable_constraints_temporarily(obj):
    prev = []
    if not obj or not hasattr(obj, "constraints"):
        return prev
    for c in obj.constraints:
        prev.append((c, c.muted))
        try:
            c.muted = True
        except Exception:
            pass
    return prev

def restore_constraints(prev):
    for c, muted in prev:
        try:
            c.muted = muted
        except Exception:
            pass

# --- HANDLERS para barra de progreso del sistema (opcional) ---
_progress_state = {"total_frames": 0, "frames_done": 0, "active": False, "wm": None}
def _progress_begin(total):
    try:
        wm = bpy.context.window_manager
        _progress_state["wm"] = wm
        _progress_state["frames_done"] = 0
        _progress_state["total_frames"] = max(1, total)
        wm.progress_begin(0, _progress_state["total_frames"])
        _progress_state["active"] = True
    except Exception:
        _progress_state["active"] = False

def _progress_update_one():
    try:
        if not _progress_state["active"]:
            return
        _progress_state["frames_done"] += 1
        wm = _progress_state.get("wm") or bpy.context.window_manager
        wm.progress_update(_progress_state["frames_done"])
    except Exception:
        pass

def _progress_end():
    try:
        if _progress_state["active"]:
            wm = _progress_state.get("wm") or bpy.context.window_manager
            wm.progress_end()
    except Exception:
        pass
    _progress_state["active"] = False
    _progress_state["frames_done"] = 0
    _progress_state["total_frames"] = 0
    _progress_state["wm"] = None

# --- ESTADO GLOBAL DEL MODAL ---
class MV_State:
    running = False
    cancel = False
    configs_iter = None
    current_dir = None
    output_dir = None
    frame_iter = None
    base_output = None
    cam_orig = None
    cam_rot_mode = None
    cam_orig_rot = None
    orig_filepath = None
    scene = None
    props = None
    prev_constraints = None
    timer = None
    total_frames_current = 0

# --- UTILIDADES SEGURAS PARA PROPS ---
def _safe_get_props(context):
    if MV_State.props is not None:
        return MV_State.props
    try:
        return context.scene.multi_vistas_props
    except Exception:
        return None

def _safe_set_status(context, text):
    props = _safe_get_props(context)
    if props is not None:
        try:
            props.status = text
        except Exception:
            pass

# --- FUNCIONES DE RANGOS RESPETANDO frame_step y preview range ---
def _get_frame_range(scene):
    if getattr(scene, "use_preview_range", False):
        start = scene.frame_preview_start
        end = scene.frame_preview_end
    else:
        start = scene.frame_start
        end = scene.frame_end
    step = max(1, getattr(scene, "frame_step", 1))
    return start, end, step

def _count_frames_in_range(start, end, step):
    if end < start:
        return 0
    return ((end - start) // step) + 1

# --- OPERADOR MODAL (principal) ---
class RENDER_OT_multi_views_modal(bpy.types.Operator):
    bl_idname = "render.multi_views_modal"
    bl_label = "Render Multi‑Vistas (Modal)"
    bl_description = "Renderiza animación por vistas sin alterar ajustes (respeta frame_step y preview range)"
    bl_options = {'REGISTER'}

    def invoke(self, context, event):
        scene = context.scene
        props = _safe_get_props(context)

        if scene.camera is None:
            self.report({'ERROR'}, "No hay cámara activa")
            if props: props.status = "❌ No hay cámara activa"
            return {'CANCELLED'}

        if MV_State.running:
            self.report({'WARNING'}, "Ya hay un render en curso")
            return {'CANCELLED'}

        MV_State.running = True
        MV_State.cancel = False
        MV_State.scene = scene
        MV_State.props = props
        MV_State.base_output = resolve_base_output_dir(props.base_output if props else BASE_OUTPUT_DIR_DEFAULT)

        cam = scene.camera
        MV_State.cam_orig = cam.location.copy()
        MV_State.cam_rot_mode = cam.rotation_mode
        MV_State.cam_orig_rot = cam.rotation_euler.copy()
        MV_State.orig_filepath = scene.render.filepath
        MV_State.prev_constraints = None

        MV_State.configs_iter = iter(RENDER_CONFIGS.items())
        MV_State.frame_iter = None

        try:
            ensure_dir(MV_State.base_output)
        except Exception as e:
            if props: props.status = f"❌ Error creando carpeta base: {e}"
            MV_State.running = False
            return {'CANCELLED'}

        MV_State.timer = context.window_manager.event_timer_add(0.12, window=context.window)
        context.window_manager.modal_handler_add(self)
        if props: props.status = "Iniciando multi‑vistas…"
        _redraw_ui()
        return {'RUNNING_MODAL'}

    def modal(self, context, event):
        # manejador principal: silencioso ante cancelación por usuario
        try:
            if event.type == 'TIMER':
                # si estamos procesando frames actuales
                if MV_State.frame_iter is not None:
                    try:
                        frame = next(MV_State.frame_iter)
                    except StopIteration:
                        _progress_end()
                        props = _safe_get_props(context)
                        if props:
                            props.status = f"✔ Dirección {MV_State.current_dir} completada"
                            props.progress = 1.0
                        MV_State.frame_iter = None
                        MV_State.current_dir = None
                        _redraw_ui()
                        return {'PASS_THROUGH'}

                    if MV_State.cancel:
                        # limpieza silenciosa y mensaje claro
                        try:
                            self._cleanup(context)
                        except Exception:
                            print("[Multi-Vistas] Limpieza tras cancelación fallo (ignorado)")
                        try:
                            self.report({'INFO'}, "Render cancelado por el usuario")
                        except Exception:
                            pass
                        _safe_set_status(context, "✖ Cancelado por usuario")
                        return {'CANCELLED'}

                    # --- render del frame ---
                    scene = MV_State.scene
                    props = _safe_get_props(context)
                    if props:
                        props.current_frame = frame

                    # colocar la línea de tiempo en el frame correcto
                    try:
                        scene.frame_set(frame)
                    except Exception:
                        try:
                            scene.frame_current = frame
                        except Exception:
                            pass

                    # forzar update por drivers/modifiers
                    try:
                        bpy.context.view_layer.update()
                    except Exception:
                        pass

                    # filepath con número de frame para evitar sobrescrituras
                    try:
                        scene.render.filepath = os.path.normpath(os.path.join(MV_State.output_dir, f"frame_{frame:04d}"))
                    except Exception:
                        pass
                    _redraw_ui()

                    # renderizar un frame (bloqueante por frame)
                    try:
                        bpy.ops.render.render(write_still=True)
                    except Exception as e:
                        print("[Multi-Vistas] ERROR renderizando frame:", e)
                        _safe_set_status(context, f"❌ Error frame {frame}")

                    # actualizar progreso (panel + barra sistema)
                    fs, fe, step = _get_frame_range(scene)
                    total = _count_frames_in_range(fs, fe, step) or 1
                    props = _safe_get_props(context)
                    if props:
                        props.total_frames = total
                        index = ((frame - fs) // step) + 1
                        props.progress = index / total
                    _progress_update_one()
                    _redraw_ui()
                    return {'PASS_THROUGH'}

                # iniciar próxima dirección
                try:
                    direccion, params = next(MV_State.configs_iter)
                except StopIteration:
                    # todo finalizado
                    try:
                        self._cleanup(context)
                    except Exception:
                        pass
                    _safe_set_status(context, "✅ Multi‑vistas finalizado")
                    MV_State.running = False
                    return {'FINISHED'}

                MV_State.current_dir = direccion
                MV_State.output_dir = os.path.normpath(os.path.join(MV_State.base_output, direccion))
                try:
                    ensure_dir(MV_State.output_dir)
                except Exception as e:
                    _safe_set_status(context, f"❌ Error carpeta {direccion}: {e}")
                    _redraw_ui()
                    return {'PASS_THROUGH'}

                cam = MV_State.scene.camera
                props = _safe_get_props(context)
                if props and props.disable_constraints:
                    MV_State.prev_constraints = disable_constraints_temporarily(cam)
                else:
                    MV_State.prev_constraints = None

                cam.location.x = params["pos"][0]
                cam.location.y = params["pos"][1]
                cam.rotation_mode = 'XYZ'
                cam.rotation_euler = Euler((cam.rotation_euler.x, cam.rotation_euler.y, radians(params["rot_z"])), 'XYZ')

                # construir iterador usando frame_step y preview range
                fs, fe, step = _get_frame_range(MV_State.scene)
                total_frames = _count_frames_in_range(fs, fe, step)
                MV_State.total_frames_current = total_frames
                props = _safe_get_props(context)
                if props:
                    props.total_frames = total_frames
                    props.current_direction = direccion
                    props.status = f"Renderizando {direccion}…"
                    props.progress = 0.0
                MV_State.frame_iter = iter(range(fs, fe + 1, step))

                # iniciar barra progreso para esta dirección
                _progress_begin(total_frames)

                _redraw_ui()
                return {'PASS_THROUGH'}

            # si el usuario pulsa Esc durante otras interacciones:
            if event.type in {'ESC'}:
                MV_State.cancel = True
                _safe_set_status(context, "Cancelando…")
                _redraw_ui()
                return {'RUNNING_MODAL'}

            return {'PASS_THROUGH'}

        except Exception:
            tb = traceback.format_exc()
            # Si fue provocado por cancelación del usuario, no mostrar traceback al usuario
            if MV_State.cancel:
                try:
                    self._cleanup(context)
                except Exception:
                    print("[Multi-Vistas] _cleanup fallo tras excepción (ignorado)")
                try:
                    self.report({'INFO'}, "Render cancelado por el usuario")
                except Exception:
                    pass
                _safe_set_status(context, "✖ Cancelado por usuario")
                return {'CANCELLED'}
            # Para cualquier otra excepción, registrar y limpiar
            print("[Multi-Vistas] EXCEPCIÓN modal:\n", tb)
            _safe_set_status(context, "❌ Error inesperado")
            try:
                self._cleanup(context)
            except Exception:
                print("[Multi-Vistas] _cleanup fallo tras excepción (ignorado)")
            return {'CANCELLED'}

    def _cleanup(self, context):
        # Restaurar cámara y filepath y limpiar estado (silencioso)
        try:
            if MV_State.scene and MV_State.scene.camera and MV_State.cam_orig is not None:
                cam = MV_State.scene.camera
                cam.location = MV_State.cam_orig
                cam.rotation_mode = MV_State.cam_rot_mode
                cam.rotation_euler = MV_State.cam_orig_rot
        except Exception as e:
            print("[Multi-Vistas] ERROR restaurando cámara (ignorado):", e)
        try:
            if MV_State.scene and MV_State.orig_filepath is not None:
                MV_State.scene.render.filepath = MV_State.orig_filepath
        except Exception as e:
            print("[Multi-Vistas] ERROR restaurando render.filepath (ignorado):", e)

        if MV_State.prev_constraints:
            try:
                restore_constraints(MV_State.prev_constraints)
            except Exception as e:
                print("[Multi-Vistas] ERROR restaurando constraints (ignorado):", e)
            MV_State.prev_constraints = None

        _progress_end()

        if MV_State.timer:
            try:
                context.window_manager.event_timer_remove(MV_State.timer)
            except Exception:
                pass
            MV_State.timer = None

        # reset estado
        MV_State.running = False
        MV_State.cancel = False
        MV_State.configs_iter = None
        MV_State.frame_iter = None
        MV_State.current_dir = None
        MV_State.output_dir = None
        MV_State.base_output = None
        MV_State.cam_orig = None
        MV_State.cam_orig_rot = None
        MV_State.cam_rot_mode = None
        MV_State.orig_filepath = None
        MV_State.scene = None
        MV_State.props = None
        MV_State.total_frames_current = 0
        _redraw_ui()

    def cancel(self, context):
        # llamado por Blender si el operador se cancela de forma externa
        MV_State.cancel = True
        try:
            self._cleanup(context)
        except Exception:
            print("[Multi-Vistas] cancel: _cleanup fallo (ignorado)")

# --- Operador simple para compatibilidad con menú antiguo ---
class RENDER_OT_multi_views_legacy(bpy.types.Operator):
    bl_idname = "render.multi_views_legacy"
    bl_label = "Render Multi‑Vistas (rápido)"
    bl_description = "Llama al operador modal que renderiza por vistas (mantiene compatibilidad)"
    bl_options = {'REGISTER'}

    base_output_dir: bpy.props.StringProperty(name="Carpeta base (anular pref.)", default="", subtype='DIR_PATH')
    disable_constraints: bpy.props.BoolProperty(name="Deshabilitar constraints", default=False)

    def execute(self, context):
        props = _safe_get_props(context)
        if self.base_output_dir and props:
            props.base_output = self.base_output_dir
        if props:
            props.disable_constraints = self.disable_constraints
        bpy.ops.render.multi_views_modal('INVOKE_DEFAULT')
        return {'FINISHED'}

# --- PANEL (usando nombre compatible) ---
class RENDER_PT_multi_vistas_panel(bpy.types.Panel):
    bl_label = "Progreso Multi‑Vistas"
    bl_idname = "RENDER_PT_multi_vistas_panel"
    bl_space_type = 'PROPERTIES'
    bl_region_type = 'WINDOW'
    bl_context = "output"

    def draw(self, context):
        props = _safe_get_props(context)
        layout = self.layout

        row = layout.row()
        if not MV_State.running:
            row.operator(RENDER_OT_multi_views_modal.bl_idname, text="Iniciar Multi‑Vistas", icon='RENDER_ANIMATION')
        else:
            row.operator("render.multi_views_cancel2", text="Cancelar", icon='CANCEL')
        layout.separator()
        if props:
            layout.prop(props, "base_output", text="Carpeta base")
            layout.prop(props, "disable_constraints", text="Deshabilitar constraints")
        else:
            layout.label(text="No hay propiedades disponibles")
        layout.separator()
        if props:
            layout.label(text=f"Dirección: {props.current_direction}")
            # Barra + porcentaje en formato "01.50%"
            row = layout.row(align=True)
            row.prop(props, "progress", text="")
            pct = f"{props.progress * 100:06.2f}%"
            row.label(text=pct)
            layout.prop(props, "current_frame", text="Frame")
            layout.prop(props, "total_frames", text="Total")
            layout.separator()
            layout.label(text=f"Estado: {props.status}")
        else:
            layout.label(text="Estado: desconocido")

# --- Operador Cancel (UI) - muestra mensaje limpio ---
class RENDER_OT_multi_views_cancel2(bpy.types.Operator):
    bl_idname = "render.multi_views_cancel2"
    bl_label = "Cancelar Multi‑Vistas"
    bl_options = {'INTERNAL'}

    def execute(self, context):
        if MV_State.running:
            MV_State.cancel = True
            props = _safe_get_props(context)
            if props:
                props.status = "Cancelando…"
            _redraw_ui()
            self.report({'INFO'}, "Operación de render cancelada por el usuario")
            return {'FINISHED'}
        else:
            self.report({'INFO'}, "No hay operación en curso para cancelar")
            return {'CANCELLED'}

# --- MENU TOPBAR ---
def menu_func_render(self, context):
    self.layout.separator()
    self.layout.operator(RENDER_OT_multi_views_legacy.bl_idname, icon='RENDER_ANIMATION')

# --- REGISTRO ---
classes = (
    MultiVistasProps,
    RENDER_OT_multi_views_modal,
    RENDER_OT_multi_views_legacy,
    RENDER_PT_multi_vistas_panel,
    RENDER_OT_multi_views_cancel2,
)

def register():
    for cls in classes:
        bpy.utils.register_class(cls)
    bpy.types.Scene.multi_vistas_props = bpy.props.PointerProperty(type=MultiVistasProps)
    try:
        bpy.types.TOPBAR_MT_render.append(menu_func_render)
    except Exception:
        pass

def unregister():
    try:
        bpy.types.TOPBAR_MT_render.remove(menu_func_render)
    except Exception:
        pass
    if hasattr(bpy.types.Scene, "multi_vistas_props"):
        del bpy.types.Scene.multi_vistas_props
    for cls in reversed(classes):
        try:
            bpy.utils.unregister_class(cls)
        except Exception:
            pass

if __name__ == "__main__":
    register()
