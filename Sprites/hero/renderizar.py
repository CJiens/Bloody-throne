bl_info = {
    "name": "Render Multi-Vistas (Cámara Activa)",
    "author": "Rolando",
    "version": (1, 0),
    "blender": (4, 5, 0),
    "location": "View3D > Object > Procesar",
    "description": "Renderiza animaciones desde múltiples posiciones usando la cámara activa",
    "category": "Render",
}

import bpy
import os
import math

# --- CONFIGURACIÓN ---
base_output_dir = bpy.path.abspath("//renders")  # Carpeta base

# Diccionario: clave = nombre de carpeta, valor = parámetros de cámara
# Posición: (x, y), Rotación Z en grados
render_configs = {
    "N": {"pos": (0, 15), "rot_z": -180},
    "S": {"pos": (0, -15), "rot_z": 0},
    "E": {"pos": (-15, 0), "rot_z": -90},
    "W": {"pos": (15, 0), "rot_z": 90},
    "NE": {"pos": (-10, 10), "rot_z": -135},
    "SE": {"pos": (-10, -10), "rot_z": -45},
    "NW": {"pos": (10, 10), "rot_z": 135},
    "SW": {"pos": (10, -10), "rot_z": 45},
}

def render_frames():
    # Tomar la cámara activa de la escena
    cam = bpy.context.scene.camera
    if not cam:
        print("No hay cámara activa en la escena.")
        return

    # Crear carpeta base si no existe
    if not os.path.exists(base_output_dir):
        os.makedirs(base_output_dir)

    for folder_name, params in render_configs.items():
        # Ajustar posición (X, Y) manteniendo Z fija
        cam.location.x = params["pos"][0]
        cam.location.y = params["pos"][1]
        # Rotación solo en Z (convertimos grados a radianes)
        cam.rotation_euler[2] = math.radians(params["rot_z"])

        # Carpeta de salida para este render
        output_dir = os.path.join(base_output_dir, folder_name)
        if not os.path.exists(output_dir):
            os.makedirs(output_dir)

        # Configurar ruta de salida de fotogramas
        bpy.context.scene.render.filepath = os.path.join(output_dir, "frame_")

        # Ejecutar render de animación
        print(f"Renderizando en carpeta: {folder_name} | Posición (X={params['pos'][0]}, Y={params['pos'][1]}) | RotZ={params['rot_z']}°")
        bpy.ops.render.render(animation=True)

# --- OPERADOR ---
class RENDER_OT_multi_views(bpy.types.Operator):
    bl_idname = "render.multi_views"
    bl_label = "Render Multi-Vistas (Cámara Activa)"
    bl_description = "Renderiza animaciones desde múltiples posiciones usando la cámara activa"

    def execute(self, context):
        render_frames()
        return {'FINISHED'}

# --- MENÚ ---
def menu_func(self, context):
    self.layout.operator(RENDER_OT_multi_views.bl_idname)

# --- REGISTRO ---
def register():
    bpy.utils.register_class(RENDER_OT_multi_views)
    bpy.types.VIEW3D_MT_object.append(menu_func)

def unregister():
    bpy.types.VIEW3D_MT_object.remove(menu_func)
    bpy.utils.unregister_class(RENDER_OT_multi_views)

if __name__ == "__main__":
    register()
