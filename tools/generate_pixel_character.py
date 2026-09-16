"""Generate the 32x32 Echo Runner pixel-art test set.

The output is intentionally made from integer pixel primitives rather than a
scaled vector image. That keeps every frame easy to edit in Pixelorama and
keeps the feet/weapon anchor stable across animations.
"""

from __future__ import annotations

import json
import os
import struct
import zlib
from typing import Iterable, Sequence


ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "characters", "pixel_32")
W = H = 32

Color = tuple[int, int, int, int]
Point = tuple[int, int]

TRANSPARENT: Color = (0, 0, 0, 0)
OUTLINE: Color = (7, 11, 28, 255)
INK: Color = (10, 16, 37, 255)
NAVY: Color = (17, 27, 57, 255)
SLATE: Color = (37, 52, 88, 255)
SLATE_HI: Color = (60, 78, 120, 255)
CYAN_DARK: Color = (7, 87, 129, 255)
CYAN: Color = (38, 214, 231, 255)
CYAN_HI: Color = (183, 255, 255, 255)
PURPLE_DARK: Color = (65, 19, 105, 255)
PURPLE: Color = (170, 35, 236, 255)
PINK: Color = (255, 65, 215, 255)
AMBER: Color = (255, 175, 42, 255)
SKIN: Color = (255, 192, 104, 255)
HURT: Color = (255, 73, 91, 255)
WHITE: Color = (255, 245, 224, 255)


def image(width: int = W, height: int = H) -> list[list[Color]]:
    return [[TRANSPARENT for _ in range(width)] for _ in range(height)]


def put(canvas: list[list[Color]], x: int, y: int, color: Color) -> None:
    if 0 <= y < len(canvas) and 0 <= x < len(canvas[0]):
        canvas[y][x] = color


def rect(canvas: list[list[Color]], x0: int, y0: int, x1: int, y1: int, color: Color) -> None:
    for y in range(max(0, y0), min(len(canvas), y1 + 1)):
        for x in range(max(0, x0), min(len(canvas[0]), x1 + 1)):
            canvas[y][x] = color


def polygon(canvas: list[list[Color]], points: Sequence[Point], color: Color) -> None:
    """Fill a polygon with a point-in-polygon test; all edges stay pixel hard."""
    min_x = max(0, min(x for x, _ in points))
    max_x = min(len(canvas[0]) - 1, max(x for x, _ in points))
    min_y = max(0, min(y for _, y in points))
    max_y = min(len(canvas) - 1, max(y for _, y in points))
    for y in range(min_y, max_y + 1):
        for x in range(min_x, max_x + 1):
            inside = False
            j = len(points) - 1
            for i, (xi, yi) in enumerate(points):
                xj, yj = points[j]
                crosses = (yi > y) != (yj > y)
                if crosses and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
                    inside = not inside
                j = i
            if inside:
                canvas[y][x] = color


def line(canvas: list[list[Color]], start: Point, end: Point, color: Color) -> None:
    x0, y0 = start
    x1, y1 = end
    dx = abs(x1 - x0)
    sx = 1 if x0 < x1 else -1
    dy = -abs(y1 - y0)
    sy = 1 if y0 < y1 else -1
    error = dx + dy
    while True:
        put(canvas, x0, y0, color)
        if x0 == x1 and y0 == y1:
            return
        doubled = 2 * error
        if doubled >= dy:
            error += dy
            x0 += sx
        if doubled <= dx:
            error += dx
            y0 += sy


def ellipse(canvas: list[list[Color]], x0: int, y0: int, x1: int, y1: int, color: Color) -> None:
    cx = (x0 + x1) / 2
    cy = (y0 + y1) / 2
    rx = max(0.5, (x1 - x0) / 2)
    ry = max(0.5, (y1 - y0) / 2)
    for y in range(max(0, y0), min(len(canvas), y1 + 1)):
        for x in range(max(0, x0), min(len(canvas[0]), x1 + 1)):
            if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                canvas[y][x] = color


def draw_shadow(canvas: list[list[Color]], y: int = 28) -> None:
    ellipse(canvas, 8, y - 1, 23, y + 2, (11, 17, 38, 175))
    rect(canvas, 11, y, 20, y + 1, (19, 30, 58, 150))


