"""Generate the 32x32 pixel combat roster for NEON RESONANCE.

The art is deliberately made from integer primitives so every PNG remains easy
to open and edit in Pixelorama.  No filtering, antialiasing, or external asset
is required to regenerate the files.
"""

from __future__ import annotations

import json
import math
import struct
import zlib
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "sprites" / "pixel_32"
ENEMY_OUT = OUT / "enemies"
WEAPON_OUT = OUT / "weapons"
SIZE = 32
SCALE = 8

PALETTE = {
    "transparent": (0, 0, 0, 0),
    "ink": (9, 16, 42, 255),
    "deep": (15, 27, 63, 255),
    "navy": (24, 41, 87, 255),
    "blue": (39, 104, 171, 255),
    "cyan": (53, 231, 255, 255),
    "ice": (149, 246, 255, 255),
    "violet": (133, 109, 255, 255),
    "purple": (93, 62, 190, 255),
    "pink": (255, 92, 137, 255),
    "coral": (255, 145, 109, 255),
    "orange": (255, 189, 105, 255),
    "mint": (85, 246, 191, 255),
    "green": (40, 165, 133, 255),
    "white": (230, 247, 255, 255),
}


def rgba(name: str) -> tuple[int, int, int, int]:
    return PALETTE[name]


class PixelSprite:
    def __init__(self, width: int = SIZE, height: int = SIZE) -> None:
        self.width = width
        self.height = height
        self.pixels = [[rgba("transparent") for _ in range(width)] for _ in range(height)]

    def set(self, x: int, y: int, color: str) -> None:
        if 0 <= x < self.width and 0 <= y < self.height:
            self.pixels[y][x] = rgba(color)

    def rect(self, x: int, y: int, width: int, height: int, color: str) -> None:
        for yy in range(y, y + height):
            for xx in range(x, x + width):
                self.set(xx, yy, color)

    def line(self, x0: int, y0: int, x1: int, y1: int, color: str) -> None:
        dx = abs(x1 - x0)
        sx = 1 if x0 < x1 else -1
        dy = -abs(y1 - y0)
        sy = 1 if y0 < y1 else -1
        error = dx + dy
        while True:
            self.set(x0, y0, color)
            if x0 == x1 and y0 == y1:
                return
            twice = 2 * error
            if twice >= dy:
                error += dy
                x0 += sx
            if twice <= dx:
                error += dx
                y0 += sy

    def polygon(self, points: list[tuple[int, int]], color: str) -> None:
        if len(points) < 3:
            return
        min_y = max(0, min(point[1] for point in points))
        max_y = min(self.height - 1, max(point[1] for point in points))
        for y in range(min_y, max_y + 1):
            intersections: list[int] = []
            for index, first in enumerate(points):
                second = points[(index + 1) % len(points)]
                x1, y1 = first
                x2, y2 = second
                if y1 == y2:
                    continue
                if min(y1, y2) <= y < max(y1, y2):
                    x = x1 + (y - y1) * (x2 - x1) / (y2 - y1)
                    intersections.append(math.floor(x))
            intersections.sort()
            for index in range(0, len(intersections) - 1, 2):
                for x in range(intersections[index], intersections[index + 1] + 1):
                    self.set(x, y, color)

    def circle(self, cx: int, cy: int, radius: int, color: str) -> None:
        radius_squared = radius * radius
        for y in range(cy - radius, cy + radius + 1):
            for x in range(cx - radius, cx + radius + 1):
                if (x - cx) ** 2 + (y - cy) ** 2 <= radius_squared:
                    self.set(x, y, color)

    def ring(self, cx: int, cy: int, radius: int, thickness: int, color: str) -> None:
        outer = radius * radius
        inner = max(0, radius - thickness) ** 2
        for y in range(cy - radius, cy + radius + 1):
            for x in range(cx - radius, cx + radius + 1):
                distance = (x - cx) ** 2 + (y - cy) ** 2
                if inner <= distance <= outer:
                    self.set(x, y, color)

    def diamond(self, cx: int, cy: int, radius: int, color: str) -> None:
        self.polygon(
            [(cx, cy - radius), (cx + radius, cy), (cx, cy + radius), (cx - radius, cy)],
            color,
        )

    def scaled(self, scale: int = SCALE) -> "PixelSprite":
        result = PixelSprite(self.width * scale, self.height * scale)
        for y, row in enumerate(self.pixels):
            for x, color in enumerate(row):
                for yy in range(y * scale, (y + 1) * scale):
                    for xx in range(x * scale, (x + 1) * scale):
                        result.pixels[yy][xx] = color
        return result


