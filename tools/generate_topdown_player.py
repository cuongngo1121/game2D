"""Generate the top-down Echo Runner production sprite set.

The character faces right in source pixels.  ``EchoPlayer`` rotates both this
sprite and the separately drawn weapon around the same origin at runtime, so
the right glove remains on the weapon grip for every aiming direction.

This uses only the Python standard library.  It deliberately writes hard-edge
RGBA PNGs that can be opened and edited as 32 px frames in Pixelorama.
"""

from __future__ import annotations

import json
import os
import struct
import zlib
from typing import Sequence


ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "characters", "topdown_32")
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
    min_x = max(0, min(x for x, _ in points))
    max_x = min(len(canvas[0]) - 1, max(x for x, _ in points))
    min_y = max(0, min(y for _, y in points))
    max_y = min(len(canvas) - 1, max(y for _, y in points))
    for y in range(min_y, max_y + 1):
        for x in range(min_x, max_x + 1):
            inside = False
            previous = len(points) - 1
            for current, (x_i, y_i) in enumerate(points):
                x_j, y_j = points[previous]
                crosses = (y_i > y) != (y_j > y)
                if crosses and x < (x_j - x_i) * (y - y_i) / (y_j - y_i) + x_i:
                    inside = not inside
                previous = current
            if inside:
                canvas[y][x] = color


def ellipse(canvas: list[list[Color]], x0: int, y0: int, x1: int, y1: int, color: Color) -> None:
    center_x = (x0 + x1) / 2
    center_y = (y0 + y1) / 2
    radius_x = max(0.5, (x1 - x0) / 2)
    radius_y = max(0.5, (y1 - y0) / 2)
    for y in range(max(0, y0), min(len(canvas), y1 + 1)):
        for x in range(max(0, x0), min(len(canvas[0]), x1 + 1)):
            if ((x - center_x) / radius_x) ** 2 + ((y - center_y) / radius_y) ** 2 <= 1.0:
                canvas[y][x] = color


def draw_shadow(canvas: list[list[Color]], y: int = 23, width: int = 0) -> None:
    ellipse(canvas, 5 - width, y - 2, 22 + width, y + 2, (11, 17, 38, 130))
    rect(canvas, 8 - width, y, 19 + width, y + 1, (19, 30, 58, 120))


def draw_head(canvas: list[list[Color]], dx: int = 0, dy: int = 0, visor_phase: int = 0, hurt: bool = False) -> None:
    """Helmet is intentionally oversized and set behind the weapon hand."""
    edge = HURT if hurt else OUTLINE
    ellipse(canvas, 3 + dx, 7 + dy, 15 + dx, 20 + dy, edge)
    ellipse(canvas, 4 + dx, 8 + dy, 14 + dx, 19 + dy, NAVY)
    polygon(canvas, [(5 + dx, 10 + dy), (8 + dx, 8 + dy), (12 + dx, 9 + dy),
                     (14 + dx, 12 + dy), (13 + dx, 15 + dy), (7 + dx, 15 + dy),
                     (4 + dx, 13 + dy)], SLATE)
    rect(canvas, 6 + dx, 9 + dy, 10 + dx, 10 + dy, SLATE_HI)
    put(canvas, 8 + dx, 8 + dy, CYAN_DARK)
    # The visor is an arc toward the front/right: readable from a strict top view.
    edge_color = HURT if hurt else CYAN_DARK
    polygon(canvas, [(9 + dx, 11 + dy), (14 + dx, 11 + dy), (15 + dx, 13 + dy),
                     (13 + dx, 16 + dy), (8 + dx, 16 + dy), (7 + dx, 14 + dy)], edge_color)
    polygon(canvas, [(10 + dx, 12 + dy), (13 + dx, 12 + dy), (14 + dx, 13 + dy),
                     (12 + dx, 14 + dy), (9 + dx, 14 + dy), (8 + dx, 13 + dy)], HURT if hurt else CYAN)
    rect(canvas, 10 + dx, 12 + dy, 12 + dx, 12 + dy, CYAN_HI if visor_phase != 1 else CYAN)
    put(canvas, 13 + dx, 13 + dy, WHITE if visor_phase == 2 else CYAN_HI)
    put(canvas, 5 + dx, 13 + dy, HURT if hurt else AMBER)
    rect(canvas, 7 + dx, 17 + dy, 12 + dx, 18 + dy, INK)