def draw_boot(canvas: list[list[Color]], cx: int, y: int, shift: int = 0, hurt: bool = False) -> None:
    ink = HURT if hurt else OUTLINE
    polygon(canvas, [(cx - 3 + shift, y), (cx + 2 + shift, y), (cx + 3 + shift, y + 5),
                     (cx + 2 + shift, y + 7), (cx - 4 + shift, y + 7),
                     (cx - 5 + shift, y + 5)], ink)
    polygon(canvas, [(cx - 2 + shift, y + 1), (cx + 1 + shift, y + 1),
                     (cx + 2 + shift, y + 5), (cx - 3 + shift, y + 6),
                     (cx - 4 + shift, y + 4)], NAVY)
    rect(canvas, cx - 2 + shift, y + 2, cx + 1 + shift, y + 3, CYAN_DARK)
    put(canvas, cx + shift, y + 2, CYAN_HI)
    rect(canvas, cx - 3 + shift, y + 5, cx + 2 + shift, y + 6, SLATE)
    put(canvas, cx + 2 + shift, y + 6, CYAN)


def draw_leg(canvas: list[list[Color]], cx: int, y: int, shift: int = 0, bent: int = 0, hurt: bool = False) -> None:
    ink = HURT if hurt else OUTLINE
    polygon(canvas, [(cx - 3, y), (cx + 2, y), (cx + 2 + bent, y + 4),
                     (cx + 1 + shift, y + 6), (cx - 3 + shift, y + 6),
                     (cx - 4 + bent, y + 3)], ink)
    polygon(canvas, [(cx - 2, y), (cx + 1, y + 1), (cx + 1 + bent, y + 4),
                     (cx - 2 + shift, y + 5), (cx - 3 + bent, y + 2)], NAVY)
    rect(canvas, cx - 1, y + 1, cx + 1, y + 2, SLATE)
    draw_boot(canvas, cx + shift, y + 4, 0, hurt)


def draw_gun(canvas: list[list[Color]], y: int, length: int = 0, muzzle: bool = False) -> None:
    end = 27 + length
    rect(canvas, 19, y - 1, end, y + 3, OUTLINE)
    rect(canvas, 21, y, end - 2, y + 1, CYAN_DARK)
    rect(canvas, 23, y, end - 3, y, CYAN)
    rect(canvas, end - 2, y, end, y + 2, SLATE_HI)
    rect(canvas, 20, y + 2, 22, y + 5, OUTLINE)
    rect(canvas, 21, y + 2, 22, y + 4, NAVY)
    put(canvas, 25, y, CYAN_HI)
    if muzzle:
        put(canvas, end + 1, y + 1, AMBER)
        rect(canvas, end + 2, y, end + 3, y + 2, CYAN_HI)
        put(canvas, end + 4, y + 1, AMBER)


def draw_head(canvas: list[list[Color]], oy: int, visor_phase: int = 0, hurt: bool = False) -> None:
    helmet = HURT if hurt else OUTLINE
    polygon(canvas, [(10, 5 + oy), (19, 4 + oy), (23, 7 + oy), (24, 11 + oy),
                     (21, 15 + oy), (12, 16 + oy), (8, 13 + oy), (8, 9 + oy)], helmet)
    polygon(canvas, [(11, 5 + oy), (19, 6 + oy), (22, 8 + oy), (21, 12 + oy),
                     (18, 14 + oy), (11, 13 + oy), (9, 11 + oy), (9, 8 + oy)], NAVY)
    polygon(canvas, [(11, 6 + oy), (18, 6 + oy), (21, 8 + oy), (19, 9 + oy),
                     (11, 9 + oy), (9, 8 + oy)], SLATE)
    rect(canvas, 10, 7 + oy, 12, 8 + oy, SLATE_HI)
    put(canvas, 11, 6 + oy, CYAN)
    put(canvas, 12, 5 + oy, CYAN_DARK)
    line(canvas, (21, 7 + oy), (22, 10 + oy), CYAN_DARK)
    visor = HURT if hurt else CYAN
    polygon(canvas, [(11, 9 + oy), (20, 9 + oy), (21, 11 + oy), (18, 13 + oy),
                     (12, 12 + oy), (10, 11 + oy)], visor)
    rect(canvas, 12, 10 + oy, 18, 11 + oy, CYAN_HI if visor_phase != 1 else CYAN)
    rect(canvas, 13, 12 + oy, 16, 12 + oy, CYAN_DARK)
    put(canvas, 19, 10 + oy, WHITE if visor_phase == 2 else CYAN_HI)
    put(canvas, 10, 10 + oy, AMBER if not hurt else HURT)
    rect(canvas, 11, 13 + oy, 19, 14 + oy, INK)