def png_chunk(kind: bytes, data: bytes) -> bytes:
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)


def write_png(path: Path, sprite: PixelSprite) -> None:
    raw = b"".join(b"\x00" + b"".join(bytes(pixel) for pixel in row) for row in sprite.pixels)
    header = struct.pack(">IIBBBBB", sprite.width, sprite.height, 8, 6, 0, 0, 0)
    payload = b"\x89PNG\r\n\x1a\n" + png_chunk(b"IHDR", header)
    payload += png_chunk(b"IDAT", zlib.compress(raw, level=9))
    payload += png_chunk(b"IEND", b"")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(payload)


def outline_polygon(sprite: PixelSprite, outer: list[tuple[int, int]], inner: list[tuple[int, int]], fill: str) -> None:
    sprite.polygon(outer, "ink")
    sprite.polygon(inner, fill)


def draw_enemy(kind: str) -> PixelSprite:
    sprite = PixelSprite()

    if kind == "drone":
        outline_polygon(sprite, [(3, 16), (9, 7), (23, 7), (29, 16), (23, 25), (9, 25)], [(7, 16), (11, 10), (21, 10), (25, 16), (21, 22), (11, 22)], "navy")
        sprite.line(4, 16, 9, 16, "cyan")
        sprite.line(23, 16, 28, 16, "cyan")
        sprite.line(10, 10, 22, 22, "blue")
        sprite.line(22, 10, 10, 22, "blue")
        sprite.circle(16, 16, 4, "ink")
        sprite.circle(16, 16, 2, "orange")
        sprite.set(16, 15, "ice")
    elif kind == "fan":
        sprite.circle(16, 16, 12, "ink")
        sprite.circle(16, 16, 9, "navy")
        for points in [[(16, 14), (13, 5), (16, 3), (19, 5)], [(18, 16), (27, 13), (29, 16), (27, 19)], [(16, 18), (19, 27), (16, 29), (13, 27)], [(14, 16), (5, 19), (3, 16), (5, 13)]]:
            sprite.polygon(points, "violet")
        sprite.circle(16, 16, 4, "ink")
        sprite.circle(16, 16, 2, "coral")
        sprite.set(16, 16, "white")
    elif kind == "charger":
        outline_polygon(sprite, [(3, 16), (9, 7), (23, 7), (29, 16), (23, 25), (9, 25)], [(7, 16), (11, 10), (21, 10), (25, 16), (21, 22), (11, 22)], "deep")
        sprite.polygon([(21, 10), (28, 16), (21, 22)], "coral")
        sprite.polygon([(22, 13), (26, 16), (22, 19)], "orange")
        sprite.rect(8, 13, 10, 2, "cyan")
        sprite.rect(8, 17, 8, 2, "blue")
        sprite.line(8, 22, 14, 22, "pink")
    elif kind == "turret":
        sprite.polygon([(5, 12), (11, 7), (23, 7), (27, 12), (27, 24), (5, 24)], "ink")
        sprite.rect(8, 13, 16, 10, "navy")
        sprite.rect(15, 5, 5, 9, "ink")
        sprite.rect(16, 4, 3, 9, "violet")
        sprite.rect(19, 14, 10, 4, "ink")
        sprite.rect(21, 15, 9, 2, "cyan")
        sprite.circle(14, 18, 4, "ink")
        sprite.circle(14, 18, 2, "orange")
        sprite.rect(8, 23, 4, 3, "blue")
        sprite.rect(20, 23, 4, 3, "blue")
    elif kind == "splitter":
        sprite.polygon([(16, 2), (21, 10), (29, 11), (23, 17), (26, 27), (16, 22), (6, 27), (9, 17), (3, 11), (11, 10)], "ink")
        sprite.polygon([(16, 6), (19, 12), (25, 13), (20, 17), (22, 23), (16, 19), (10, 23), (12, 17), (7, 13), (13, 12)], "purple")
        sprite.diamond(16, 15, 5, "violet")
        sprite.diamond(16, 15, 2, "orange")
        sprite.set(16, 14, "white")
        sprite.line(5, 10, 9, 12, "pink")
        sprite.line(27, 10, 23, 12, "pink")
    elif kind == "support":
        sprite.ring(16, 16, 12, 3, "ink")
        sprite.ring(16, 16, 9, 2, "green")
        sprite.ring(16, 16, 6, 2, "mint")
        sprite.rect(14, 4, 4, 7, "ink")
        sprite.rect(15, 4, 2, 6, "ice")
        sprite.rect(14, 21, 4, 7, "ink")
        sprite.rect(15, 22, 2, 6, "ice")
        sprite.rect(4, 14, 7, 4, "ink")
        sprite.rect(4, 15, 6, 2, "ice")
        sprite.rect(21, 14, 7, 4, "ink")
        sprite.rect(22, 15, 6, 2, "ice")
        sprite.circle(16, 16, 3, "ink")
        sprite.circle(16, 16, 1, "orange")
    elif kind == "sniper":
        outline_polygon(sprite, [(3, 12), (21, 12), (29, 16), (21, 20), (3, 20)], [(7, 14), (21, 14), (25, 16), (21, 18), (7, 18)], "deep")
        sprite.rect(7, 9, 12, 3, "ink")
        sprite.rect(9, 10, 11, 1, "violet")
        sprite.rect(24, 14, 7, 4, "ink")
        sprite.rect(25, 15, 6, 2, "coral")
        sprite.rect(10, 15, 9, 2, "cyan")
        sprite.rect(4, 9, 3, 4, "pink")
        sprite.rect(4, 19, 3, 4, "pink")
    elif kind == "spiral":
        sprite.ring(16, 16, 12, 3, "ink")
        sprite.ring(16, 16, 8, 2, "violet")
        sprite.polygon([(25, 8), (29, 9), (26, 13), (23, 11)], "ink")
        sprite.polygon([(25, 9), (28, 10), (26, 12)], "coral")
        sprite.line(10, 13, 13, 10, "cyan")
        sprite.line(13, 10, 19, 10, "cyan")
        sprite.line(19, 10, 22, 14, "cyan")
        sprite.line(22, 14, 20, 19, "cyan")
        sprite.line(20, 19, 15, 21, "cyan")
        sprite.line(15, 21, 12, 18, "cyan")
        sprite.circle(16, 16, 2, "orange")
    elif kind == "warden":
        sprite.polygon([(16, 2), (25, 7), (29, 16), (25, 25), (16, 30), (7, 25), (3, 16), (7, 7)], "ink")
        sprite.polygon([(16, 6), (22, 10), (25, 16), (22, 22), (16, 26), (10, 22), (7, 16), (10, 10)], "purple")
        sprite.ring(16, 16, 8, 2, "violet")
        sprite.diamond(16, 16, 4, "ink")
        sprite.diamond(16, 16, 2, "coral")
        sprite.set(16, 16, "white")
        sprite.rect(14, 2, 4, 3, "cyan")
        sprite.rect(14, 27, 4, 3, "cyan")
    elif kind == "skirmisher":
        outline_polygon(sprite, [(2, 16), (10, 8), (27, 11), (30, 16), (27, 21), (10, 24)], [(7, 16), (11, 12), (24, 13), (26, 16), (24, 19), (11, 20)], "navy")
        sprite.polygon([(22, 12), (29, 16), (22, 20)], "coral")
        sprite.polygon([(8, 11), (14, 13), (10, 16), (5, 14)], "cyan")
        sprite.polygon([(8, 21), (14, 19), (10, 16), (5, 18)], "cyan")
        sprite.rect(12, 15, 10, 2, "ice")
        sprite.rect(5, 14, 3, 2, "orange")
        sprite.rect(5, 17, 3, 2, "orange")
    else:
        raise ValueError(f"Unknown enemy kind: {kind}")

    return sprite


