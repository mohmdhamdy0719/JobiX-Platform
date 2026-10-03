#!/usr/bin/env python3
"""Verify and package unchanged native build and explicitly labelled widget renders."""
import hashlib
import io
import json
from pathlib import Path
import re
import subprocess
import zipfile

from PIL import Image, ImageDraw, ImageFont
from fontTools.ttLib import TTFont

APP = Path(__file__).resolve().parents[1]
ROOT = APP.parents[1]
APK = APP / "build/app/outputs/flutter-apk/app-debug.apk"
OUTPUT = APP / "build/review"
FONT = APP / "assets/fonts/Inter.ttf"


def certificate(path):
    result = subprocess.run(
        [str(ROOT / ".local/toolchains/android-sdk/build-tools/35.0.0/apksigner"),
         "verify", "--print-certs", str(path)], capture_output=True, text=True, check=True,
    )
    match = re.search(r"certificate SHA-256 digest: ([0-9a-f]+)", result.stdout)
    if not match:
        raise RuntimeError("APK signing certificate could not be verified")
    return match[1]


def sheet(name, entries, columns):
    width, height, gap = 280, 609, 20
    rows = (len(entries) + columns - 1) // columns
    image = Image.new("RGB", (columns * (width + gap) + gap, rows * (height + 50 + gap) + 100), "#E9EDF3")
    draw = ImageDraw.Draw(image)
    title_font = ImageFont.truetype(str(FONT), 22)
    label_font = ImageFont.truetype(str(FONT), 15)
    draw.text((gap, 15), "Jobix — redesigned Flutter flows", fill="#14243A", font=title_font)
    draw.text((gap, 48), "WIDGET TEST RENDERS / NOT PHYSICAL-DEVICE SCREENSHOTS", fill="#203F75", font=label_font)
    for i, (filename, label) in enumerate(entries):
        x = gap + (i % columns) * (width + gap)
        y = 90 + (i // columns) * (height + 50 + gap)
        source = Image.open(APP / "test/goldens" / filename).convert("RGB")
        source.thumbnail((width, height), Image.Resampling.LANCZOS)
        draw.text((x, y), label, fill="#14243A", font=label_font)
        image.paste(source, (x, y + 30))
    image.save(OUTPUT / name, optimize=True)


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    previous = OUTPUT / "jobix-dev-debug.zip"
    if previous.exists():
        old_apk = OUTPUT / "previous-review.apk"
        with zipfile.ZipFile(previous) as archive:
            old_apk.write_bytes(archive.read("app-debug.apk"))
        same_certificate = certificate(old_apk) == certificate(APK)
        old_apk.unlink()
        if not same_certificate:
            raise RuntimeError("Review signing certificate changed; stop before advising installation or data-destructive uninstall.")
        print("PASS: signing certificate matches previous review APK.")
    else:
        certificate(APK)
    with zipfile.ZipFile(APK) as archive:
        manifest = json.loads(archive.read("assets/flutter_assets/FontManifest.json"))
        families = {family["family"]: family for family in manifest}
        assert "Inter" in families
        assert {f.get("weight") for f in families["Noto Sans Arabic"]["fonts"]} == {400, 500, 600, 700}
        for weight, name in [(400, "Regular"), (500, "Medium"), (600, "SemiBold"), (700, "Bold")]:
            font = TTFont(io.BytesIO(archive.read(f"assets/flutter_assets/assets/fonts/NotoSansArabic-{name}.ttf")))
            assert font["OS/2"].usWeightClass == weight
            assert 0x0627 in font.getBestCmap() and 0x0645 in font.getBestCmap()
        assert "assets/flutter_assets/assets/fonts/OFL-NotoSansArabic.txt" in archive.namelist()
        engines = {path for path in archive.namelist() if path.endswith("/libflutter.so")}
        assert engines == {"lib/arm64-v8a/libflutter.so", "lib/armeabi-v7a/libflutter.so"}
        for staged, original in [
            ("logo_dark.png", "0_JX_Logo_Dark_1791039765492.png"),
            ("app_icon_master.png", "0_app_icon_white_background_1791039821804.png"),
        ]:
            assert archive.read(f"assets/flutter_assets/assets/brand/{staged}") == (ROOT / "attached_assets" / original).read_bytes()
    print("PASS: packaged Inter, four real Arabic weights/glyphs and OFL; ARM Flutter engines; unchanged brand masters.")
    digest = hashlib.sha256(APK.read_bytes()).hexdigest()
    with zipfile.ZipFile(previous, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        archive.write(APK, "app-debug.apk")
        archive.writestr("README.txt",
            "Jobix DEVELOPMENT/DEBUG review build, not production.\n"
            "Extract app-debug.apk and install on a real ARM Android device (API 24+).\n"
            "Same signing certificate as previous review build; no uninstall/data deletion requested.\n"
            "No physical-device acceptance or Google/mail callback acceptance is claimed.\n"
            "See separately delivered widget renders and the verification report.\n"
            f"SHA-256 app-debug.apk: {digest}\n")
    with zipfile.ZipFile(previous) as archive:
        assert archive.testzip() is None
        assert hashlib.sha256(archive.read("app-debug.apk")).hexdigest() == digest
    captures = sorted((APP / "test/goldens").glob("redesign_*.png"))
    with zipfile.ZipFile(OUTPUT / "jobix-redesign-captures.zip", "w", zipfile.ZIP_DEFLATED) as archive:
        for path in captures:
            archive.write(path, path.name)
        archive.write(APP / "VISUAL_REDESIGN_REPORT.md", "VERIFICATION_REPORT.md")
        archive.write(APP / "DESIGN_SYSTEM.md", "DESIGN_SYSTEM.md")
        archive.writestr("README.txt",
            "Actual Flutter widget test renders, NOT physical Android screenshots.\n"
            "Production fonts and approved logos; fake auth/profile service boundaries.\n"
            "Synthetic test input in error/keyboard captures is not a production account.\n")
    sheet("jobix-overview.png", [
        ("redesign_startup_boot_en.png", "Startup / English"),
        ("redesign_intro_1_en.png", "Introduction / English"),
        ("redesign_research_1_ar.png", "Research Q1 / Arabic"),
        ("redesign_signup_ar.png", "Create account / Arabic"),
    ], 4)
    sheet("jobix-introductions.png", [
        (f"redesign_intro_{step}_{locale}.png", f"Introduction {step} / {locale.upper()}")
        for locale in ["en", "ar"] for step in range(1, 4)
    ], 3)
    sheet("jobix-authentication.png", [
        (f"redesign_{mode}_{locale}.png", f"{mode.title()} / {locale.upper()}")
        for locale in ["en", "ar"] for mode in ["signup", "login"]
    ], 2)
    sheet("jobix-research.png", [
        (f"redesign_research_{step}_{locale}.png", f"Question {step} / {locale.upper()}")
        for locale in ["en", "ar"] for step in range(1, 5)
    ], 4)
    print(f"PASS: unchanged APK ZIP; {len(captures)} full-size labelled captures.")
    print(f"APK SHA-256: {digest}")


if __name__ == "__main__":
    main()