def draw_torso(canvas: list[list[Color]], dx: int = 0, dy: int = 0, hurt: bool = False) -> None:
    edge = HURT if hurt else OUTLINE
    polygon(canvas, [(10 + dx, 10 + dy), (17 + dx, 9 + dy), (22 + dx, 12 + dy),
                     (23 + dx, 19 + dy), (18 + dx, 24 + dy), (10 + dx, 23 + dy),
                     (7 + dx, 18 + dy)], edge)
    polygon(canvas, [(11 + dx, 11 + dy), (17 + dx, 10 + dy), (20 + dx, 13 + dy),
                     (20 + dx, 19 + dy), (17 + dx, 22 + dy), (11 + dx, 21 + dy),
                     (9 + dx, 17 + dy)], NAVY)
    polygon(canvas, [(11 + dx, 11 + dy), (14 + dx, 10 + dy), (15 + dx, 21 + dy),
                     (11 + dx, 20 + dy), (9 + dx, 17 + dy)], PURPLE_DARK)
    rect(canvas, 12 + dx, 13 + dy, 16 + dx, 19 + dy, INK)
    rect(canvas, 13 + dx, 14 + dy, 15 + dx, 18 + dy, SLATE)
    put(canvas, 14 + dx, 14 + dy, SLATE_HI)
    rect(canvas, 11 + dx, 20 + dy, 18 + dx, 22 + dy, INK)
    put(canvas, 17 + dx, 13 + dy, PINK)
    put(canvas, 18 + dx, 14 + dy, CYAN)
    put(canvas, 13 + dx, 21 + dy, CYAN_DARK)


def draw_support_arm(canvas: list[list[Color]], dx: int = 0, dy: int = 0, lift: int = 0, hurt: bool = False) -> None:
    """Rear/lower arm makes the character read as head + hands, not legs."""
    edge = HURT if hurt else OUTLINE
    polygon(canvas, [(10 + dx, 18 + dy), (14 + dx, 20 + dy), (17 + dx, 24 + dy - lift),
                     (15 + dx, 27 + dy - lift), (11 + dx, 26 + dy - lift),
                     (8 + dx, 22 + dy)], edge)
    polygon(canvas, [(11 + dx, 19 + dy), (13 + dx, 21 + dy), (15 + dx, 24 + dy - lift),
                     (14 + dx, 25 + dy - lift), (12 + dx, 24 + dy - lift),
                     (10 + dx, 21 + dy)], PURPLE_DARK)
    rect(canvas, 13 + dx, 22 + dy - lift, 15 + dx, 24 + dy - lift, NAVY)
    put(canvas, 13 + dx, 22 + dy - lift, PURPLE)
    put(canvas, 15 + dx, 24 + dy - lift, HURT if hurt else AMBER)
    put(canvas, 16 + dx, 25 + dy - lift, HURT if hurt else AMBER)


def draw_weapon_arm(canvas: list[list[Color]], dx: int = 0, dy: int = 0, recoil: int = 0, hurt: bool = False) -> None:
    """Forward arm ends at frame (21, 15), the game weapon's grip point."""
    edge = HURT if hurt else OUTLINE
    polygon(canvas, [(16 + dx - recoil, 10 + dy), (21 + dx - recoil, 11 + dy),
                     (24 + dx - recoil, 14 + dy), (23 + dx - recoil, 18 + dy),
                     (19 + dx - recoil, 18 + dy), (17 + dx - recoil, 15 + dy)], edge)
    polygon(canvas, [(18 + dx - recoil, 11 + dy), (20 + dx - recoil, 12 + dy),
                     (22 + dx - recoil, 14 + dy), (21 + dx - recoil, 16 + dy),
                     (19 + dx - recoil, 15 + dy)], SLATE)
    rect(canvas, 20 + dx - recoil, 13 + dy, 22 + dx - recoil, 15 + dy, NAVY)
    put(canvas, 21 + dx - recoil, 13 + dy, CYAN)
    # This amber glove is deliberately aligned to the existing weapon's rear grip.
    rect(canvas, 21 + dx - recoil, 15 + dy, 23 + dx - recoil, 16 + dy, HURT if hurt else AMBER)
    put(canvas, 23 + dx - recoil, 15 + dy, CYAN_HI)