def draw_weapon(kind: str) -> PixelSprite:
    sprite = PixelSprite()

    if kind == "pistol":
        outline_polygon(sprite, [(3, 11), (21, 11), (25, 14), (25, 17), (17, 17), (15, 24), (10, 24), (11, 17), (4, 17)], [(6, 13), (20, 13), (22, 15), (16, 15), (13, 21), (12, 21), (13, 15), (6, 15)], "navy")
        sprite.rect(8, 12, 12, 2, "cyan")
        sprite.rect(6, 16, 10, 2, "blue")
        sprite.rect(22, 14, 6, 3, "ink")
        sprite.rect(24, 15, 6, 1, "orange")
        sprite.set(10, 13, "white")
    elif kind == "smg":
        outline_polygon(sprite, [(2, 11), (21, 11), (26, 14), (30, 14), (30, 17), (21, 17), (18, 20), (18, 25), (13, 25), (13, 18), (7, 18), (7, 16), (2, 16)], [(5, 13), (20, 13), (23, 15), (27, 15), (20, 16), (15, 17), (9, 16), (9, 15), (5, 15)], "navy")
        sprite.rect(6, 12, 13, 2, "cyan")
        sprite.rect(21, 14, 8, 2, "violet")
        sprite.rect(14, 18, 3, 6, "coral")
        sprite.rect(3, 13, 4, 2, "orange")
    elif kind == "shotgun":
        outline_polygon(sprite, [(2, 10), (24, 10), (29, 13), (29, 18), (24, 21), (17, 19), (14, 25), (9, 25), (11, 18), (3, 18)], [(5, 12), (23, 12), (26, 14), (26, 17), (22, 18), (16, 16), (14, 18), (6, 16)], "deep")
        sprite.rect(5, 11, 20, 2, "cyan")
        sprite.rect(5, 14, 20, 2, "violet")
        sprite.rect(25, 12, 6, 3, "ink")
        sprite.rect(25, 16, 6, 3, "ink")
        sprite.rect(27, 13, 4, 1, "orange")
        sprite.rect(27, 17, 4, 1, "orange")
        sprite.rect(12, 18, 3, 6, "coral")
    elif kind == "rail":
        outline_polygon(sprite, [(2, 13), (27, 13), (30, 15), (30, 18), (22, 18), (20, 23), (15, 23), (16, 18), (2, 18)], [(5, 14), (25, 14), (27, 16), (20, 16), (18, 20), (17, 20), (18, 16), (5, 16)], "navy")
        sprite.rect(5, 12, 20, 2, "violet")
        sprite.rect(7, 14, 18, 2, "cyan")
        sprite.rect(25, 15, 7, 3, "ink")
        sprite.rect(27, 16, 5, 1, "ice")
        sprite.rect(12, 18, 4, 4, "coral")
    elif kind == "beam":
        outline_polygon(sprite, [(2, 12), (23, 12), (28, 14), (31, 16), (28, 18), (23, 20), (2, 20)], [(5, 14), (22, 14), (26, 16), (22, 18), (5, 18)], "deep")
        sprite.polygon([(7, 14), (23, 14), (27, 16), (23, 18), (7, 18)], "cyan")
        sprite.line(9, 15, 24, 16, "white")
        sprite.rect(4, 13, 4, 6, "violet")
        sprite.rect(27, 14, 5, 4, "ink")
        sprite.rect(29, 15, 3, 2, "ice")
    elif kind == "disc":
        sprite.circle(14, 16, 11, "ink")
        sprite.circle(14, 16, 8, "violet")
        sprite.polygon([(14, 7), (27, 12), (30, 16), (27, 20), (14, 25), (19, 16)], "ink")
        sprite.polygon([(17, 10), (25, 13), (27, 16), (25, 19), (17, 22), (20, 16)], "cyan")
        sprite.circle(14, 16, 3, "ink")
        sprite.circle(14, 16, 1, "orange")
        sprite.rect(25, 14, 6, 4, "coral")
    elif kind == "arc":
        outline_polygon(sprite, [(3, 12), (21, 12), (25, 9), (29, 10), (26, 15), (31, 16), (26, 18), (29, 23), (25, 23), (21, 20), (3, 20)], [(6, 14), (20, 14), (24, 12), (23, 16), (24, 20), (20, 18), (6, 18)], "navy")
        sprite.line(7, 16, 25, 16, "cyan")
        sprite.line(22, 13, 27, 11, "violet")
        sprite.line(22, 19, 27, 22, "violet")
        sprite.circle(7, 16, 3, "ink")
        sprite.circle(7, 16, 1, "orange")
    elif kind == "wave":
        outline_polygon(sprite, [(3, 12), (18, 12), (23, 8), (27, 9), (24, 14), (30, 16), (24, 18), (27, 23), (23, 24), (18, 20), (3, 20)], [(6, 14), (18, 14), (21, 11), (22, 16), (21, 21), (18, 18), (6, 18)], "deep")
        sprite.polygon([(19, 11), (24, 10), (22, 15), (28, 16), (22, 17), (24, 22), (19, 21), (21, 16)], "cyan")
        sprite.line(7, 15, 18, 15, "violet")
        sprite.line(7, 17, 18, 17, "purple")
        sprite.circle(7, 16, 2, "orange")
    elif kind == "glitch":
        sprite.rect(3, 10, 22, 13, "ink")
        sprite.rect(6, 13, 16, 7, "purple")
        sprite.rect(8, 12, 11, 2, "cyan")
        sprite.rect(9, 15, 5, 2, "pink")
        sprite.rect(16, 17, 6, 2, "orange")
        sprite.rect(24, 13, 6, 6, "ink")
        sprite.rect(25, 14, 5, 4, "coral")
        sprite.set(27, 15, "white")
        sprite.rect(11, 22, 4, 5, "coral")
        sprite.rect(14, 24, 2, 4, "orange")
    elif kind == "orbit":
        sprite.circle(14, 16, 9, "ink")
        sprite.circle(14, 16, 6, "navy")
        sprite.ring(14, 16, 11, 1, "violet")
        sprite.circle(14, 16, 3, "ink")
        sprite.circle(14, 16, 1, "mint")
        sprite.rect(25, 7, 5, 5, "ink")
        sprite.rect(26, 8, 3, 3, "cyan")
        sprite.rect(25, 20, 5, 5, "ink")
        sprite.rect(26, 21, 3, 3, "coral")
        sprite.rect(21, 14, 8, 4, "ink")
        sprite.rect(22, 15, 8, 2, "orange")
    elif kind == "blade":
        sprite.polygon([(5, 23), (11, 25), (29, 8), (27, 5), (23, 8), (8, 20)], "ink")
        sprite.polygon([(11, 21), (24, 8), (27, 8), (12, 23)], "ice")
        sprite.polygon([(9, 18), (15, 22), (12, 26), (6, 22)], "coral")
        sprite.rect(4, 20, 8, 3, "violet")
        sprite.rect(3, 19, 4, 2, "orange")
    elif kind == "chord":
        sprite.rect(3, 12, 16, 9, "ink")
        sprite.rect(6, 14, 11, 5, "navy")
        sprite.rect(17, 14, 5, 5, "violet")
        sprite.rect(21, 10, 3, 13, "ink")
        sprite.rect(22, 11, 1, 11, "cyan")
        for x, y, color in [(26, 10, "coral"), (29, 16, "orange"), (26, 22, "mint")]:
            sprite.circle(x, y, 3, "ink")
            sprite.circle(x, y, 1, color)
        sprite.line(23, 16, 27, 11, "cyan")
        sprite.line(23, 16, 28, 16, "cyan")
        sprite.line(23, 16, 27, 21, "cyan")
    else:
        raise ValueError(f"Unknown weapon kind: {kind}")

    return sprite


