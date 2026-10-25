"""Turns the raw simulator captures into the captioned App Store screenshots.

Reads docs/store/screenshots/raw/<device>/ (written by capture.sh) and writes
docs/store/screenshots/<device>/01-…png to 06-…png at exactly the size App Store
Connect asks for. Colours and fonts are the app's own
(lib/src/design/palette.dart, assets/fonts/).

    python3 tool/screenshots/compose.py      (needs Pillow)
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "docs/store/screenshots/raw"
OUT = ROOT / "docs/store/screenshots"
FONTS = ROOT / "assets/fonts"

BACKGROUND = (0xF3, 0xE9, 0xD2)  # Palette.backgroundLight
INK = (0x22, 0x36, 0x1F)  # Palette.moss
MARIGOLD = (0xE8, 0xA3, 0x3D)  # Palette.marigold
LABEL = (0xFF, 0xF8, 0xEA)  # Palette.surfaceLight

# Where the garden sits in a garden-tab capture, as fractions of the screen:
# what the season and theme composites crop to.
GARDEN_BAND = {
    "iphone-6.3": (0.30, 0.65),
    "iphone-6.9": (0.30, 0.65),
    "ipad-13": (0.20, 0.74),
}

# The composites' layout per device: (columns, rows) for four seasons and for
# three themes. Bands on the narrow phone, a grid where the iPad has room.
GRIDS = {
    "iphone-6.3": {"seasons": (1, 4), "themes": (1, 3)},
    "iphone-6.9": {"seasons": (1, 4), "themes": (1, 3)},
    "ipad-13": {"seasons": (2, 2), "themes": (1, 3)},
}

SHOTS = [
    ("01-garden", "Your garden grows with every focused session", "garden"),
    ("02-session", "Watch your plant grow as you focus", "session"),
    ("03-timer-bar", "Your session keeps time while you wander", "garden-session"),
    ("04-journal", "See your focus habits bloom over time", "journal"),
    (
        "05-seasons",
        "Your garden changes with the seasons",
        [
            ("season-spring", "Spring"),
            ("season-summer", "Summer"),
            ("season-autumn", "Autumn"),
            ("season-winter", "Winter"),
        ],
    ),
    (
        "06-themes",
        "Three gardens to grow in, all of them free",
        [
            ("theme-zen", "Zen Garden"),
            ("theme-tropical", "Tropical"),
            ("theme-wildflower", "Wildflower Meadow"),
        ],
    ),
]


def font(name, size):
    return ImageFont.truetype(str(FONTS / name), size)


def rounded(image, radius):
    mask = Image.new("L", image.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, image.width - 1, image.height - 1), radius, fill=255
    )
    return image, mask


def paste_card(canvas, image, x, y, radius):
    """Pastes [image] with rounded corners and a soft shadow under it."""
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        (x, y + radius // 3, x + image.width, y + image.height + radius // 3),
        radius,
        fill=(0x22, 0x36, 0x1F, 70),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius // 2))
    canvas.alpha_composite(shadow)
    image, mask = rounded(image.convert("RGBA"), radius)
    canvas.paste(image, (x, y), mask)


def wrap(draw, text, face, width):
    lines, line = [], ""
    for word in text.split():
        trial = f"{line} {word}".strip()
        if draw.textlength(trial, font=face) <= width or not line:
            line = trial
        else:
            lines.append(line)
            line = word
    return lines + [line]


def caption(canvas, text, top, width):
    """Draws [text] centred from [top]; returns where the caption ends."""
    draw = ImageDraw.Draw(canvas)
    # Two lines at most, so every screenshot in the set sits at the same height.
    size = int(width * 0.085)
    while True:
        face = font("Fraunces-SemiBold.ttf", size)
        lines = wrap(draw, text, face, width * 0.86)
        if len(lines) <= 2:
            break
        size -= 4
    y = top
    for line in lines:
        draw.text((width / 2, y), line, font=face, fill=INK, anchor="ma")
        y += int(size * 1.15)
    # A short marigold rule under the caption, the app's accent.
    rule = int(width * 0.08)
    draw.rounded_rectangle(
        (width / 2 - rule / 2, y + size * 0.35, width / 2 + rule / 2, y + size * 0.35 + size * 0.12),
        radius=int(size * 0.06),
        fill=MARIGOLD,
    )
    return y + int(size * 0.5)


def crop_to(image, band, aspect):
    """The centre of the garden band in [image], cropped to [aspect] (w / h)."""
    top, bottom = int(image.height * band[0]), int(image.height * band[1])
    width, height = image.width, bottom - top
    if width / height > aspect:
        new_width = int(height * aspect)
        left = (width - new_width) // 2
        return image.crop((left, top, left + new_width, bottom))
    new_height = int(width / aspect)
    middle = (top + bottom) // 2
    return image.crop((0, middle - new_height // 2, width, middle - new_height // 2 + new_height))


def label(canvas, text, x, y, scale):
    draw = ImageDraw.Draw(canvas)
    face = font("Inter-SemiBold.ttf", int(scale * 0.032))
    pad_x, pad_y = int(scale * 0.022), int(scale * 0.012)
    width = draw.textlength(text, font=face)
    height = face.size
    draw.rounded_rectangle(
        (x, y - height - pad_y * 2, x + width + pad_x * 2, y),
        radius=(height + pad_y * 2) // 2,
        fill=INK,
    )
    draw.text((x + pad_x, y - pad_y - height * 0.08), text, font=face, fill=LABEL, anchor="ls")


def compose(device, name, text, source):
    size = Image.open(RAW / device / "garden.png").size
    width, height = size
    canvas = Image.new("RGBA", size, BACKGROUND + (255,))
    margin = int(width * 0.06)
    body_top = caption(canvas, text, int(height * 0.055), width) + int(height * 0.03)
    body_bottom = height - margin
    radius = int(width * 0.045)

    if isinstance(source, str):
        shot = Image.open(RAW / device / f"{source}.png").convert("RGB")
        scale = min((body_bottom - body_top) / shot.height, (width - 2 * margin) / shot.width)
        shot = shot.resize((int(shot.width * scale), int(shot.height * scale)), Image.LANCZOS)
        paste_card(canvas, shot, (width - shot.width) // 2, body_top, radius)
    else:
        kind = "seasons" if name.endswith("seasons") else "themes"
        cols, rows = GRIDS[device][kind]
        gap = int(width * 0.03)
        tile_w = (width - 2 * margin - gap * (cols - 1)) // cols
        tile_h = (body_bottom - body_top - gap * (rows - 1)) // rows
        tile_radius = int(radius * 0.7)
        for i, (raw, title) in enumerate(source):
            col, row = i % cols, i // cols
            shot = Image.open(RAW / device / f"{raw}.png").convert("RGB")
            tile = crop_to(shot, GARDEN_BAND[device], tile_w / tile_h).resize((tile_w, tile_h), Image.LANCZOS)
            x = margin + col * (tile_w + gap)
            y = body_top + row * (tile_h + gap)
            paste_card(canvas, tile, x, y, tile_radius)
            label(canvas, title, x + int(width * 0.025), y + tile_h - int(width * 0.025), width)

    destination = OUT / device / f"{name}.png"
    destination.parent.mkdir(parents=True, exist_ok=True)
    # Flattened: App Store Connect turns away screenshots with an alpha channel.
    canvas.convert("RGB").save(destination, optimize=True)
    print(destination.relative_to(ROOT), canvas.size)


if __name__ == "__main__":
    for device in GRIDS:
        for name, text, source in SHOTS:
            compose(device, name, text, source)
