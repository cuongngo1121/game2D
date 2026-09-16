"""Regression coverage for Area 4's geometry-owned HD route atlas."""

from pathlib import Path
import hashlib
import struct
import unittest


ROOT = Path(__file__).resolve().parent.parent
GEOMETRY_PLATE = "prism_spire_route_background_user_geometry_v2.png"
REFINED_BACKDROP = "prism_spire_route_background_concept_v1_refined_room_detail_safe_junctions_hd_v4.png"
GEOMETRY_PLATE_SHA256 = "bf249cd540a1853b98e89770c82736501d667452fb64b42712ebf8c549825ccf"
LEVEL_FOUR_BOUNDARY_SHA256 = "f84c2b8e01dfe519292b17c563899a26277e9d0683ba0c07294f5ea27977c7e4"
DETAIL_SECTIONS = (
    "combat_1_hd.png",
    "combat_2_hd.png",
    "support_hd.png",
    "combat_3_hd.png",
    "combat_4_hd.png",
    "boss_hd.png",
)


def png_size(path: Path) -> tuple[int, int]:
    with path.open("rb") as image:
        header = image.read(24)
    if header[:8] != b"\x89PNG\r\n\x1a\n":
        raise AssertionError(f"{path.name} is not a PNG")
    return struct.unpack(">II", header[16:24])


class PrismSpireSeamlessBackdropTest(unittest.TestCase):
    def test_runtime_uses_a_geometry_owned_one_piece_atlas(self) -> None:
        """Generated detail cannot change Area 4 topology or cover a junction."""
        geometry = ROOT / "assets" / "backgrounds" / GEOMETRY_PLATE
        asset = ROOT / "assets" / "backgrounds" / REFINED_BACKDROP
        details_dir = ROOT / "assets" / "backgrounds" / "prism_spire_sections_v2_generated"
        room_view = (ROOT / "scripts" / "world" / "room_view.gd").read_text(encoding="utf-8")
        boundary_editor = (ROOT / "scripts" / "world" / "map_boundary_editor.gd").read_text(encoding="utf-8")
        camera_probe = (ROOT / "tests" / "camera_follow_probe.gd").read_text(encoding="utf-8")
        composer = (ROOT / "tools" / "compose_prism_spire_safe_hd_v2.ps1").read_text(encoding="utf-8")
        boundary = ROOT / "data" / "map_boundaries_lv4.json"

        with self.subTest("geometry_plate"):
            self.assertTrue(geometry.is_file())
            if geometry.is_file():
                self.assertEqual(png_size(geometry), (1448, 1086))
                self.assertEqual(hashlib.sha256(geometry.read_bytes()).hexdigest(), GEOMETRY_PLATE_SHA256)
        with self.subTest("atlas"):
            self.assertTrue(asset.is_file())
            if asset.is_file():
                self.assertEqual(png_size(asset), (5792, 4344))
        with self.subTest("detail_sources"):
            for name in DETAIL_SECTIONS:
                detail = details_dir / name
                self.assertTrue(detail.is_file(), name)
                if detail.is_file():
                    self.assertGreaterEqual(min(png_size(detail)), 900, name)
        with self.subTest("runtime_references"):
            for source in (room_view, boundary_editor, camera_probe):
                self.assertIn(REFINED_BACKDROP, source)
                self.assertNotIn("prism_spire_route_background_concept_v1_tiled_restored_hd_v1.png", source)
        with self.subTest("safe_composition"):
            self.assertIn("prism_spire_route_background_user_geometry_v2.png", composer)
            self.assertIn("$atlasWidth = 5120", composer)
            self.assertIn("$atlasHeight = 3840", composer)
            self.assertIn("$junctionKeepouts", composer)
            self.assertEqual(composer.count("# Combat"), 6)
            self.assertIn("New-RoomRegion", composer)
            self.assertIn("[double]$DetailOpacity = 0.88", composer)
            self.assertIn("$matrix.Matrix33 = [single]$DetailOpacity", composer)
            self.assertIn("$attributes.SetColorKey", composer)
            self.assertIn("Geometry plate owns only the physical door/corridor handoff", composer)
        with self.subTest("collision_unchanged"):
            self.assertEqual(hashlib.sha256(boundary.read_bytes()).hexdigest(), LEVEL_FOUR_BOUNDARY_SHA256)


if __name__ == "__main__":
    unittest.main(verbosity=2)