def draw_hero(canvas: list[list[Color]], animation: str, frame: int) -> None:
    if animation == "idle":
        bob = (0, -1, 0, 1)[frame % 4]
        draw_shadow(canvas, 25 + max(0, bob))
        draw_torso(canvas, dy=bob)
        draw_support_arm(canvas, dy=bob, lift=frame % 2)
        draw_weapon_arm(canvas, dy=bob)
        draw_head(canvas, dy=bob, visor_phase=frame % 3)
        return

    if animation == "run":
        bob = (0, -1, 0, -1, 0, -1)[frame % 6]
        swing = (-1, 0, 1, 1, 0, -1)[frame % 6]
        draw_shadow(canvas, 25, abs(swing))
        draw_torso(canvas, dx=swing, dy=bob)
        draw_support_arm(canvas, dx=swing, dy=bob, lift=1 if frame % 2 else 0)
        draw_weapon_arm(canvas, dx=swing, dy=bob, recoil=-swing)
        draw_head(canvas, dx=swing, dy=bob, visor_phase=frame % 3)
        return

    if animation == "attack":
        recoil = (0, 1, 2, 1)[frame % 4]
        bob = (0, 0, -1, 0)[frame % 4]
        draw_shadow(canvas, 25)
        draw_torso(canvas, dx=-recoil, dy=bob)
        draw_support_arm(canvas, dx=-recoil, dy=bob, lift=1)
        draw_weapon_arm(canvas, dx=0, dy=bob, recoil=recoil)
        draw_head(canvas, dx=-recoil, dy=bob, visor_phase=2)
        if frame == 2:
            put(canvas, 30, 15, CYAN_HI)
            put(canvas, 31, 15, AMBER)
        return

    if animation == "dash":
        stretch = (0, 1, 2, 3)[frame % 4]
        for trail in range(3):
            alpha = 145 - trail * 35
            rect(canvas, 2 - trail * 2, 12 + trail, 9 + stretch - trail, 18 + trail, (7, 87, 129, alpha))
            put(canvas, 3 - trail * 2, 15 + trail, (38, 214, 231, alpha))
        draw_shadow(canvas, 25, 1)
        draw_torso(canvas, dx=stretch, dy=-1)
        draw_support_arm(canvas, dx=stretch, dy=-1, lift=2)
        draw_weapon_arm(canvas, dx=stretch, dy=-1)
        draw_head(canvas, dx=stretch, dy=-1, visor_phase=2)
        return

    if animation == "hurt":
        shake = (0, -1, 0)[frame % 3]
        draw_shadow(canvas, 25)
        draw_torso(canvas, dx=shake, hurt=True)
        draw_support_arm(canvas, dx=shake, lift=-1, hurt=True)
        draw_weapon_arm(canvas, dx=shake, recoil=1, hurt=True)
        draw_head(canvas, dx=shake, visor_phase=1, hurt=True)
        if frame == 1:
            put(canvas, 4, 8, WHITE)
            put(canvas, 27, 20, WHITE)
        return

    if animation == "death":
        if frame < 3:
            fall = frame
            draw_shadow(canvas, 25 + fall, fall)
            draw_torso(canvas, dx=-fall, dy=fall)
            draw_support_arm(canvas, dx=-fall, dy=fall, lift=-fall)
            draw_weapon_arm(canvas, dx=-fall, dy=fall, recoil=fall)
            draw_head(canvas, dx=-fall, dy=fall, visor_phase=frame % 2)
            return
        draw_shadow(canvas, 27)
        if frame == 3:
            polygon(canvas, [(5, 18), (11, 15), (21, 16), (25, 20), (20, 24), (9, 24)], OUTLINE)
            polygon(canvas, [(8, 18), (18, 17), (22, 20), (18, 22), (10, 22)], NAVY)
            rect(canvas, 10, 19, 16, 20, PURPLE_DARK)
            rect(canvas, 17, 17, 21, 18, CYAN_DARK)
            put(canvas, 7, 20, AMBER)
            return
        if frame == 4:
            polygon(canvas, [(7, 21), (12, 18), (22, 20), (23, 23), (17, 25), (9, 24)], OUTLINE)
            rect(canvas, 11, 21, 18, 22, NAVY)
            rect(canvas, 14, 20, 18, 20, CYAN_DARK)
            put(canvas, 9, 23, PURPLE)
            put(canvas, 22, 22, AMBER)
            return
        put(canvas, 8, 25, PURPLE)
        put(canvas, 13, 21, CYAN)
        put(canvas, 18, 24, CYAN_HI)
        put(canvas, 23, 21, AMBER)
        put(canvas, 27, 25, PINK)
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
        frame_name = f"echo_runner_topdown_{name}_{frame_index}.png"
        write_png(os.path.join(OUT, frame_name), frame)
        frame_files.append(frame_name)
        paste(strip, frame, frame_index * W)
    strip_name = f"echo_runner_topdown_{name}_{count}x32.png"
    write_png(os.path.join(OUT, strip_name), strip)
    return {"frames": count, "fps": fps, "loop": loop, "strip": strip_name, "files": frame_files}


