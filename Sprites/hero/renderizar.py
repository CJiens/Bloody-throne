bl_info = {
    "name": "Render Multi-Vistas (Cámara Activa)",
    "author": "Rolando",
    "version": (1, 6, 0),
    "blender": (4, 5, 0),
    "location": "Topbar > Procesar (Render)",
    "description": "Renderiza animaciones desde múltiples posiciones usando la cámara activa",
    "category": "Render",
}

import bpy
import os
import math
import traceback
from mathutils import Euler

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

# --- PROGRESS HANDLERS ---
_progress_state = {
    "total_frames": 0,
    "frames_done": 0,
    "active": False,
    "wm": None,
    "handler_write": None,
    "handler_pre": None,
    "handler_post": None,
    "handler_cancel": None
}

def _handler_render_pre(*args):
    try:
        wm = bpy.context.window_manager
        _progress_state["wm"] = wm
        if not _progress_state["active"]:
            _progress_state["frames_done"] = 0
            total = max(1, _progress_state.get("total_frames", 1))
            wm.progress_begin(0, total)
            _progress_state["active"] = True
    except Exception as e:
        print(f"[Multi-Vistas] render_pre handler error: {e}")

def _handler_render_write(*args):
    try:
        wm = _progress_state.get("wm") or bpy.context.window_manager
        _progress_state["frames_done"] += 1
        total = max(1, _progress_state.get("total_frames", 1))
        done = _progress_state["frames_done"]
        # Actualiza la barra de progreso
        wm.progress_update(done)
        print(f"[Multi-Vistas] Frame escrito {done}/{total}")
    except Exception as e:
        print(f"[Multi-Vistas] render_write handler error: {e}")

def _handler_render_post(*args):
    try:
        wm = _progress_state.get("wm") or bpy.context.window_manager
        if _progress_state["active"]:
            wm.progress_end()
        _progress_state["active"] = False
        _progress_state["frames_done"] = 0
        _progress_state["total_frames"] = 0
    except Exception as e:
        print(f"[Multi-Vistas] render_post handler error: {e}")
    finally:
        _unregister_handlers()

def _handler_render_cancel(*args):
    try:
        wm = _progress_state.get("wm") or bpy.context.window_manager
        if _progress_state["active"]:
            wm.progress_end()
        _progress_state["active"] = False
    except Exception as e:
        print(f"[Multi-Vistas] render_cancel handler error: {e}")
    finally:
        _unregister_handlers()

def _register_handlers():
    import bpy.app.handlers as handlers
    if _progress_state["handler_pre"] is None:
        _progress_state["handler_pre"] = _handler_render_pre
        handlers.render_pre.append(_progress_state["handler_pre"])
    if _progress_state["handler_write"] is None:
        _progress_state["handler_write"] = _handler_render_write
        handlers.render_write.append(_progress_state["handler_write"])
    if _progress_state["handler_post"] is None:
        _progress_state["handler_post"] = _handler_render_post
        handlers.render_post.append(_progress_state["handler_post"])
    if _progress_state["handler_cancel"] is None:
        _progress_state["handler_cancel"] = _handler_render_cancel
        handlers.render_cancel.append(_progress_state["handler_cancel"])

def _unregister_handlers():
    import bpy.app.handlers as handlers
    try:
        if _progress_state["handler_write"] and _progress_state["handler_write"] in handlers.render_write:
            handlers.render_write.remove(_progress_state["handler_write"])
    except Exception:
        pass
    try:
        if _progress_state["handler_pre"] and _progress_state["handler_pre"] in handlers.render_pre:
            handlers.render_pre.remove(_progress_state["handler_pre"])
    except Exception:
        pass
    try:
        if _progress_state["handler_post"] and _progress_state["handler_post"] in handlers.render_post:
            handlers.render_post.remove(_progress_state["handler_post"])
    except Exception:
        pass
    try:
        if _progress_state["handler_cancel"] and _progress_state["handler_cancel"] in handlers.render_cancel:
            handlers.render_cancel.remove(_progress_state["handler_cancel"])
    except Exception:
        pass
    _progress_state["handler_write"] = None
    _progress_state["handler_pre"] = None
    _progress_state["handler_post"] = None
    _progress_state["handler_cancel"] = None

