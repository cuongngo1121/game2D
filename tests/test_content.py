"""Static content/assets contract checks. Does not simulate Godot gameplay.

Run: python tests/test_content.py
Standard-library only; no network or mutable player save data involved.
"""
from __future__ import annotations

import array
from collections import deque
import hashlib
import json
import math
from pathlib import Path
import struct
import sys
import unittest
import wave
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]


def read_data(name):
    return json.loads((ROOT / "data" / f"{name}.json").read_text(encoding="utf-8"))


def png_size(path):
    """Return a PNG's native size without adding an image-library dependency."""
    header = path.read_bytes()[:24]
    if header[:8] != b"\x89PNG\r\n\x1a\n" or header[12:16] != b"IHDR":
        raise ValueError(f"Invalid PNG: {path}")
    return struct.unpack(">II", header[16:24])


def polygon_area(points):
    return sum(
        x1 * y2 - y1 * x2
        for (x1, y1), (x2, y2) in zip(points, points[1:] + points[:1])
    ) / 2


def point_in_polygon(point, polygon):
    """Odd-even containment is sufficient for the deliberately interior seam probes."""
    x, y = point
    inside = False
    for (x1, y1), (x2, y2) in zip(polygon, polygon[1:] + polygon[:1]):
        if (y1 > y) != (y2 > y) and x < (x2 - x1) * (y - y1) / (y2 - y1) + x1:
            inside = not inside
    return inside


def segments_properly_intersect(a, b, c, d):
    def side(start, end, point):
        return (end[0] - start[0]) * (point[1] - start[1]) - (end[1] - start[1]) * (point[0] - start[0])

    ab_c, ab_d = side(a, b, c), side(a, b, d)
    cd_a, cd_b = side(c, d, a), side(c, d, b)
    return (ab_c > 0) != (ab_d > 0) and (cd_a > 0) != (cd_b > 0) and all(value != 0 for value in [ab_c, ab_d, cd_a, cd_b])


def polygon_self_intersects(points):
    count = len(points)
    for first in range(count):
        first_next = (first + 1) % count
        for second in range(first + 1, count):
            second_next = (second + 1) % count
            if first == second or first_next == second or second_next == first:
                continue
            if segments_properly_intersect(points[first], points[first_next], points[second], points[second_next]):
                return True
    return False


def glyphs(path):
    """Read supported Unicode mappings from TrueType cmap formats 4 and 12."""
    data = path.read_bytes()
    u16 = lambda offset: struct.unpack_from(">H", data, offset)[0]
    u32 = lambda offset: struct.unpack_from(">I", data, offset)[0]
    table = None
    for index in range(u16(4)):
        offset = 12 + index * 16
        if data[offset:offset+4] == b"cmap":
            table = u32(offset+8)
            break
    if table is None:
        raise ValueError("Missing cmap")
    points = set()
    for index in range(u16(table+2)):
        offset = table+4+index*8
        platform, encoding = u16(offset), u16(offset+2)
        if platform not in [0,3]:
            continue
        sub = table+u32(offset+4)
        form = u16(sub)
        if form == 4:
            segments=u16(sub+6)//2
            endbase=sub+14
            startbase=endbase+segments*2+2
            deltabase=startbase+segments*2
            rangebase=deltabase+segments*2
            for idx in range(segments):
                start,end=u16(startbase+idx*2),u16(endbase+idx*2)
                delta=u16(deltabase+idx*2)
                roffset=u16(rangebase+idx*2)
                for point in range(start,min(end,65534)+1):
                    if roffset:
                        glyph=u16(rangebase+idx*2+roffset+(point-start)*2)
                        if glyph:
                            glyph=(glyph+delta)%65536
                    else:
                        glyph=(point+delta)%65536
                    if glyph:
                        points.add(point)
        elif form == 12:
            for idx in range(u32(sub+12)):
                group=sub+16+idx*12
                start,end,first=u32(group),u32(group+4),u32(group+8)
                points.update(range(start+(1 if first==0 else 0),end+1))
    return points