def save_preview(animation_counts: dict[str, int]) -> str:
    scale = 8
    cell = W * scale
    gap = 16
    preview = image(max(animation_counts.values()) * (cell + gap) + gap, len(animation_counts) * (cell + gap) + gap)
    fill(preview, (10, 16, 37, 255))
    for row, (name, count) in enumerate(animation_counts.items()):
        for frame_index in range(count):
            frame = image()
            draw_hero(frame, name, frame_index)
            x = gap + frame_index * (cell + gap)
            y = gap + row * (cell + gap)
            rect(preview, x - 4, y - 4, x + cell + 3, y + cell + 3, (19, 30, 58, 255))
            paste_scaled(preview, frame, x, y, scale)
    filename = "echo_runner_topdown_preview_8x.png"
    write_png(os.path.join(OUT, filename), preview)
    return filename


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    model = image()
    draw_hero(model, "idle", 0)
    write_png(os.path.join(OUT, "echo_runner_topdown_model_32.png"), model)

    animation_config = {
        "idle": (4, 6, True),
        "run": (6, 10, True),
        "attack": (4, 12, False),
        "dash": (4, 16, False),
        "hurt": (3, 10, False),
        "death": (6, 8, False),
    }
    animations = {
        name: save_animation(name, count, fps, loop)
        for name, (count, fps, loop) in animation_config.items()
    }
    preview_name = save_preview({name: spec[0] for name, spec in animation_config.items()})
    manifest = {
        "character": "Echo Runner — top-down aiming rig",
        "source": "Original hard-edge pixel art based on the approved top-down concept.",
        "frame_size": {"width": 32, "height": 32},
        "canvas": "RGBA PNG, transparent background",
        "source_facing": "right (+X)",
        "rotation_contract": {
            "pivot": {"x": 15, "y": 16},
            "weapon_grip": {"x": 22, "y": 15},
            "description": "Rotate player sprite and weapon together by aim_direction.angle() around the player origin.",
        },
        "recommended_import": {"filter": "Nearest", "mipmaps": False, "scale": "4x or 6x"},
        "preview": preview_name,
        "palette": {
            "outline": "#070B1C", "navy": "#111B39", "slate": "#253458",
            "cyan": "#26D6E7", "cyan_highlight": "#B7FFFF", "purple": "#AA23EC",
            "pink": "#FF41D7", "amber": "#FFAF2A",
        },
        "animations": animations,
    }
    with open(os.path.join(OUT, "animation_manifest.json"), "w", encoding="utf-8") as handle:
        json.dump(manifest, handle, ensure_ascii=False, indent=2)
        handle.write("\n")


if __name__ == "__main__":
    main()