# --- UTILIDADES ---
def ensure_dir(path: str):
    try:
        os.makedirs(path, exist_ok=True)
    except Exception as e:
        raise RuntimeError(f"No se pudo crear la carpeta: {path} -> {e}")

def resolve_base_output_dir(relpath: str) -> str:
    try:
        resolved = bpy.path.abspath(relpath)
    except Exception:
        resolved = ""
    if not resolved:
        home = os.path.expanduser("~") or os.getcwd()
        resolved = os.path.join(home, "renders_blender")
    return os.path.normpath(resolved)

def set_render_basics(scene: bpy.types.Scene, output_dir: str, file_basename: str = "frame_"):
    scene.render.image_settings.file_format = 'PNG'
    scene.render.filepath = os.path.normpath(os.path.join(output_dir, file_basename))

def disable_constraints_temporarily(obj: bpy.types.Object):
    prev_states = []
    if not obj.constraints:
        return prev_states
    for c in obj.constraints:
        prev_states.append((c, c.muted))
        c.muted = True
    return prev_states

def restore_constraints(prev_states):
    for c, muted in prev_states:
        try:
            c.muted = muted
        except Exception:
            pass

# --- LÓGICA PRINCIPAL ---
def render_frames(context: bpy.types.Context, base_output_dir_rel: str, configs: dict, disable_constraints: bool = False):
    scene = context.scene
    cam = scene.camera
    if cam is None:
        print("[Multi-Vistas] No hay cámara activa en la escena")
        return {'CANCELLED'}

    base_output_dir = resolve_base_output_dir(base_output_dir_rel)
    try:
        ensure_dir(base_output_dir)
    except RuntimeError as e:
        print(f"[Multi-Vistas] {e}")
        return {'CANCELLED'}

    orig_location = cam.location.copy()
    orig_rotation_mode = cam.rotation_mode
    orig_rotation = cam.rotation_euler.copy()

    for folder_name, params in configs.items():
        output_dir = os.path.join(base_output_dir, folder_name)
        try:
            ensure_dir(output_dir)
        except RuntimeError as e:
            print(f"[Multi-Vistas] {e}")
            continue

        cam.location.x = params["pos"][0]
        cam.location.y = params["pos"][1]

        cam.rotation_mode = 'XYZ'
        cam.rotation_euler = Euler((cam.rotation_euler.x, cam.rotation_euler.y, math.radians(params["rot_z"])), 'XYZ')

        prev_constraints = []
        if disable_constraints:
            prev_constraints = disable_constraints_temporarily(cam)

        frame_start = scene.frame_start
        frame_end = scene.frame_end
        total_frames = max(1, frame_end - frame_start + 1)
        _progress_state["total_frames"] = total_frames
        _progress_state["frames_done"] = 0
        _register_handlers()

        set_render_basics(scene, output_dir, "frame_")
        print(f"[Multi-Vistas] Renderizando {folder_name}: {total_frames} frames -> {output_dir}")

        try:
            bpy.ops.render.render(animation=True)
        except Exception as e:
            print(f"[Multi-Vistas] Error renderizando {folder_name}: {e}")
            _handler_render_cancel()
            if prev_constraints:
                restore_constraints(prev_constraints)
            continue

        if prev_constraints:
            restore_constraints(prev_constraints)

    cam.location = orig_location
    cam.rotation_mode = orig_rotation_mode
    cam.rotation_euler = orig_rotation

    return {'FINISHED'}

