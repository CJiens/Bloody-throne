import os
from PIL import Image

def resize_and_replace_images(root_dir, size=(512, 512)):
    for dirpath, _, filenames in os.walk(root_dir):
        count = 1
        for filename in sorted(filenames):
            ext = os.path.splitext(filename)[1].lower()
            if ext in ('.png', '.jpg', '.jpeg', '.bmp', '.gif', '.tiff'):
                file_path = os.path.join(dirpath, filename)
                try:
                    with Image.open(file_path) as img:
                        img_resized = img.resize(size, Image.LANCZOS)

                        # Nuevo nombre con mismo formato
                        new_name = f"{count:02d}{ext}"
                        new_path = os.path.join(dirpath, new_name)

                        img_resized.save(new_path)
                        print(f"Guardado: {new_path}")

                        # Borrar original
                        os.remove(file_path)
                        print(f"Eliminado: {file_path}")

                        count += 1
                except Exception as e:
                    print(f"Error con {file_path}: {e}")

if __name__ == "__main__":
    current_dir = os.getcwd()
    resize_and_replace_images(current_dir)

