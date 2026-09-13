#!/usr/bin/env python3
"""Generates an original, on-theme app icon and splash-screen source image
for the fitness_tracker app.

This is a one-time local build-tool script (not shipped with the app). It
draws simple geometric shapes with Pillow rather than any third-party logo
or font asset, matching the app's dark/neon design tokens defined in
lib/core/theme/app_colors.dart:
  - background: 0xFF0A0A0F (near-black)
  - accentGreen: 0xFF00E5A0 (neon)
  - accentBlue: 0xFF3D5AFE

The glyph is an abstract "activity pulse" (a heartbeat/EKG-style zig-zag)
inside a rounded, glowing square badge -- legible at small sizes, and not a
copy of any existing app or brand mark.
"""
from PIL import Image, ImageDraw, ImageFilter
import math
import os

BACKGROUND = (10, 10, 15, 255)  # 0xFF0A0A0F
SURFACE = (21, 21, 31, 255)  # 0xFF15151F
ACCENT_GREEN = (0, 229, 160, 255)  # 0xFF00E5A0
ACCENT_BLUE = (61, 90, 254, 255)  # 0xFF3D5AFE

SIZE = 1024


def build_icon(size=SIZE, transparent_bg=False):
    bg = (0, 0, 0, 0) if transparent_bg else BACKGROUND
    img = Image.new("RGBA", (size, size), bg)
    draw = ImageDraw.Draw(img)

    if not transparent_bg:
        # Soft radial glow behind the badge, built from concentric
        # translucent green circles blurred together.
        glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        glow_draw = ImageDraw.Draw(glow)
        cx, cy = size // 2, size // 2
        max_r = int(size * 0.42)
        for r in range(max_r, 0, -8):
            alpha = int(70 * (1 - r / max_r))
            glow_draw.ellipse(
                [cx - r, cy - r, cx + r, cy + r],
                fill=(ACCENT_GREEN[0], ACCENT_GREEN[1], ACCENT_GREEN[2], alpha),
            )
        glow = glow.filter(ImageFilter.GaussianBlur(size * 0.04))
        img.alpha_composite(glow)

    # Rounded-square badge (the "card" surface).
    margin = int(size * 0.16)
    badge_box = [margin, margin, size - margin, size - margin]
    radius = int(size * 0.22)
    badge = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    badge_draw = ImageDraw.Draw(badge)
    badge_draw.rounded_rectangle(badge_box, radius=radius, fill=SURFACE)
    img.alpha_composite(badge)

    # Abstract "activity pulse" glyph: a bold zig-zag line evoking a
    # heartbeat/EKG trace and a bar-chart baseline -- fitness-adjacent,
    # simple, legible at small sizes, entirely original geometry.
    glyph_layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    glyph_draw = ImageDraw.Draw(glyph_layer)

    cx, cy = size // 2, size // 2
    half_w = int(size * 0.22)
    points = [
        (cx - half_w, cy),
        (cx - half_w * 0.45, cy),
        (cx - half_w * 0.18, cy - half_w * 0.85),
        (cx + half_w * 0.05, cy + half_w * 0.55),
        (cx + half_w * 0.28, cy - half_w * 0.35),
        (cx + half_w * 0.5, cy),
        (cx + half_w, cy),
    ]
    stroke_width = int(size * 0.045)
    glyph_draw.line(points, fill=ACCENT_GREEN, width=stroke_width, joint="curve")
    # Rounded end caps so the stroke doesn't look clipped at the joints.
    cap_r = stroke_width // 2
    for px, py in [points[0], points[-1]]:
        glyph_draw.ellipse([px - cap_r, py - cap_r, px + cap_r, py + cap_r], fill=ACCENT_GREEN)

    # A small accent dot (a "reading" marker) in the secondary accent color.
    dot_r = int(size * 0.028)
    dot_x, dot_y = points[4]
    glyph_draw.ellipse(
        [dot_x - dot_r, dot_y - dot_r, dot_x + dot_r, dot_y + dot_r], fill=ACCENT_BLUE
    )

    img.alpha_composite(glyph_layer)
    return img


def build_splash(width=1242, height=2688):
    """A simple dark splash: solid background + the same badge/glyph
    centered, sized modestly (flutter_native_splash centers it itself, but
    we supply a reasonably sized transparent-background source image)."""
    icon = build_icon(size=600, transparent_bg=True)
    canvas = Image.new("RGBA", (width, height), BACKGROUND)
    x = (width - icon.width) // 2
    y = (height - icon.height) // 2
    canvas.alpha_composite(icon, (x, y))
    return canvas


if __name__ == "__main__":
    out_dir = os.path.join(os.path.dirname(__file__), "..", "assets")
    icon_dir = os.path.join(out_dir, "icon")
    splash_dir = os.path.join(out_dir, "splash")
    os.makedirs(icon_dir, exist_ok=True)
    os.makedirs(splash_dir, exist_ok=True)

    icon = build_icon()
    icon_path = os.path.join(icon_dir, "icon.png")
    icon.convert("RGB").save(icon_path, "PNG")
    print(f"Wrote {icon_path} ({icon.size})")

    # Foreground-only (transparent bg) variant for Android adaptive icons.
    icon_fg = build_icon(transparent_bg=True)
    icon_fg_path = os.path.join(icon_dir, "icon_foreground.png")
    icon_fg.save(icon_fg_path, "PNG")
    print(f"Wrote {icon_fg_path} ({icon_fg.size})")

    splash = build_splash()
    splash_path = os.path.join(splash_dir, "splash.png")
    splash.save(splash_path, "PNG")
    print(f"Wrote {splash_path} ({splash.size})")