class ContentContract(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.weapons=read_data("weapons")
        cls.upgrades=read_data("upgrades")
        cls.enemies=read_data("enemies")
        cls.stages=read_data("stages")

    def test_required_content_and_unique_ids(self):
        for group,expected in [(self.weapons,12),(self.upgrades,13),(self.enemies,10),(self.stages,5)]:
            self.assertGreaterEqual(len(group),expected)
            self.assertEqual(len(group),len({row["id"] for row in group}))
        self.assertEqual([stage["id"] for stage in self.stages],list(range(5)))
        self.assertEqual([stage["bpm"] for stage in self.stages],[90,100,110,120,128])
        self.assertEqual(len({stage["boss"] for stage in self.stages}),5)

    def test_weapon_and_upgrade_contracts(self):
        ids={row["id"] for row in self.weapons}
        self.assertEqual(ids,{"pistol","smg","shotgun","rail","beam","disc","arc","wave","glitch","orbit","blade","chord"})
        for weapon in self.weapons:
            with self.subTest(weapon=weapon["id"]):
                self.assertEqual(weapon["id"],weapon["behavior"])
                for field in ["cooldown","damage","range"]:
                    self.assertGreater(weapon[field],0)
                for field in ["energy","speed"]:
                    self.assertGreaterEqual(weapon[field],0)
                for field in ["name","description"]:
                    self.assertTrue(weapon[field].strip())
                for field in ["icon","model","sprite","sfx"]:
                    self.assertTrue((ROOT/weapon[field].removeprefix("res://")).is_file())
        self.assertEqual(next(w for w in self.weapons if w["id"]=="pistol")["energy"],0)
        for upgrade in self.upgrades:
            self.assertGreater(upgrade["max_stacks"],0)
            self.assertTrue(set(upgrade["compatible"])<=ids)

    def test_stage_geometry_and_reachability(self):
        checked=0
        for stage in self.stages:
            self.assertGreaterEqual(len(stage["room_templates"]),3)
            self.assertTrue(set(stage["enemy_ids"])<={enemy["id"] for enemy in self.enemies})
            templates=stage["room_templates"]+[stage["boss_obstacles"]]
            for index,template in enumerate(templates):
                for x,y,w,h in template:
                    self.assertGreater(w,0)
                    self.assertGreater(h,0)
                    self.assertGreaterEqual(x,64)
                    self.assertGreaterEqual(y,112)
                    self.assertLessEqual(x+w,1216)
                    self.assertLessEqual(y+h,592)
                for radius in [11,15]:
                    with self.subTest(stage=stage["id"],template=index,radius=radius):
                        # 8 px grid spans the playable area with a margin >= radius.
                        def valid(x,y):
                            return not any(a-radius<x<a+w+radius and b-radius<y<b+h+radius for a,b,w,h in template)
                        free={(x,y) for x in range(80,1201,8) for y in range(128,577,8) if valid(x,y)}
                        spawn=(128,352)  # nearest lattice point to live spawn (130,350).
                        self.assertIn(spawn,free)
                        seen={spawn}
                        queue=deque([spawn])
                        while queue:
                            x,y=queue.popleft()
                            for neighbor in [(x+8,y),(x-8,y),(x,y+8),(x,y-8)]:
                                if neighbor in free and neighbor not in seen:
                                    seen.add(neighbor)
                                    queue.append(neighbor)
                        self.assertEqual(seen,free,"A free floor cell is disconnected from the player spawn")
                        self.assertIn((1152,352),seen)
                        # Entry/exit lane remains open across the required vertical span.
                        for y in range(200,501,8):
                            for x in [114,120,130,1150]:
                                self.assertTrue(valid(x,y),f"Blocked portal lane: {x},{y}")
                        checked+=1
        self.assertEqual(checked,40)

    def test_bass_foundry_route_art_and_boundaries(self):
        """Area 2's image and authored collision data must stay in one coordinate space."""
        asset = ROOT / "assets/backgrounds/bass_foundry_route_background_concept_v5_amber_foundry.png"
        hd_asset = ROOT / "assets/backgrounds/bass_foundry_route_background_concept_v5_amber_foundry_tiled_restored_hd.png"
        boundary = read_data("map_boundaries_lv2")
        self.assertTrue(asset.is_file())
        self.assertEqual(png_size(asset), (1448, 1086))
        self.assertTrue(hd_asset.is_file())
        self.assertEqual(png_size(hd_asset), (5120, 3840))
        self.assertEqual(boundary["version"], 1)
        self.assertEqual(boundary["art_size"], [1448, 1086])
        rooms = boundary["rooms"]
        self.assertEqual(set(rooms), {str(index) for index in range(6)})
        polygons = {int(index): points for index, points in rooms.items()}
        for index, points in polygons.items():
            with self.subTest(room=index):
                self.assertGreaterEqual(len(points), 3)
                self.assertGreater(abs(polygon_area(points)), 64)
                self.assertTrue(all(0 <= x <= 1448 and 0 <= y <= 1086 for x, y in points))
                self.assertTrue(all(first != second for first, second in zip(points, points[1:] + points[:1])))
                self.assertFalse(polygon_self_intersects(points))
        # Interior samples prove every intended doorway has an actual collision
        # overlap. This preserves C1 -> C2 -> C3 -> C4 -> Boss, plus support.
        for left, right, sample in [
            (0, 1, (287, 700)),
            (1, 2, (605, 530)),
            (1, 4, (580, 790)),
            (2, 3, (900, 395)),
            (3, 5, (1130, 292)),
        ]:
            with self.subTest(link=f"{left}-{right}"):
                self.assertTrue(point_in_polygon(sample, polygons[left]))
                self.assertTrue(point_in_polygon(sample, polygons[right]))

    def test_luminous_grove_hd_route_art_and_boundaries(self):
        """Area 3 restores each route section at HD without changing its collision space."""
        asset = ROOT / "assets/backgrounds/luminous_grove_route_background_concept_v1.png"
        hd_asset = ROOT / "assets/backgrounds/luminous_grove_route_background_user_final_fixed_hd_v29.png"
        geometry_source = ROOT / "assets/backgrounds/luminous_grove_route_background_concept_v1_boundary_cleanup_source_v10.png"
        main_source = (ROOT / "scripts/main.gd").read_text(encoding="utf-8")
        boundary = read_data("map_boundaries_lv3")
        self.assertTrue(asset.is_file())
        self.assertEqual(png_size(asset), (1448, 1086))
        self.assertTrue(geometry_source.is_file())
        self.assertEqual(png_size(geometry_source), (1448, 1086))
        self.assertTrue(hd_asset.is_file())
        self.assertEqual(png_size(hd_asset), (5120, 3840))
        self.assertIn("const LEVEL_THREE_WORLD_SCALE := 3.0", main_source)
        self.assertIn(
            "return Vector2(arena.size.x / LEVEL_THREE_ART_SIZE.x, arena.size.y / LEVEL_THREE_ART_SIZE.y)",
            main_source,
        )
        self.assertEqual(boundary["version"], 1)
        self.assertEqual(boundary["art_size"], [1448, 1086])
        rooms = boundary["rooms"]
        self.assertEqual(set(rooms), {str(index) for index in range(6)})
        polygons = {int(index): points for index, points in rooms.items()}
        for index, points in polygons.items():
            with self.subTest(room=index):
                self.assertGreaterEqual(len(points), 3)
                self.assertGreater(abs(polygon_area(points)), 64)
                self.assertTrue(all(0 <= x <= 1448 and 0 <= y <= 1086 for x, y in points))
                self.assertTrue(all(first != second for first, second in zip(points, points[1:] + points[:1])))
                self.assertFalse(polygon_self_intersects(points))
        # Interior samples prove every route doorway keeps real collision overlap:
        # C1 -> C2 -> C3 -> C4 -> Boss, with the support branch off C2.
        for left, right, sample in [
            (0, 1, (192, 798)),
            (1, 2, (650, 520)),
            (1, 4, (690, 520)),
            (2, 3, (1000, 445)),
            (3, 5, (1195, 370)),
        ]:
            with self.subTest(link=f"{left}-{right}"):
                self.assertTrue(point_in_polygon(sample, polygons[left]))
                self.assertTrue(point_in_polygon(sample, polygons[right]))

    def test_prism_spire_hd_route_art_and_boundaries(self):
        """Area 4 keeps its authored route layout while receiving HD section detail."""
        asset = ROOT / "assets/backgrounds/prism_spire_route_background_user_geometry_v2.png"
        hd_asset = ROOT / "assets/backgrounds/prism_spire_route_background_concept_v1_refined_room_detail_safe_junctions_hd_v4.png"
        boundary = read_data("map_boundaries_lv4")
        main_source = (ROOT / "scripts/main.gd").read_text(encoding="utf-8")
        self.assertTrue(asset.is_file())
        self.assertEqual(png_size(asset), (1448, 1086))
        self.assertTrue(hd_asset.is_file())
        self.assertEqual(png_size(hd_asset), (5792, 4344))
        self.assertIn("const LEVEL_FOUR_WORLD_SCALE := 3.0", main_source)
        self.assertIn("LEVEL_FOUR_ART_SIZE.x * LEVEL_FOUR_WORLD_SCALE", main_source)
        self.assertIn("return Vector2(arena.size.x / LEVEL_FOUR_ART_SIZE.x, arena.size.y / LEVEL_FOUR_ART_SIZE.y)", main_source)
        self.assertEqual(boundary["version"], 1)
        self.assertEqual(boundary["art_size"], [1448, 1086])
        polygons = {int(index): points for index, points in boundary["rooms"].items()}
        self.assertEqual(set(polygons), set(range(6)))
        for index, points in polygons.items():
            with self.subTest(room=index):
                self.assertGreaterEqual(len(points), 3)
                self.assertGreater(abs(polygon_area(points)), 64)
                self.assertTrue(all(0 <= x <= 1448 and 0 <= y <= 1086 for x, y in points))
                self.assertTrue(all(first != second for first, second in zip(points, points[1:] + points[:1])))
                self.assertFalse(polygon_self_intersects(points))
        for left, right, sample in [
            (0, 1, (250, 820)),
            (1, 2, (640, 550)),
            (1, 4, (580, 720)),
            (2, 3, (880, 330)),
            (3, 5, (1175, 180)),
        ]:
            with self.subTest(link=f"{left}-{right}"):
                self.assertTrue(point_in_polygon(sample, polygons[left]))
                self.assertTrue(point_in_polygon(sample, polygons[right]))

    def test_silent_core_hd_route_art_and_boundaries(self):
        """Area 5 is an open route with one continuous HD atlas and native polygons."""
        asset = ROOT / "assets/backgrounds/silent_core_route_background_concept_v1.png"
        material = ROOT / "assets/backgrounds/silent_core_route_background_concept_v1_material_detail_v1.png"
        hd_asset = ROOT / "assets/backgrounds/silent_core_route_background_concept_v1_refined_room_detail_safe_junctions_hd_v2.png"
        composer = ROOT / "tools/compose_silent_core_room_detail_hd.ps1"
        detail_sources = ROOT / "assets/backgrounds/silent_core_sections_v2_generated"
        boundary = read_data("map_boundaries_lv5")
        main_source = (ROOT / "scripts/main.gd").read_text(encoding="utf-8")
        room_view_source = (ROOT / "scripts/world/room_view.gd").read_text(encoding="utf-8")
        editor_source = (ROOT / "scripts/world/map_boundary_editor.gd").read_text(encoding="utf-8")
        graph_source = (ROOT / "scripts/core/level_graph.gd").read_text(encoding="utf-8")
        self.assertTrue(asset.is_file())
        self.assertEqual(png_size(asset), (1448, 1086))
        self.assertTrue(material.is_file())
        self.assertEqual(png_size(material), (1448, 1086))
        self.assertTrue(hd_asset.is_file())
        self.assertEqual(png_size(hd_asset), (5792, 4344))
        for detail_name in (
            "combat_1_hd.png", "combat_2_hd.png", "combat_3_hd.png",
            "combat_4_hd.png", "support_hd.png", "boss_hd.png",
        ):
            detail = detail_sources / detail_name
            with self.subTest(detail=detail_name):
                self.assertTrue(detail.is_file())
                if detail.is_file():
                    self.assertGreaterEqual(min(png_size(detail)), 900)
        self.assertTrue(composer.is_file())
        composer_source = composer.read_text(encoding="utf-8")
        self.assertIn("$sections", composer_source)
        self.assertIn("$junctionKeepouts", composer_source)
        self.assertIn("[double]$DetailOpacity = 0.88", composer_source)
        self.assertIn("Geometry first", composer_source)
        self.assertIn("const LEVEL_FIVE_WORLD_SCALE := 3.0", main_source)
        self.assertIn("LEVEL_FIVE_ART_SIZE.x * LEVEL_FIVE_WORLD_SCALE", main_source)
        self.assertIn("return stage_index >= 0 and stage_index <= 4", main_source)
        self.assertIn("level_five_art_polygons", main_source)
        self.assertIn("silent_core_route_background_concept_v1_refined_room_detail_safe_junctions_hd_v2.png", room_view_source)
        self.assertIn("silent_core_route_background_concept_v1_refined_room_detail_safe_junctions_hd_v2.png", editor_source)
        self.assertIn("var branch: int = 1 if stage <= 3 else 3", graph_source)
        self.assertEqual(boundary["version"], 1)
        self.assertEqual(boundary["art_size"], [1448, 1086])
        polygons = {int(index): points for index, points in boundary["rooms"].items()}
        self.assertEqual(set(polygons), set(range(6)))
        for index, points in polygons.items():
            with self.subTest(room=index):
                self.assertGreaterEqual(len(points), 3)
                self.assertGreater(abs(polygon_area(points)), 64)
                self.assertTrue(all(0 <= x <= 1448 and 0 <= y <= 1086 for x, y in points))
                self.assertTrue(all(first != second for first, second in zip(points, points[1:] + points[:1])))
                self.assertFalse(polygon_self_intersects(points))
        # The visible route is C1 -> C2 -> C3 -> C4 -> Boss, while Support is
        # the upper-left branch attached to C4. Samples must stay in a genuine
        # shared doorway interior rather than merely touching polygon edges.
        for left, right, sample in [
            (0, 1, (250, 700)),
            (1, 2, (707, 620)),
            (2, 3, (900, 420)),
            (3, 4, (760, 250)),
            (3, 5, (1100, 250)),
        ]:
            with self.subTest(link=f"{left}-{right}"):
                self.assertTrue(point_in_polygon(sample, polygons[left]))
                self.assertTrue(point_in_polygon(sample, polygons[right]))

    def test_final_route_concept_maps_are_exported(self):
        expected = {
            "luminous_grove_route_background_concept_v1.png": (1448, 1086),
            "prism_spire_route_background_concept_v1.png": (1448, 1086),
            "silent_core_route_background_concept_v1.png": (1448, 1086),
        }
        for filename, dimensions in expected.items():
            with self.subTest(asset=filename):
                path = ROOT / "assets/backgrounds" / filename
                self.assertTrue(path.is_file())
                self.assertEqual(png_size(path), dimensions)

    def test_svg_assets_parse_and_required_sprites_exist(self):
        paths=list((ROOT/"assets").rglob("*.svg"))
        self.assertGreaterEqual(len(paths),55)
        for path in paths:
            tree=ET.parse(path)
            self.assertEqual(tree.getroot().tag,"{http://www.w3.org/2000/svg}svg")
            self.assertTrue(tree.getroot().get("viewBox"))
        for enemy in self.enemies:
            self.assertTrue((ROOT/enemy["sprite"].removeprefix("res://")).is_file())
        for stage in self.stages:
            self.assertTrue((ROOT/stage["boss_sprite"].removeprefix("res://")).is_file())
        for state in ["idle","run_0","run_1","attack","dash","hurt","death"]:
            self.assertTrue((ROOT/f"assets/sprites/player_{state}.svg").is_file())

    def test_music_alignment_and_clean_file_boundaries(self):
        hashes=set()
        for stage in self.stages:
            expected=round(16*60/stage["bpm"]*22050)
            for variant in ["explore","combat","boss"]:
                path=ROOT/f"assets/audio/stage_{stage['id']+1}_{variant}.wav"
                with wave.open(str(path),"rb") as source:
                    self.assertEqual((source.getnchannels(),source.getsampwidth(),source.getframerate()),(1,2,22050))
                    self.assertEqual(source.getnframes(),expected)
                    raw=source.readframes(expected)
                values=array.array("h",raw)
                if sys.byteorder!="little":
                    values.byteswap()
                self.assertEqual(values[0],0)
                self.assertEqual(values[-1],0)
                peak=max(abs(value) for value in values)
                self.assertLessEqual(peak,round(.86*32767)+1)
                self.assertGreater(peak,1000)
                self.assertGreater(math.sqrt(sum(v*v for v in values)/len(values)),300)
                self.assertLessEqual(abs(expected-16*60/stage["bpm"]*22050),.5)
                hashes.add(hashlib.sha256(raw).hexdigest())
        self.assertEqual(len(hashes),15,"Mixes or stage compositions are byte-identical")

    def test_required_sound_effects(self):
        events=["shoot","hit","dash","perfect","hurt","pickup","door","buy","boss","pulse"]
        names=events+["weapon_"+weapon["id"] for weapon in self.weapons]
        for name in names:
            with wave.open(str(ROOT/f"assets/audio/sfx_{name}.wav"),"rb") as source:
                self.assertGreater(source.getnframes(),500)
                self.assertLess(source.getnframes(),22050*2)
                self.assertEqual(source.getframerate(),22050)
        self.assertEqual(len(list((ROOT/"assets/audio").glob("sfx_*.wav"))),26)

    def test_vietnamese_font_coverage(self):
        text=""
        for path in (ROOT/"data").glob("*.json"):
            text+=path.read_text(encoding="utf-8")
        text+="ÀÁẢÃẠĂẰẮẲẴẶÂẦẤẨẪẬÈÉẺẼẸÊỀẾỂỄỆÌÍỈĨỊÒÓỎÕỌÔỒỐỔỖỘƠỜỚỞỠỢÙÚỦŨỤƯỪỨỬỮỰỲÝỶỸỴĐ"
        text+=text.lower()
        needed={ord(char) for char in text if not char.isspace()}
        for filename in ["NotoSans-Regular.ttf","NotoSans-Bold.ttf"]:
            available=glyphs(ROOT/"assets/fonts"/filename)
            missing=needed-available
            self.assertFalse(missing,f"{filename} missing: {''.join(chr(code) for code in sorted(missing))}")
        self.assertIn("SIL OPEN FONT LICENSE",(ROOT/"assets/fonts/OFL.txt").read_text(encoding="utf-8"))

    def test_audio_manifest_matches_files(self):
        manifest=json.loads((ROOT/"assets/audio/manifest.json").read_text(encoding="utf-8"))
        self.assertEqual(len(manifest["tracks"]),41)
        self.assertEqual(len({entry["path"] for entry in manifest["tracks"]}),41)
        for entry in manifest["tracks"]:
            with wave.open(str(ROOT/entry["path"]),"rb") as source:
                self.assertEqual(source.getnframes(),entry["frames"])
                self.assertEqual(source.getframerate(),entry["rate"])


if __name__=="__main__":
    unittest.main(verbosity=2)
