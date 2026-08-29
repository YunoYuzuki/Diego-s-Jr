"""
Redimensiona todas as texturas de uma pasta para o tamanho alvo (256x256 por padrão).
Mantém os originais e salva as versões redimensionadas numa pasta separada.

Uso:
    python resize_textures.py
    python resize_textures.py --input ./textures --output ./textures_256 --size 256
    python resize_textures.py --size 128   # para 128x128

Requisitos:
    pip install Pillow
"""

import argparse
import os
from pathlib import Path
from PIL import Image

SUPPORTED = {".png", ".jpg", ".jpeg", ".bmp", ".tga", ".webp"}

def resize_textures(input_dir: str, output_dir: str, size: int):
    input_path = Path(input_dir)
    output_path = Path(output_dir)
    output_path.mkdir(parents=True, exist_ok=True)

    files = [f for f in input_path.rglob("*") if f.suffix.lower() in SUPPORTED]

    if not files:
        print(f"Nenhuma textura encontrada em: {input_path}")
        return

    print(f"Encontradas {len(files)} texturas. Redimensionando para {size}x{size}...\n")

    for f in files:
        try:
            img = Image.open(f)
            original_size = img.size

            # Mantém estrutura de subpastas
            relative = f.relative_to(input_path)
            dest = output_path / relative
            dest.parent.mkdir(parents=True, exist_ok=True)

            # Redimensiona com NEAREST (mantém look pixelado, sem blur)
            resized = img.resize((size, size), Image.NEAREST)
            resized.save(dest)

            print(f"  {relative}  {original_size[0]}x{original_size[1]} -> {size}x{size}")
        except Exception as e:
            print(f"  ERRO em {f.name}: {e}")

    print(f"\nPronto! Texturas salvas em: {output_path.resolve()}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Redimensiona texturas em lote")
    parser.add_argument("--input",  default="./textures",      help="Pasta com as texturas originais")
    parser.add_argument("--output", default="./textures_256",  help="Pasta de destino")
    parser.add_argument("--size",   default=256, type=int,     help="Tamanho alvo (256 ou 128)")
    args = parser.parse_args()

    resize_textures(args.input, args.output, args.size)