ENEMY_KINDS = ["drone", "fan", "charger", "turret", "splitter", "support", "sniper", "spiral", "warden", "skirmisher"]
WEAPON_KINDS = ["pistol", "smg", "shotgun", "rail", "beam", "disc", "arc", "wave", "glitch", "orbit", "blade", "chord"]


def make_contact_sheet(names: list[str], sprites: dict[str, PixelSprite]) -> PixelSprite:
    sheet = PixelSprite(len(names) * SIZE, SIZE)
    for index, name in enumerate(names):
        source = sprites[name]
        for y in range(SIZE):
            for x in range(SIZE):
                sheet.pixels[y][index * SIZE + x] = source.pixels[y][x]
    return sheet.scaled()


def main() -> None:
    enemies = {kind: draw_enemy(kind) for kind in ENEMY_KINDS}
    weapons = {kind: draw_weapon(kind) for kind in WEAPON_KINDS}

    for kind, sprite in enemies.items():
        write_png(ENEMY_OUT / f"enemy_{kind}_32.png", sprite)
    for kind, sprite in weapons.items():
        write_png(WEAPON_OUT / f"weapon_{kind}_32.png", sprite)

    write_png(ENEMY_OUT / "enemy_models_8x.png", make_contact_sheet(ENEMY_KINDS, enemies))
    write_png(WEAPON_OUT / "weapon_models_8x.png", make_contact_sheet(WEAPON_KINDS, weapons))

    manifest = {
        "format": "RGBA PNG",
        "dimensions": {"width": SIZE, "height": SIZE},
        "filter": "nearest",
        "palette": PALETTE,
        "enemies": [
            {"id": kind, "path": f"assets/sprites/pixel_32/enemies/enemy_{kind}_32.png"}
            for kind in ENEMY_KINDS
        ],
        "weapons": [
            {"id": kind, "path": f"assets/sprites/pixel_32/weapons/weapon_{kind}_32.png"}
            for kind in WEAPON_KINDS
        ],
        "contact_sheets": [
            "assets/sprites/pixel_32/enemies/enemy_models_8x.png",
            "assets/sprites/pixel_32/weapons/weapon_models_8x.png",
        ],
    }
    (OUT / "combat_asset_manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(f"Generated {len(enemies)} enemy sprites and {len(weapons)} weapon sprites in {OUT}")


if __name__ == "__main__":
    main()
