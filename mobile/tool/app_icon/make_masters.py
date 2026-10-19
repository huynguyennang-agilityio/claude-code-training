"""Make the app icon masters in assets/icon/ from the StrideQuest artwork.

Run from mobile/ in a throwaway virtualenv (Pillow and NumPy are not app or
backend dependencies):

    python3 -m venv /tmp/icon-venv
    /tmp/icon-venv/bin/pip install pillow numpy
    /tmp/icon-venv/bin/python -I tool/app_icon/make_masters.py

Then regenerate the platform icons with `dart run flutter_launcher_icons`.
See docs/plans/008-app-icon.md.
"""

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ICON_DIR = Path(__file__).resolve().parents[2] / "assets" / "icon"
SIZE = 1024

# Inside of the glossy border on the 2000 px source, and its corner radius.
TILE_X, TILE_Y, TILE_SIDE = 166, 167, 1668
TILE_RADIUS, TILE_INSET = 300, 10
# Rows of the tile that hold the "Stride Quest" text.
TEXT_ROWS = (1330, 1640)
# The athletes and medal, zoomed: a square of this share of the tile, from its
# top. The adaptive icon zooms less, so the medal keeps a margin inside its fade.
ZOOM = 0.86
ADAPTIVE_ZOOM = 1.0

# Brightness to colour, built from the app theme (lib/core/theme/).
LIME_STOPS = [
    (0.0, "0A1406"),
    (0.12, "1A2C0E"),
    (0.35, "4F6E1A"),
    (0.65, "D0EC60"),
    (1.0, "F6FFD8"),
]
# Android adaptive icon: art share of the 108 dp layer (the safe zone is 66 dp),
# and how far the art moves left and down so the medal sits inside the safe zone
# (the empty band where the text was goes below the visible area).
ADAPTIVE_ART = 0.68
ADAPTIVE_SHIFT = (-0.03, 0.08)


def hex_rgb(value: str) -> np.ndarray:
    return np.array([int(value[i : i + 2], 16) for i in (0, 2, 4)]) / 255


