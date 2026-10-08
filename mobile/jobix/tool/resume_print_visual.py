"""Opt-in PDF visual guard; stdlib and existing Poppler only.

Evidence/baselines must be outside tracked source (temporary or git-ignored).
Candidate generation NEVER approves a baseline. Review every PNG, then invoke
this module with --approve DIRECTORY --review-note "what was checked".
"""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import platform
import subprocess

from resume_print_cdp import tool_environment

SELECTED = {"ar-short.html", "ar-boundary-10.html", "en-boundary-10.html"}
POLICY = {"dpi": 96, "channel_delta": 24, "max_changed_ink_ratio": .015,
          "tile_size": 64, "max_tile_changed_ink_ratio": .12}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def evidence_directory(path, root):
    path = Path(path).resolve()
    if path == root or root in path.parents:
        relative = path.relative_to(root)
        result = subprocess.run(["git", "check-ignore", "-q", str(relative)],
                                cwd=root, env=tool_environment())
        if result.returncode != 0:
            raise ValueError("Visual evidence must be temporary or git-ignored")
    return path


def ppm(path):
    """Read Poppler's binary RGB PPM, including comments in its header."""
    data = path.read_bytes()
    pos = 0
    tokens = []
    while len(tokens) < 4:
        while data[pos:pos+1].isspace():
            pos += 1
        if data[pos:pos+1] == b"#":
            pos = data.index(b"\n", pos) + 1
            continue
        end = pos
        while end < len(data) and not data[end:end+1].isspace():
            end += 1
        tokens.append(data[pos:end])
        pos = end
    if tokens[0] != b"P6" or tokens[3] != b"255":
        raise ValueError("Expected 8-bit binary RGB PPM")
    width, height = map(int, tokens[1:3])
    # Consume exactly the raster separator; pixel bytes may be whitespace.
    pos += 2 if data[pos:pos+2] == b"\r\n" else 1
    pixels = data[pos:]
    if width <= 0 or height <= 0 or len(pixels) != width * height * 3:
        raise ValueError("Malformed PPM raster")
    return width, height, pixels


