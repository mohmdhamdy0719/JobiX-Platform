#!/usr/bin/env python3
"""Package approved masters by proportional resizing only; never redraw marks."""
import json
from pathlib import Path
import shutil

from PIL import Image
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

ROOT = Path(__file__).resolve().parents[3]
APP = ROOT / "mobile/jobix"
DARK = ROOT / "attached_assets/0_JX_Logo_Dark_1791039765492.png"
ICON = ROOT / "attached_assets/0_app_icon_white_background_1791039821804.png"


def resize(source, output, size):
    """Fit within the requested canvas, retaining source aspect ratio/clear space."""
    image = Image.open(source).convert("RGBA")
    image.thumbnail((size, size), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (size, size))
    canvas.alpha_composite(image, ((size - image.width) // 2, (size - image.height) // 2))
    output.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(output)


def main():
    brand = APP / "assets/brand"
    shutil.copyfile(DARK, brand / "logo_dark.png")
    shutil.copyfile(ICON, brand / "app_icon_master.png")
    res = APP / "android/app/src/main/res"
    for density, factor in {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}.items():
        resize(ICON, res / f"mipmap-{density}/ic_launcher.png", round(48 * factor))
        # Original master inside adaptive-icon safe area; OS masks outer padding only.
        foreground = Image.new("RGBA", (round(108 * factor),) * 2)
        art = Image.open(ICON).convert("RGBA")
        art.thumbnail((round(66 * factor),) * 2, Image.Resampling.LANCZOS)
        foreground.alpha_composite(art, ((foreground.width-art.width)//2, (foreground.height-art.height)//2))
        foreground.save(res / f"mipmap-{density}/ic_launcher_foreground.png")
        resize(brand / "logo.png", res / f"drawable-{density}/jobix_splash.png", round(96 * factor))
    ios = APP / "ios/Runner/Assets.xcassets"
    contents = json.loads((ios / "AppIcon.appiconset/Contents.json").read_text())
    for entry in contents["images"]:
        size = round(float(entry["size"].split("x")[0]) * float(entry["scale"].rstrip("x")))
        path = ios / "AppIcon.appiconset" / entry["filename"]
        resize(ICON, path, size)
        # iOS icons must be opaque. Preserve the approved master's white background.
        rgba = Image.open(path)
        flat = Image.new("RGB", rgba.size, "white")
        flat.paste(rgba, mask=rgba.getchannel("A"))
        flat.save(path)
    for scale, suffix in [(1, ""), (2, "@2x"), (3, "@3x")]:
        resize(brand / "logo.png", ios / f"LaunchImage.imageset/LaunchImage{suffix}.png", 96 * scale)
    variable = TTFont("/tmp/jobix-noto-arabic.ttf")
    for weight, name in [(400, "Regular"), (500, "Medium"), (600, "SemiBold"), (700, "Bold")]:
        font = instantiateVariableFont(variable, {"wght": weight, "wdth": 100}, inplace=False)
        font.save(APP / f"assets/fonts/NotoSansArabic-{name}.ttf")
    print("Approved brand masters copied; native sizes generated without cropping/recoloring.")
    print("Noto Sans Arabic production weights 400, 500, 600, 700 instantiated.")


if __name__ == "__main__":
    main()