def push_pull_fill(rgb: np.ndarray, known: np.ndarray) -> np.ndarray:
    """Fill the pixels where `known` is False smoothly from their surroundings."""
    levels = [(rgb * known[..., None], known.astype(np.float64))]
    while min(levels[-1][1].shape) > 2:
        colour, weight = levels[-1]
        h, w = colour.shape[0] // 2 * 2, colour.shape[1] // 2 * 2
        colour = colour[:h, :w].reshape(h // 2, 2, w // 2, 2, 3).sum((1, 3))
        weight = weight[:h, :w].reshape(h // 2, 2, w // 2, 2).sum((1, 3))
        levels.append((colour, weight))
    colour, weight = levels[-1]
    result = colour / np.maximum(weight, 1e-9)[..., None]
    for colour, weight in reversed(levels[:-1]):
        size = (weight.shape[1], weight.shape[0])
        up = np.stack(
            [
                np.asarray(
                    Image.fromarray(result[..., i].astype(np.float32)).resize(
                        size, Image.Resampling.BILINEAR
                    )
                )
                for i in range(3)
            ],
            -1,
        )
        alpha = np.clip(weight, 0, 1)[..., None]
        result = colour / np.maximum(weight, 1e-9)[..., None] * alpha + up * (1 - alpha)
    return result


def clean_artwork(source: Image.Image) -> Image.Image:
    """Crop to the tile and fill its corners and the text band."""
    tile = source.convert("RGB").crop(
        (TILE_X, TILE_Y, TILE_X + TILE_SIDE, TILE_Y + TILE_SIDE)
    )
    rgb = np.asarray(tile).astype(np.float64)
    mask = Image.new("L", tile.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (TILE_INSET, TILE_INSET, TILE_SIDE - 1 - TILE_INSET, TILE_SIDE - 1 - TILE_INSET),
        TILE_RADIUS,
        fill=255,
    )
    known = np.asarray(mask) > 127
    known[TEXT_ROWS[0] : TEXT_ROWS[1], :] = False
    filled = push_pull_fill(rgb, known)
    rgb[~known] = filled[~known]
    return Image.fromarray(rgb.clip(0, 255).astype(np.uint8))


def zoom(clean: Image.Image, share: float) -> Image.Image:
    """Keep a square of `share` of the tile, from its top, at SIZE."""
    side = int(TILE_SIDE * share)
    left = (TILE_SIDE - side) // 2
    return clean.crop((left, 0, left + side, side)).resize(
        (SIZE, SIZE), Image.Resampling.LANCZOS
    )


def to_lime(art: Image.Image) -> Image.Image:
    """Map brightness to the theme's lime scale, keeping the gold medal."""
    rgb = np.asarray(art).astype(np.float64) / 255
    hsv = np.asarray(art.convert("HSV")).astype(np.float64) / 255
    hue, sat, val = hsv[..., 0] * 360, hsv[..., 1], hsv[..., 2]
    ys, xs = np.mgrid[0:SIZE, 0:SIZE]
    gold = (hue > 25) & (hue < 60) & (sat > 0.35) & (val > 0.45)
    gold &= (xs > SIZE * 0.7) & (ys < SIZE * 0.33)
    gold_mask = (
        Image.fromarray((gold * 255).astype(np.uint8))
        .filter(ImageFilter.MaxFilter(9))
        .filter(ImageFilter.GaussianBlur(4))
    )
    keep = np.asarray(gold_mask).astype(np.float64)[..., None] / 255

    lum = rgb @ np.array([0.2126, 0.7152, 0.0722])
    stops = np.array([p for p, _ in LIME_STOPS])
    colours = np.array([hex_rgb(c) for _, c in LIME_STOPS])
    lime = np.stack([np.interp(lum, stops, colours[:, i]) for i in range(3)], -1)
    out = lime * (1 - keep) + rgb * keep
    return Image.fromarray((out * 255).clip(0, 255).astype(np.uint8))


def edge_colour(image: Image.Image) -> tuple[int, int, int]:
    a = np.asarray(image).astype(np.float64)
    band = 40
    edges = np.concatenate(
        [
            a[:band].reshape(-1, 3),
            a[-band:].reshape(-1, 3),
            a[:, :band].reshape(-1, 3),
            a[:, -band:].reshape(-1, 3),
        ]
    )
    r, g, b = np.median(edges, 0).astype(int)
    return int(r), int(g), int(b)


def adaptive_layer(icon: Image.Image) -> tuple[Image.Image, np.ndarray]:
    """Place the icon in the middle of a 108 dp layer with soft round edges."""
    side = int(SIZE * ADAPTIVE_ART)
    art = icon.resize((side, side), Image.Resampling.LANCZOS)
    ys, xs = np.mgrid[0:side, 0:side]
    # Distance from the centre, as a share of half the side, in a squircle norm
    # so the corners fade earlier than the edge midpoints.
    d = (np.abs(xs / (side - 1) * 2 - 1) ** 4 + np.abs(ys / (side - 1) * 2 - 1) ** 4) ** 0.25
    alpha = np.clip((1.0 - d) / 0.12, 0, 1)
    layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    left = (SIZE - side) // 2 + int(SIZE * ADAPTIVE_SHIFT[0])
    top = (SIZE - side) // 2 + int(SIZE * ADAPTIVE_SHIFT[1])
    layer.paste(art.convert("RGBA"), (left, top))
    full_alpha = np.zeros((SIZE, SIZE))
    full_alpha[top : top + side, left : left + side] = alpha
    return layer, full_alpha


def main() -> None:
    source = Image.open(ICON_DIR / "source.webp")
    clean = clean_artwork(source)
    icon = to_lime(zoom(clean, ZOOM))
    icon.save(ICON_DIR / "app_icon.png")

    layer, alpha = adaptive_layer(to_lime(zoom(clean, ADAPTIVE_ZOOM)))
    rgba = np.asarray(layer).copy()
    rgba[..., 3] = (alpha * 255).astype(np.uint8)
    Image.fromarray(rgba, "RGBA").save(ICON_DIR / "app_icon_foreground.png")

    # Themed icon: white where the strokes are bright.
    lum = np.asarray(layer.convert("L")).astype(np.float64) / 255
    strokes = np.clip((lum - 0.3) / 0.3, 0, 1) * alpha
    mono = np.zeros((SIZE, SIZE, 4), dtype=np.uint8)
    mono[..., :3] = 255
    mono[..., 3] = (strokes * 255).astype(np.uint8)
    Image.fromarray(mono, "RGBA").save(ICON_DIR / "app_icon_monochrome.png")

    print("adaptive background: #%02X%02X%02X" % edge_colour(icon))


if __name__ == "__main__":
    main()
