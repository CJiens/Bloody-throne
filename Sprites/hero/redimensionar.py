import os
from PIL import Image

def resize_images(root_dir, size=(512, 512)):
    # Recorre todas las carpetas y subcarpetas
    for dirpath, _, filenames in os.walk(root_dir):
        count = 1  # contador por carpeta
        for filename in sorted(filenames):
            # Filtrar solo imágenes comunes
            if filename.lower().endswith(('.png', '.jpg', '.jpeg', '.bmp', '.gif', '.tiff')):
                file_path = os.path.join(dirpath, filename)
                try:
                    with Image.open(file_path) as img:
                        # Redimensionar con antialiasing
                        img_resized = img.resize(size, Image.LANCZOS)

                        # Nombre nuevo con cero delante
                        new_name = f"{count:02d}.png"
                        new_path = os.path.join(dirpath, new_name)

                        # Guardar en el mismo directorio
                        img_resized.save(new_path)
                        print(f"Guardado: {new_path}")

                        count += 1
                except Exception as e:
                    print(f"Error con {file_path}: {e}")

if __name__ == "__main__":
    current_dir = os.getcwd()
    resize_images(current_dir)
