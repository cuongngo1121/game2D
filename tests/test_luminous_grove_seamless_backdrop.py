"""Regression coverage for Area 3's user-approved one-piece HD atlas."""

from pathlib import Path
import struct
import unittest


ROOT = Path(__file__).resolve().parent.parent
REFINED_BACKDROP = "luminous_grove_route_background_user_final_fixed_hd_v29.png"
USER_APPROVED_BACKDROP_SHA256 = "418bff03f04da9dc376875ed2a60f44066d8b58b136ee65fc9f923173ad21153"
RETIRED_FLOOR_DETAIL_TILE = "assets/backgrounds/luminous_grove_floor_detail_tile_v11.png"
COMBAT_ONE_V12_SOURCE = "assets/backgrounds/luminous_grove_sections_v12/combat_1_refined_hd_v12.png"
REFINED_SECTIONS = tuple(
    "assets/backgrounds/luminous_grove_sections_v15_user_six/" + name
    for name in (
        "combat_1_refined_hd.png",
        "combat_2_refined_hd.png",
        "combat_3_refined_hd.png",
        "support_refined_hd.png",
        "combat_4_refined_hd.png",
        "boss_refined_hd.png",
    )
)
USER_SIX_SECTIONS = {
    "combat_1_refined_hd.png": "15e2f9ad29a4de67f6ac52521f5251c676cc2e8182f6518fa47dcb3b3855f67b",
    "combat_2_refined_hd.png": "9367e1e41659779550057c9d1d55ae417e3e3f7ed39a59d582d7fccf4de1183d",
    "combat_3_refined_hd.png": "8359ed8183ef7b621483b732e58ae456ef4c219f34ef8ca23cfc115be986a38e",
    "support_refined_hd.png": "178d0ec43f99caf71f54737c325b948d0cf6e0e7208c1301ecaf9f02a0cfc431",
    "combat_4_refined_hd.png": "3343ea5c9e9b6bff623a156984b6c5d87be91161dd9ed59640013b78e3697a07",
    "boss_refined_hd.png": "ba25f6017c0106b2637781e7e44ecfda61d6f0b5ff64f373c39d956b0dfaf6e2",
}
def png_size(path: Path) -> tuple[int, int]:
    with path.open("rb") as image:
        header = image.read(24)
    if header[:8] != b"\x89PNG\r\n\x1a\n":
        raise AssertionError(f"{path.name} is not a PNG")
    return struct.unpack(">II", header[16:24])


class LuminousGroveRefinedBackdropTest(unittest.TestCase):
    def test_runtime_uses_complete_direct_source_section_atlas(self) -> None:
        """The complete user-approved atlas remains the one-piece runtime texture."""
        asset = ROOT / "assets" / "backgrounds" / REFINED_BACKDROP
        room_view = (ROOT / "scripts" / "world" / "room_view.gd").read_text(encoding="utf-8")
        boundary_editor = (ROOT / "scripts" / "world" / "map_boundary_editor.gd").read_text(encoding="utf-8")
        composer = (ROOT / "tools" / "compose_luminous_grove_v10_hd.ps1").read_text(encoding="utf-8")

        with self.subTest("asset"):
            self.assertTrue(asset.is_file())
            if asset.is_file():
                self.assertEqual(png_size(asset), (5120, 3840))
                import hashlib
                self.assertEqual(hashlib.sha256(asset.read_bytes()).hexdigest(), USER_APPROVED_BACKDROP_SHA256)
            self.assertTrue(all((ROOT / section).is_file() for section in REFINED_SECTIONS))
            self.assertTrue((ROOT / COMBAT_ONE_V12_SOURCE).is_file())
            if (ROOT / COMBAT_ONE_V12_SOURCE).is_file():
                self.assertGreaterEqual(min(png_size(ROOT / COMBAT_ONE_V12_SOURCE)), 1024)
            self.assertFalse((ROOT / RETIRED_FLOOR_DETAIL_TILE).exists())
            user_sections_dir = ROOT / "assets/backgrounds/luminous_grove_sections_v15_user_six"
            for name, expected_hash in USER_SIX_SECTIONS.items():
                with self.subTest(user_section=name):
                    section = user_sections_dir / name
                    self.assertTrue(section.is_file())
                    if section.is_file():
                        import hashlib
                        self.assertEqual(hashlib.sha256(section.read_bytes()).hexdigest(), expected_hash)
        with self.subTest("gameplay_runtime"):
            self.assertIn(REFINED_BACKDROP, room_view)
            self.assertNotIn(RETIRED_FLOOR_DETAIL_TILE, room_view)
            self.assertNotIn("draw_luminous_grove_detail_overlay", room_view)
        with self.subTest("boundary_editor"):
            self.assertIn(REFINED_BACKDROP, boundary_editor)
        with self.subTest("composition"):
            self.assertIn("BuildGeometryPlate", composer)
            self.assertIn("BuildSectionCoverage", composer)
            self.assertIn("coverage[coverageOffset] > 1", composer)
            self.assertIn("IsVoid(geometryPixels", composer)
            self.assertIn("IsNearVoid", composer)
            self.assertIn("GeometryMarginAtlasPixels", composer)
            self.assertIn("UseFloorPolygonMask", composer)
            self.assertIn("NativeFloorPolygons", composer)
            self.assertIn("SafeFloorAlpha", composer)
            # The wall plate cannot be left as the 1448 px geometry source while
            # only the floor receives the section source.  Runtime zoom makes
            # that exact split visible as soft walls around a sharp floor.
            self.assertIn("MaximumWallAlpha", composer)
            self.assertIn("SafeWallAlpha", composer)
            self.assertIn("wallAlpha", composer)
            self.assertIn("DirectSectionStitch", composer)
            self.assertIn("IsDirectSectionOwner", composer)
            self.assertIn("DirectSectionWallReachAtlasPixels", composer)
            self.assertIn("(!directSectionStitch && IsVoid(detailPixels, detailOffset))", composer)
            self.assertIn("directSectionStitch\n                                        ? 1.0", composer)


if __name__ == "__main__":
    unittest.main(verbosity=2)
