"""Offline visual checker self-tests, no third-party modules or live data."""
import copy
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from resume_print_visual import (
    POLICY, VisualCheck, approve, compare, digest, evidence_directory, ppm,
)


class VisualTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="jobix-visual-unit-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def image(self, name, pixels=None, size=(128, 128)):
        width, height = size
        data = bytearray(b"\xff" * (width * height * 3))
        for (x, y), value in (pixels or {}).items():
            offset = (y * width + x) * 3
            data[offset:offset+3] = bytes([value] * 3)
        path = self.root / name
        path.write_bytes(f"P6\n# synthetic\n{width} {height}\n255\n".encode() + data)
        return path

    def test_identical_and_low_antialias_delta_pass(self):
        ink = {(x, y): 100 for x in range(20, 40) for y in range(20, 40)}
        reference = self.image("old.ppm", ink)
        current = self.image("new.ppm", {key: 110 for key in ink})
        result = compare(reference, current, self.root / "diff.ppm")
        self.assertEqual(result["changed_pixels"], 0)
        self.assertEqual(compare(reference, reference, self.root / "same.ppm")["ink_pixels"], 400)

    def test_lost_join_diacritic_weight_and_direction_fail(self):
        ink = {(x, y): 60 for x in range(10, 110) for y in range(10, 40)}
        reference = self.image("old.ppm", ink)
        changes = [
            {key: value for key, value in ink.items() if key[0] not in (50, 51, 52)},
            {key: 110 for key in ink},
            {(x, y + 60): value for (x, y), value in ink.items()},
            {**ink, **{(x, 90): 0 for x in range(10, 15)}},
        ]
        for index, changed in enumerate(changes):
            with self.subTest(index=index), self.assertRaisesRegex(AssertionError, "Visual regression"):
                compare(reference, self.image("new.ppm", changed), self.root / "diff.ppm")
        self.assertTrue((self.root / "diff.ppm").exists())

    def test_dimension_change_fails(self):
        with self.assertRaisesRegex(AssertionError, "dimensions"):
            compare(self.image("a.ppm"), self.image("b.ppm", size=(100, 100)),
                    self.root / "diff.ppm")

    def test_binary_whitespace_pixel_not_consumed(self):
        path = self.root / "white.ppm"
        path.write_bytes(b"P6\n1 1\n255\n\x20\x0a\x09")
        self.assertEqual(ppm(path), (1, 1, b"\x20\x0a\x09"))
        path.write_bytes(b"P6\n1 1\n255\n\x20")
        with self.assertRaises(ValueError):
            ppm(path)

    def candidate(self):
        image = self.image("synthetic.ppm")
        preview = self.root / "synthetic.png"
        preview.write_bytes(b"synthetic-preview")
        manifest = {"environment": {}, "images": {
            image.name: {"sha256": digest(image), "preview_sha256": digest(preview),
                         "source_sha256": "fixture"}}, "review": None}
        (self.root / "visual-manifest.json").write_text(json.dumps(manifest))
        return manifest

    def test_explicit_approval_integrity_and_no_reapproval(self):
        self.candidate()
        with self.assertRaisesRegex(ValueError, "note"):
            approve(self.root, " ")
        approve(self.root, "Reviewed synthetic test image")
        self.assertTrue(json.loads((self.root / "visual-manifest.json").read_text())["review"]["at_utc"])
        with self.assertRaisesRegex(ValueError, "Already reviewed"):
            approve(self.root, "Overwrite")

    def test_modified_candidate_cannot_be_approved(self):
        self.candidate()
        (self.root / "synthetic.png").write_bytes(b"altered")
        with self.assertRaisesRegex(ValueError, "changed"):
            approve(self.root, "Review")

    def test_unreviewed_and_version_changes_fail_closed(self):
        fonts = self.root / "assets/fonts"
        fonts.mkdir(parents=True)
        for name in ("Inter.ttf", "IBMPlexSansArabic-Regular.ttf"):
            (fonts / name).write_bytes(b"synthetic")
        class Browser:
            def call(self, _):
                return {"product": "test", "revision": "test", "jsVersion": "test"}
        with patch("resume_print_visual.subprocess.check_output", return_value=b"version test\n"):
            checker = VisualCheck(self.root, {"pdftoppm": "test"}, self.root, Browser())
            manifest = self.candidate()
            manifest["environment"] = checker.environment
            path = self.root / "visual-manifest.json"
            path.write_text(json.dumps(manifest))
            with self.assertRaisesRegex(AssertionError, "unreviewed"):
                VisualCheck(self.root, {"pdftoppm": "test"}, self.root, Browser(), self.root)
            manifest["review"] = {"note": "Explicit review"}
            for key in ("chromium", "poppler", "fonts_sha256", "policy"):
                mutated = copy.deepcopy(manifest)
                mutated["environment"][key] = "changed"
                path.write_text(json.dumps(mutated))
                with self.subTest(key=key), self.assertRaisesRegex(AssertionError, "versions changed"):
                    VisualCheck(self.root, {"pdftoppm": "test"}, self.root, Browser(), self.root)

    def test_missing_visual_pages_fail(self):
        checker = VisualCheck.__new__(VisualCheck)
        checker.images = {"page-1.ppm": {}}
        checker.baseline = self.root
        checker.reviewed = {"images": {"page-1.ppm": {}, "page-2.ppm": {}}}
        with self.assertRaisesRegex(AssertionError, "coverage"):
            checker.finish()

    def test_tracked_evidence_rejected(self):
        with patch("resume_print_visual.subprocess.run") as run:
            run.return_value.returncode = 1
            with self.assertRaisesRegex(ValueError, "git-ignored"):
                evidence_directory(self.root / "tracked", self.root)
            run.return_value.returncode = 0
            self.assertEqual(evidence_directory(self.root / "ignored", self.root),
                             self.root / "ignored")


if __name__ == "__main__":
    unittest.main()
