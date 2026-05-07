#!/usr/bin/env python3
"""Genera el set completo de iconos para Marker.app.

Diseño: squircle oscuro #1B202A + letra "M" blanca centrada.
Salida: PNGs dentro de Marker/Assets.xcassets/AppIcon.appiconset/.

Edita las constantes BG_COLOR / FG_COLOR / TEXT y vuelve a ejecutar
para cambiar el diseño.
"""
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "Marker", "Assets.xcassets")
APPICON_SET = os.path.join(ASSETS, "AppIcon.appiconset")

BASE_SIZE = 1024
BG_COLOR = (27, 32, 42, 255)        # #1B202A — gris oscuro azulado
FG_COLOR = (255, 255, 255, 255)
RADIUS_PCT = 0.2237                 # squircle de macOS aprox.
TEXT = "M"

# Tamaños del Contents.json del asset catalog: (filename, pixel_size).
ICON_FILES = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

CONTENTS = {
    "images": [
        {"idiom": "mac", "scale": "1x", "size": "16x16",   "filename": "icon_16x16.png"},
        {"idiom": "mac", "scale": "2x", "size": "16x16",   "filename": "icon_16x16@2x.png"},
        {"idiom": "mac", "scale": "1x", "size": "32x32",   "filename": "icon_32x32.png"},
        {"idiom": "mac", "scale": "2x", "size": "32x32",   "filename": "icon_32x32@2x.png"},
        {"idiom": "mac", "scale": "1x", "size": "128x128", "filename": "icon_128x128.png"},
        {"idiom": "mac", "scale": "2x", "size": "128x128", "filename": "icon_128x128@2x.png"},
        {"idiom": "mac", "scale": "1x", "size": "256x256", "filename": "icon_256x256.png"},
        {"idiom": "mac", "scale": "2x", "size": "256x256", "filename": "icon_256x256@2x.png"},
        {"idiom": "mac", "scale": "1x", "size": "512x512", "filename": "icon_512x512.png"},
        {"idiom": "mac", "scale": "2x", "size": "512x512", "filename": "icon_512x512@2x.png"},
    ],
    "info": {"version": 1, "author": "xcode"},
}


def load_font(point_size):
    candidates = [
        ("/System/Library/Fonts/HelveticaNeue.ttc", 1),     # Bold
        ("/System/Library/Fonts/Helvetica.ttc", 1),         # Bold
        ("/System/Library/Fonts/Avenir Next.ttc", 1),       # Demi Bold
        ("/System/Library/Fonts/SFCompact.ttf", 0),
        ("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 0),
    ]
    for path, index in candidates:
        if os.path.isfile(path):
            try:
                return ImageFont.truetype(path, point_size, index=index)
            except (OSError, IOError):
                try:
                    return ImageFont.truetype(path, point_size)
                except (OSError, IOError):
                    continue
    return ImageFont.load_default()


def render_master():
    img = Image.new("RGBA", (BASE_SIZE, BASE_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    radius = int(BASE_SIZE * RADIUS_PCT)
    draw.rounded_rectangle([0, 0, BASE_SIZE, BASE_SIZE], radius=radius, fill=BG_COLOR)

    # Anchor "mm" centra el texto por su punto medio (visual), evitando los
    # offsets que mete textbbox según la métrica de la fuente.
    font = load_font(620)
    cx, cy = BASE_SIZE / 2, BASE_SIZE / 2
    draw.text(
        (cx, cy), TEXT, font=font, fill=FG_COLOR,
        anchor="mm",
        stroke_width=12, stroke_fill=FG_COLOR,
    )
    return img


def main():
    os.makedirs(APPICON_SET, exist_ok=True)
    master = render_master()

    for filename, pixel_size in ICON_FILES:
        out = os.path.join(APPICON_SET, filename)
        if pixel_size == BASE_SIZE:
            master.save(out, format="PNG")
        else:
            resized = master.resize((pixel_size, pixel_size), Image.LANCZOS)
            resized.save(out, format="PNG")

    contents_path = os.path.join(APPICON_SET, "Contents.json")
    with open(contents_path, "w") as f:
        json.dump(CONTENTS, f, indent=2)

    # Asset catalog raíz también necesita un Contents.json mínimo.
    root_contents = os.path.join(ASSETS, "Contents.json")
    if not os.path.exists(root_contents):
        with open(root_contents, "w") as f:
            json.dump({"info": {"version": 1, "author": "xcode"}}, f, indent=2)

    print(f"Wrote {len(ICON_FILES)} icon files + manifest into {APPICON_SET}")


if __name__ == "__main__":
    main()
