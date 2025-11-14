import bpy
import os
import math

# --- CONFIGURACIÓN ---
camera_name = "Camera"  # Nombre de la cámara en tu escena
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
    cam = bpy.data.objects.get(camera_name)
    if not cam:
        print(f"No se encontró la cámara '{camera_name}'")
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

        # Ejecutar render de animación (usará la configuración actual de fotogramas)
        print(f"Renderizando fotogramas en carpeta: {folder_name} | Posición (X={params['pos'][0]}, Y={params['pos'][1]}) | RotZ={params['rot_z']}°")
        bpy.ops.render.render(animation=True)

# Ejecutar
render_frames()