def draw_torso(canvas: list[list[Color]], oy: int, arm_lift: int = 0, hurt: bool = False) -> None:
    jacket = HURT if hurt else OUTLINE
    polygon(canvas, [(11, 13 + oy), (19, 13 + oy), (23, 17 + oy), (21, 23 + oy),
                     (11, 23 + oy), (8, 19 + oy), (9, 16 + oy)], jacket)
    polygon(canvas, [(12, 14 + oy), (18, 14 + oy), (20, 17 + oy), (19, 21 + oy),
                     (12, 21 + oy), (10, 18 + oy)], PURPLE_DARK)
    rect(canvas, 13, 15 + oy, 17, 20 + oy, INK)
    rect(canvas, 14, 16 + oy, 16, 19 + oy, SLATE)
    put(canvas, 15, 16 + oy, SLATE_HI)
    polygon(canvas, [(10, 14 + oy), (13, 15 + oy), (12, 19 + oy), (9, 18 + oy)], PURPLE)
    polygon(canvas, [(18, 14 + oy), (21, 16 + oy), (20, 20 + oy), (18, 19 + oy)], PINK)
    put(canvas, 11, 16 + oy, CYAN)
    put(canvas, 20, 17 + oy, CYAN)
    rect(canvas, 12, 21 + oy, 19, 23 + oy, NAVY)

    # Left arm: a readable bent gauntlet, with a single warm hand pixel.
    left_y = 16 + oy - arm_lift
    polygon(canvas, [(9, 15 + oy), (12, 17 + oy), (10, left_y + 4), (7, left_y + 4),
                     (6, left_y + 2), (7, 16 + oy)], OUTLINE)
    rect(canvas, 7, left_y + 1, 9, left_y + 3, PURPLE_DARK)
    put(canvas, 7, left_y + 2, PURPLE)
    put(canvas, 8, left_y + 1, CYAN)
    put(canvas, 6, left_y + 3, SKIN if not hurt else HURT)

    # Right arm leads into the pistol.
    polygon(canvas, [(19, 15 + oy), (22, 16 + oy), (22, 20 + oy), (19, 20 + oy),
                     (18, 18 + oy)], OUTLINE)
    rect(canvas, 20, 16 + oy, 22, 18 + oy, NAVY)
    put(canvas, 21, 16 + oy, CYAN)
    put(canvas, 21, 19 + oy, SKIN if not hurt else HURT)


