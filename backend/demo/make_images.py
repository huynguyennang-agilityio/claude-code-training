"""Generate the artwork of the demo challenges: one cover per challenge and one medal per
type and tier, as PNG files in `backend/demo/images/`.

    python -m demo.make_images

The images are original: gradients, a route line and simple glyphs drawn here, no third-party
artwork. Running it again rewrites the same files, so the demo can be rebuilt.
"""

import math
from pathlib import Path

from PIL import Image, ImageDraw

IMAGES_DIR = Path(__file__).resolve().parent / "images"

COVER_SIZE = (1200, 675)
MEDAL_SIZE = 512

# (top colour, bottom colour, accent) of each challenge type.
PALETTES = {
    "run": ((18, 24, 20), (52, 78, 30), (200, 255, 70)),
    "swim": ((8, 22, 44), (14, 98, 124), (110, 226, 240)),
    "cycle": ((30, 16, 40), (122, 52, 38), (255, 176, 80)),
}
MEDAL_COLOURS = {
    "bronze": ((205, 127, 50), (130, 76, 28)),
    "silver": ((214, 218, 224), (124, 130, 142)),
    "gold": ((255, 205, 60), (176, 120, 14)),
}
# The covers of the demo challenges: (file name, type, seed that moves the route line).
COVERS = [
    ("cover-old-quarter-50k-steps", "run", 1),
    ("cover-my-khe-bay-20km", "swim", 2),
    ("cover-saigon-riverside-100km", "cycle", 3),
    ("cover-hanoi-autumn-30k-steps", "run", 4),
]


def _gradient(size: tuple[int, int], top: tuple[int, ...], bottom: tuple[int, ...]) -> Image.Image:
    width, height = size
    image = Image.new("RGB", size, top[:3])
    draw = ImageDraw.Draw(image)
    for y in range(height):
        t = y / (height - 1)
        draw.line(
            [(0, y), (width, y)],
            fill=tuple(round(a + (b - a) * t) for a, b in zip(top, bottom, strict=True)),
        )
    return image


def make_cover(kind: str, seed: int) -> Image.Image:
    top, bottom, accent = PALETTES[kind]
    image = _gradient(COVER_SIZE, top, bottom)
    draw = ImageDraw.Draw(image, "RGBA")
    width, height = COVER_SIZE
    # Soft discs, like a sun or a moon behind the route.
    for radius, alpha in ((260, 22), (180, 30), (110, 44)):
        cx, cy = width * (0.2 + 0.15 * seed), height * 0.3
        draw.ellipse([cx - radius, cy - radius, cx + radius, cy + radius], fill=(*accent, alpha))
    # The route: a wave across the picture with a dot at every kilometre.
    points = [
        (
            x,
            height * 0.68 + math.sin(x / 150 + seed) * 70 + math.sin(x / 61 + seed * 2) * 18,
        )
        for x in range(-20, width + 21, 6)
    ]
    draw.line(points, fill=(*accent, 70), width=22, joint="curve")
    draw.line(points, fill=(*accent, 255), width=7, joint="curve")
    for x, y in points[::22]:
        draw.ellipse([x - 9, y - 9, x + 9, y + 9], fill=(255, 255, 255, 255))
    # A pin at the far end of the route.
    px, py = points[-45]
    draw.ellipse([px - 26, py - 74, px + 26, py - 22], fill=(*accent, 255))
    draw.polygon([(px - 18, py - 38), (px + 18, py - 38), (px, py)], fill=(*accent, 255))
    draw.ellipse([px - 10, py - 58, px + 10, py - 38], fill=(*top, 255))
    # Fade the bottom edge so text laid over it stays readable.
    for y in range(height // 2, height):
        alpha = round(150 * ((y - height / 2) / (height / 2)))
        draw.line([(0, y), (width, y)], fill=(*top, alpha))
    return image


def _glyph(
    draw: ImageDraw.ImageDraw, kind: str, cx: float, cy: float, colour: tuple[int, ...]
) -> None:
    if kind == "run":  # two chevrons pointing forward
        for dx in (-34, 22):
            draw.line(
                [(cx + dx, cy - 52), (cx + dx + 38, cy), (cx + dx, cy + 52)],
                fill=colour,
                width=26,
                joint="curve",
            )
    elif kind == "swim":  # three waves
        for dy in (-44, 0, 44):
            wave = [(cx - 80 + x, cy + dy + math.sin(x / 20) * 12) for x in range(0, 161, 4)]
            draw.line(wave, fill=colour, width=18, joint="curve")
    else:  # cycle: two wheels and a frame
        for dx in (-52, 52):
            draw.ellipse([cx + dx - 40, cy - 34, cx + dx + 40, cy + 46], outline=colour, width=14)
        draw.line(
            [(cx - 52, cy + 6), (cx - 6, cy - 76), (cx + 36, cy - 76), (cx + 52, cy + 6)],
            fill=colour,
            width=14,
            joint="curve",
        )
        draw.line([(cx - 6, cy - 76), (cx + 14, cy + 6)], fill=colour, width=14)


def make_medal(kind: str, tier: str) -> Image.Image:
    light, dark = MEDAL_COLOURS[tier]
    size = MEDAL_SIZE
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    centre = size / 2
    # A ribbon behind the disc, then the disc as rings from dark to light.
    draw.polygon(
        [(centre - 90, 0), (centre - 30, 0), (centre + 20, 220), (centre - 40, 220)], fill=dark
    )
    draw.polygon(
        [(centre + 90, 0), (centre + 30, 0), (centre - 20, 220), (centre + 40, 220)], fill=light
    )
    cy = centre + 40
    for radius, colour in ((200, dark), (186, light), (150, dark), (140, light)):
        draw.ellipse([centre - radius, cy - radius, centre + radius, cy + radius], fill=colour)
    _glyph(draw, kind, centre, cy, (*dark, 255))
    return image


def generate(directory: Path = IMAGES_DIR) -> list[Path]:
    directory.mkdir(parents=True, exist_ok=True)
    written = []
    for name, kind, seed in COVERS:
        path = directory / f"{name}.png"
        make_cover(kind, seed).save(path, optimize=True)
        written.append(path)
    for kind in PALETTES:
        for tier in MEDAL_COLOURS:
            path = directory / f"medal-{kind}-{tier}.png"
            make_medal(kind, tier).save(path, optimize=True)
            written.append(path)
    return written


if __name__ == "__main__":
    for path in generate():
        print(path.relative_to(IMAGES_DIR.parent.parent), f"{path.stat().st_size // 1024} KB")
