"""Local artwork release gates; no Roblox execution or network requests."""
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("vfx_audit",ROOT/"tools/vfx_pipeline/audit_assets.py")
audit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audit)


class AssetAuditTests(unittest.TestCase):
    def test_current_exports_validate_without_claiming_publication(self):
        report = audit.inspect()
        self.assertEqual(report["errors"],[])
        self.assertFalse(report["release_ready"])
        self.assertIsNone(report["studio_measurements"])
        self.assertGreater(len(report["placeholder_review"]),0)

    def test_path_traversal_is_rejected(self):
        with self.assertRaises(ValueError):
            audit.inside(ROOT,"../outside.png")

    def test_decode_corrupt_png_and_budget(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder)/"test.png"
            path.write_bytes(b"\x89PNG\r\n\x1a\ncorrupt")
            errors = []
            audit.check_pixels(path,[256,256],errors)
            self.assertTrue(errors)
            Image.new("RGBA",(2048,2),(255,255,255,255)).save(path)
            errors = []
            audit.check_pixels(path,[2048,2],errors)
            self.assertTrue(any("budget" in message for message in errors))

    def test_blank_art_is_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder)/"blank.png"
            Image.new("RGBA",(256,256)).save(path)
            errors = []
            audit.check_pixels(path,[256,256],errors,opaque=True)
            self.assertTrue(errors)

    def test_source_tampering_and_publication_claim_are_rejected(self):
        study = json.loads(audit.STUDY.read_text())
        study["assets"]["core"]["sources"][0]["sha256"] = "tampered"
        study["assets"]["core"]["studio_verified"] = True
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder)/"manifest.json"
            path.write_text(json.dumps(study))
            errors = audit.inspect(study_path=path)["errors"]
            self.assertTrue(any("source hash mismatch" in value for value in errors))
            self.assertTrue(any("publication receipt" in value for value in errors))


if __name__ == "__main__":
    unittest.main()