def draw_hero(canvas: list[list[Color]], animation: str, frame: int) -> None:
    if animation == "idle":
        bob = (0, -1, 0, 1)[frame % 4]
        draw_shadow(canvas, 28 + max(0, bob))
        draw_leg(canvas, 12, 21 + bob, shift=0)
        draw_leg(canvas, 18, 21 + bob, shift=0)
        draw_torso(canvas, bob)
        draw_head(canvas, bob, frame % 3)
        draw_gun(canvas, 16 + bob)
        return

    if animation == "run":
        bob = (0, -1, 0, -1, 0, -1)[frame % 6]
        gait = ((-2, 2, 1, -1), (-1, 3, 1, 2), (0, 1, 0, 1),
                (2, -2, -1, 1), (1, -3, -1, -2), (0, -1, 0, -1))[frame % 6]
        left_shift, right_shift, left_bend, right_bend = gait
        draw_shadow(canvas, 28 + abs(left_shift) // 2)
        draw_leg(canvas, 12, 21 + bob, shift=left_shift, bent=left_bend)
        draw_leg(canvas, 18, 21 + bob, shift=right_shift, bent=right_bend)
        draw_torso(canvas, bob, arm_lift=1 if frame % 2 else 0)
        draw_head(canvas, bob, frame % 3)
        draw_gun(canvas, 16 + bob)
        return

    if animation == "attack":
        bob = (0, 0, -1, 0)[frame % 4]
        draw_shadow(canvas, 28)
        draw_leg(canvas, 12, 21 + bob)
        draw_leg(canvas, 18, 21 + bob)
        draw_torso(canvas, bob, arm_lift=1)
        draw_head(canvas, bob, frame % 3)
        draw_gun(canvas, 16 + bob, length=(0, 1, 3, 1)[frame % 4], muzzle=frame % 4 == 2)
        if frame % 4 == 2:
            put(canvas, 30, 13, AMBER)
            put(canvas, 31, 16, CYAN_HI)
        return

    if animation == "dash":
        lean = (0, 1, 2, 2)[frame % 4]
        trail_color = (10, 181, 219, 190)
        for index in range(3 - min(2, frame // 2)):
            dx = -4 - index * 2 - lean
            dy = 2 + index
            rect(canvas, 10 + dx, 14 + dy, 18 + dx, 20 + dy, trail_color)
            put(canvas, 12 + dx, 12 + dy, (84, 245, 255, 180))
        draw_shadow(canvas, 28)
        draw_leg(canvas, 12, 20, shift=lean, bent=1)
        draw_leg(canvas, 18, 20, shift=lean + 1, bent=-1)
        draw_torso(canvas, -1, arm_lift=2)
        draw_head(canvas, -1, frame % 2)
        draw_gun(canvas, 15, length=2)
        rect(canvas, 26, 14, 30, 15, CYAN_HI)
        put(canvas, 30, 14 + (frame % 2), WHITE)
        return

    if animation == "hurt":
        bob = (0, -1, 0)[frame % 3]
        draw_shadow(canvas, 28)
        draw_leg(canvas, 12, 21 + bob, shift=-1, hurt=True)
        draw_leg(canvas, 18, 21 + bob, shift=1, hurt=True)
        draw_torso(canvas, bob, arm_lift=-1, hurt=True)
        draw_head(canvas, bob, frame % 2, hurt=True)
        draw_gun(canvas, 16 + bob, length=-1)
        rect(canvas, 7, 10 + bob, 8, 12 + bob, HURT)
        put(canvas, 24, 11 + bob, HURT)
        if frame == 1:
            put(canvas, 5, 14, WHITE)
            put(canvas, 26, 8, WHITE)
        return

    if animation == "death":
        if frame < 3:
            bob = frame
            draw_shadow(canvas, 28 + frame)
            draw_leg(canvas, 12, 21 + bob, shift=-frame)
            draw_leg(canvas, 18, 21 + bob, shift=frame)
            draw_torso(canvas, bob, arm_lift=-frame)
            draw_head(canvas, bob, frame % 2)
            draw_gun(canvas, 16 + bob, length=-frame)
            if frame == 2:
                rect(canvas, 7, 8, 8, 10, HURT)
            return
        if frame == 3:
            draw_shadow(canvas, 29)
            polygon(canvas, [(9, 22), (12, 19), (22, 20), (24, 23), (20, 26),
                             (11, 26)], OUTLINE)
            polygon(canvas, [(12, 21), (20, 21), (22, 23), (19, 24), (12, 24)], PURPLE_DARK)
            rect(canvas, 13, 22, 19, 23, SLATE)
            polygon(canvas, [(7, 19), (10, 18), (12, 21), (10, 23), (7, 22)], NAVY)
            rect(canvas, 22, 21, 27, 23, OUTLINE)
            rect(canvas, 23, 21, 26, 21, CYAN)
            return
        if frame == 4:
            draw_shadow(canvas, 29)
            polygon(canvas, [(9, 24), (12, 22), (21, 22), (24, 24), (21, 27),
                             (12, 27)], OUTLINE)
            rect(canvas, 12, 24, 20, 25, PURPLE_DARK)
            rect(canvas, 14, 23, 18, 23, CYAN_DARK)
            rect(canvas, 21, 24, 26, 25, SLATE)
            return
        # Final sparks leave a readable endpoint without adding opaque clutter.
        put(canvas, 12, 25, CYAN)
        put(canvas, 16, 22, PURPLE)
        put(canvas, 20, 26, CYAN_HI)
        put(canvas, 23, 23, AMBER)
        put(canvas, 8, 26, PINK)
        return

    raise ValueError(f"Unknown animation: {animation}")


def png_chunk(kind: bytes, data: bytes) -> bytes:
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)


def write_png(path: str, canvas: list[list[Color]]) -> None:
    raw = b"".join(b"\x00" + b"".join(bytes(pixel) for pixel in row) for row in canvas)
    payload = b"\x89PNG\r\n\x1a\n"
    payload += png_chunk(b"IHDR", struct.pack(">IIBBBBB", len(canvas[0]), len(canvas), 8, 6, 0, 0, 0))
    payload += png_chunk(b"IDAT", zlib.compress(raw, 9))
    payload += png_chunk(b"IEND", b"")
    with open(path, "wb") as handle:
        handle.write(payload)


def blank_strip(frame_count: int) -> list[list[Color]]:
    return image(W * frame_count, H)


def paste(strip: list[list[Color]], frame: list[list[Color]], offset_x: int) -> None:
    for y in range(H):
        for x in range(W):
            strip[y][offset_x + x] = frame[y][x]


def fill(canvas: list[list[Color]], color: Color) -> None:
    for y in range(len(canvas)):
        for x in range(len(canvas[0])):
            canvas[y][x] = color


def paste_scaled(canvas: list[list[Color]], frame: list[list[Color]], offset_x: int, offset_y: int, scale: int) -> None:
    for y in range(H):
        for x in range(W):
            color = frame[y][x]
            if color[3] == 0:
                continue
            for scaled_y in range(scale):
                for scaled_x in range(scale):
                    canvas[offset_y + y * scale + scaled_y][offset_x + x * scale + scaled_x] = color


def save_animation(name: str, count: int, fps: int, loop: bool) -> dict[str, object]:
    strip = blank_strip(count)
    frame_files: list[str] = []
    for frame_index in range(count):
        frame = image()
        draw_hero(frame, name, frame_index)
        frame_name = f"echo_runner_{name}_{frame_index}.png"
        write_png(os.path.join(OUT, frame_name), frame)
        frame_files.append(frame_name)
        paste(strip, frame, frame_index * W)
    strip_name = f"echo_runner_{name}_{count}x32.png"
    write_png(os.path.join(OUT, strip_name), strip)
    return {
        "frames": count,
        "fps": fps,
        "loop": loop,
        "strip": strip_name,
        "files": frame_files,
    }


def save_preview(animation_counts: dict[str, int]) -> str:
    scale = 8
    cell = W * scale
    gap = 16
    row_height = cell + gap
    max_count = max(animation_counts.values())
    preview = image(max_count * (cell + gap) + gap, len(animation_counts) * row_height + gap)
    fill(preview, (10, 16, 37, 255))
    for row, (name, count) in enumerate(animation_counts.items()):
        for frame_index in range(count):
            frame = image()
            draw_hero(frame, name, frame_index)
            x = gap + frame_index * (cell + gap)
            y = gap + row * row_height
            rect(preview, x - 4, y - 4, x + cell + 3, y + cell + 3, (19, 30, 58, 255))
            paste_scaled(preview, frame, x, y, scale)
    filename = "echo_runner_preview_8x.png"
    write_png(os.path.join(OUT, filename), preview)
    return filename


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    model = image()
    draw_hero(model, "idle", 0)
    write_png(os.path.join(OUT, "echo_runner_model_32.png"), model)

    animations = {
        "idle": save_animation("idle", 4, 6, True),
        "run": save_animation("run", 6, 10, True),
        "attack": save_animation("attack", 4, 12, False),
        "dash": save_animation("dash", 4, 16, False),
        "hurt": save_animation("hurt", 3, 10, False),
        "death": save_animation("death", 6, 8, False),
    }
    preview_name = save_preview({"idle": 4, "run": 6, "attack": 4, "dash": 4, "hurt": 3, "death": 6})
    manifest = {
        "character": "Echo Runner",
        "source": "Original pixel-art test asset; concept palette and silhouette guided by an AI-generated design study.",
        "frame_size": {"width": 32, "height": 32},
        "canvas": "RGBA PNG, transparent background",
        "anchor": {"x": 15, "y": 28, "description": "feet/ground anchor; keep this point fixed in Godot"},
        "recommended_import": {
            "filter": "Nearest",
            "mipmaps": False,
            "scale": "4x or 6x for a readable test preview",
        },
        "preview": preview_name,
        "palette": {
            "outline": "#070B1C",
            "navy": "#111B39",
            "slate": "#253458",
            "cyan": "#26D6E7",
            "cyan_highlight": "#B7FFFF",
            "purple": "#AA23EC",
            "pink": "#FF41D7",
            "amber": "#FFAF2A",
        },
        "animations": animations,
    }
    with open(os.path.join(OUT, "animation_manifest.json"), "w", encoding="utf-8") as handle:
        json.dump(manifest, handle, ensure_ascii=False, indent=2)
        handle.write("\n")


if __name__ == "__main__":
    main()