def compare(reference, current, difference):
    w, h, old = ppm(reference)
    nw, nh, new = ppm(current)
    if (w, h) != (nw, nh):
        raise AssertionError(f"Image dimensions changed: {(w, h)} -> {(nw, nh)}")
    ink = changed = 0
    tiles = {}
    diff = bytearray(b"\xff" * len(old))
    for index in range(w * h):
        offset = index * 3
        a, b = old[offset:offset+3], new[offset:offset+3]
        has_ink = min(a + b) < 245
        different = max(abs(x-y) for x, y in zip(a, b)) > POLICY["channel_delta"]
        ink += has_ink
        changed += different
        key = ((index % w) // POLICY["tile_size"],
               (index // w) // POLICY["tile_size"])
        counts = tiles.setdefault(key, [0, 0])
        counts[0] += has_ink
        counts[1] += different
        if different:
            diff[offset:offset+3] = b"\xff\x00\x00"
    difference.write_bytes(f"P6\n{w} {h}\n255\n".encode() + diff)
    ratio = changed / max(ink, 1)
    worst = max((c / max(i, 32) for i, c in tiles.values()), default=0)
    result = {"changed_pixels": changed, "ink_pixels": ink,
              "changed_ink_ratio": ratio, "worst_tile_ratio": worst}
    if ratio > POLICY["max_changed_ink_ratio"] or worst > POLICY["max_tile_changed_ink_ratio"]:
        raise AssertionError(f"Visual regression: {result}; inspect {difference}")
    return result


class VisualCheck:
    def __init__(self, directory, binaries, root, browser, baseline=None):
        self.directory = directory
        self.binaries = binaries
        self.baseline = baseline
        self.images = {}
        self.results = {}
        version = subprocess.check_output([binaries["pdftoppm"], "-v"],
                                         stderr=subprocess.STDOUT,
                                         env=tool_environment()).decode().splitlines()[0]
        engine = browser.call("Browser.getVersion")
        self.environment = {
            "chromium": {key: engine[key] for key in ("product", "revision", "jsVersion")},
            "poppler": version, "platform": platform.system(),
            "machine": platform.machine(),
            "fonts_sha256": {name: digest(root / "assets/fonts" / name) for name in
                             ("Inter.ttf", "IBMPlexSansArabic-Regular.ttf")},
            "policy": POLICY,
        }
        if baseline:
            self.reviewed = json.loads((baseline / "visual-manifest.json").read_text())
            if not (self.reviewed.get("review") or {}).get("note"):
                raise AssertionError("Baseline is unreviewed; review PNGs and explicitly approve")
            if self.reviewed["environment"] != self.environment:
                raise AssertionError("Engine/font/capture versions changed; deliberate fresh review required")

    def capture(self, case, stem, pages):
        if case["file"] not in SELECTED:
            return
        source_hash = hashlib.sha256(json.dumps(case["source"], sort_keys=True,
                                               ensure_ascii=False).encode()).hexdigest()
        for page in range(1, pages + 1):
            name = f"{stem.name}-page-{page}"
            for extra in ([], ["-png"]):
                subprocess.check_call(
                    [self.binaries["pdftoppm"], "-f", str(page), "-l", str(page),
                     "-singlefile", "-r", str(POLICY["dpi"]), *extra,
                     str(stem.with_suffix(".pdf")), str(self.directory / name)],
                    timeout=60, env=tool_environment())
            filename = name + ".ppm"
            current = self.directory / filename
            self.images[filename] = {"sha256": digest(current), "source_sha256": source_hash,
                                    "preview_sha256": digest(self.directory / (name + ".png"))}
            if self.baseline:
                expected = self.reviewed["images"].get(filename)
                if not expected or expected["source_sha256"] != source_hash:
                    raise AssertionError("Fixture/page changed; review a fresh candidate set")
                reference = self.baseline / filename
                if digest(reference) != expected["sha256"]:
                    raise AssertionError("Reviewed baseline image was modified")
                self.results[filename] = compare(
                    reference, current, self.directory / (name + "-diff.ppm"))

    def finish(self):
        if not self.images or (self.baseline and
                               self.images.keys() != self.reviewed["images"].keys()):
            raise AssertionError("Visual page coverage differs from reviewed baseline")
        manifest = {"environment": self.environment, "images": self.images,
                    "results": self.results, "review": None}
        (self.directory / "visual-manifest.json").write_text(json.dumps(manifest, indent=2))
        print(f"VISUAL: {len(self.images)} pages "
              f"{'matched reviewed baseline' if self.baseline else 'await explicit PNG review'}")


def approve(directory, note):
    manifest_path = directory / "visual-manifest.json"
    manifest = json.loads(manifest_path.read_text())
    if manifest.get("review"):
        raise ValueError("Already reviewed; generate a separate fresh candidate directory")
    if not note.strip():
        raise ValueError("A specific review note is required")
    if not manifest["images"]:
        raise ValueError("No candidate images")
    for filename, image in manifest["images"].items():
        if Path(filename).name != filename or not filename.endswith(".ppm"):
            raise ValueError("Invalid image filename")
        if digest(directory / filename) != image["sha256"] or digest(
                directory / Path(filename).with_suffix(".png")) != image["preview_sha256"]:
            raise ValueError("Candidate changed after capture; regenerate before review")
        ppm(directory / filename)
    manifest["review"] = {"note": note.strip(),
                          "at_utc": datetime.now(timezone.utc).isoformat()}
    manifest_path.write_text(json.dumps(manifest, indent=2))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--approve", type=Path, required=True)
    parser.add_argument("--review-note", required=True)
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[3]
    approve(evidence_directory(args.approve, repo), args.review_note)
    print("Explicit review recorded. This directory can now be used as a baseline.")