# --- PREFERENCIAS DEL ADDON ---
class RENDERUIPrefs(bpy.types.AddonPreferences):
    bl_idname = __name__

    base_output_dir: bpy.props.StringProperty(
        name="Carpeta base",
        description="Carpeta base de salida (puede ser relativa al .blend, e.g. //renders)",
        default=BASE_OUTPUT_DIR_DEFAULT,
        subtype='DIR_PATH'
    )

    disable_camera_constraints: bpy.props.BoolProperty(
        name="Deshabilitar constraints de cámara durante render",
        default=False,
        description="Deshabilita temporalmente constraints de la cámara para que la rotación/posición aplicada no sea sobrescrita"
    )

    def draw(self, context):
        layout = self.layout
        layout.prop(self, "base_output_dir")
        layout.prop(self, "disable_camera_constraints")

# --- OPERADOR (con captura de excepciones y logging) ---
class RENDER_OT_multi_views(bpy.types.Operator):
    bl_idname = "render.multi_views"
    bl_label = "Render Multi-Vistas (Cámara Activa)"
    bl_description = "Renderiza animaciones desde múltiples posiciones usando la cámara activa"
    bl_options = {'REGISTER', 'UNDO'}

    base_output_dir: bpy.props.StringProperty(
        name="Carpeta base (anular pref.)",
        description="Si se rellena, esta ruta anula la preferencia del addon (acepta rutas relativas //)",
        default="",
        subtype='DIR_PATH'
    )
    disable_constraints: bpy.props.BoolProperty(
        name="Deshabilitar constraints",
        default=False
    )

    def execute(self, context):
        try:
            prefs = context.preferences.addons.get(__name__)
            if prefs and hasattr(prefs, "preferences") and isinstance(prefs.preferences, RENDERUIPrefs):
                addon_prefs: RENDERUIPrefs = prefs.preferences
                base_dir_rel = self.base_output_dir if self.base_output_dir else addon_prefs.base_output_dir
                disable_constraints = self.disable_constraints or addon_prefs.disable_camera_constraints
            else:
                base_dir_rel = self.base_output_dir or BASE_OUTPUT_DIR_DEFAULT
                disable_constraints = self.disable_constraints

            if not context.scene.camera:
                self.report({'ERROR'}, "No hay cámara activa en la escena")
                return {'CANCELLED'}

            result = render_frames(context, base_dir_rel, RENDER_CONFIGS, disable_constraints)

            if isinstance(result, set) or isinstance(result, dict):
                if 'FINISHED' in result:
                    self.report({'INFO'}, "Multi-vistas finalizado")
                    return {'FINISHED'}
                else:
                    self.report({'ERROR'}, "Multi-vistas cancelado (ver consola y log)")
                    return {'CANCELLED'}

            return {'FINISHED'}

        except Exception:
            tb = traceback.format_exc()
            print("[Multi-Vistas] EXCEPCION NO CONTROLADA:\n", tb)
            logfile = os.path.join(os.path.expanduser("~"), "multi_vistas_error.log")
            try:
                with open(logfile, "a", encoding="utf-8") as f:
                    f.write("\n\n--- Exception at run ---\n")
                    f.write(tb)
            except Exception as e:
                print("[Multi-Vistas] No se pudo escribir el log:", e)
            self.report({'ERROR'}, f"Multi-vistas fallo (ver consola y {logfile})")
            return {'CANCELLED'}

# --- Añadir al menú Render (Procesar) ---
def menu_func_render(self, context):
    layout = self.layout
    layout.separator()
    layout.operator(RENDER_OT_multi_views.bl_idname, icon='RENDER_ANIMATION')

# --- REGISTRO ---
classes = (
    RENDERUIPrefs,
    RENDER_OT_multi_views,
)

def register():
    for cls in classes:
        bpy.utils.register_class(cls)
    try:
        bpy.types.TOPBAR_MT_render.append(menu_func_render)
    except Exception as e:
        print(f"[Multi-Vistas] No se pudo añadir al menú Procesar: {e}")

def unregister():
    try:
        bpy.types.TOPBAR_MT_render.remove(menu_func_render)
    except Exception:
        pass
    for cls in reversed(classes):
        try:
            bpy.utils.unregister_class(cls)
        except Exception:
            pass
    _unregister_handlers()

if __name__ == "__main__":
    register()