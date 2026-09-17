"""Generate editable 32 px overhead ECHO RUNNER animation sheets.

The source model faces right.  EchoPlayer rotates this entire sheet and the
separate weapon with the same aim angle, so the amber right-hand grip stays on
the weapon when aiming in any direction.  The art is intentionally built from
integer pixel primitives: every frame stays editable in Pixelorama.
"""

from __future__ import annotations

import json
import os
import struct
import zlib
from typing import Sequence


ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "characters", "overhead_32")
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


def draw_shadow(canvas: list[list[Color]], y: int = 25, width: int = 0) -> None:
    ellipse(canvas, 5 - width, y - 2, 23 + width, y + 2, (11, 17, 38, 135))
    rect(canvas, 8 - width, y, 20 + width, y + 1, (19, 30, 58, 120))


def draw_core(canvas: list[list[Color]], dx: int = 0, dy: int = 0, hurt: bool = False) -> None:
    edge = HURT if hurt else OUTLINE
    polygon(canvas, [(10 + dx, 16 + dy), (19 + dx, 16 + dy), (21 + dx, 21 + dy),
                     (18 + dx, 26 + dy), (11 + dx, 26 + dy), (8 + dx, 21 + dy)], edge)
    polygon(canvas, [(11 + dx, 17 + dy), (18 + dx, 17 + dy), (19 + dx, 21 + dy),
                     (17 + dx, 24 + dy), (12 + dx, 24 + dy), (10 + dx, 21 + dy)], NAVY)
    rect(canvas, 12 + dx, 19 + dy, 17 + dx, 22 + dy, SLATE)
    rect(canvas, 13 + dx, 20 + dy, 16 + dx, 21 + dy, PURPLE_DARK)
    put(canvas, 14 + dx, 20 + dy, PURPLE)
    put(canvas, 17 + dx, 18 + dy, CYAN_DARK)


def draw_head(canvas: list[list[Color]], dx: int = 0, dy: int = 0, lamp_phase: int = 0, hurt: bool = False) -> None:
    """A crown/top surface, never a frontal face or visor."""
    edge = HURT if hurt else OUTLINE
    ellipse(canvas, 7 + dx, 6 + dy, 19 + dx, 19 + dy, edge)
    ellipse(canvas, 8 + dx, 7 + dy, 18 + dx, 18 + dy, NAVY)
    polygon(canvas, [(10 + dx, 8 + dy), (16 + dx, 8 + dy), (18 + dx, 11 + dy),
                     (16 + dx, 14 + dy), (10 + dx, 14 + dy), (8 + dx, 11 + dy)], SLATE)
    rect(canvas, 11 + dx, 8 + dy, 15 + dx, 9 + dy, SLATE_HI)
    polygon(canvas, [(12 + dx, 10 + dy), (15 + dx, 10 + dy), (16 + dx, 12 + dy),
                     (14 + dx, 13 + dy), (12 + dx, 12 + dy)], CYAN_DARK)
    put(canvas, 14 + dx, 11 + dy, HURT if hurt else CYAN)
    if lamp_phase == 2:
        put(canvas, 14 + dx, 10 + dy, CYAN_HI)
    # Small cyan markers on the rim read as top-mounted lights, not eyes.
    put(canvas, 8 + dx, 13 + dy, HURT if hurt else CYAN_DARK)
    put(canvas, 18 + dx, 13 + dy, HURT if hurt else CYAN_DARK)


def draw_arm(canvas: list[list[Color]], side: int, dx: int = 0, dy: int = 0,
             swing: int = 0, recoil: int = 0, hurt: bool = False) -> None:
    """Both arms are visible from above; the right glove meets the gun grip."""
    edge = HURT if hurt else OUTLINE
    if side < 0:
        polygon(canvas, [(9 + dx, 13 + dy), (6 + dx, 13 + dy + swing),
                         (3 + dx, 16 + dy + swing), (4 + dx, 21 + dy + swing),
                         (8 + dx, 22 + dy), (11 + dx, 18 + dy)], edge)
        polygon(canvas, [(8 + dx, 14 + dy), (6 + dx, 15 + dy + swing),
                         (5 + dx, 18 + dy + swing), (6 + dx, 20 + dy + swing),
                         (8 + dx, 20 + dy), (9 + dx, 17 + dy)], SLATE)
        rect(canvas, 4 + dx, 17 + dy + swing, 6 + dx, 19 + dy + swing, NAVY)
        put(canvas, 5 + dx, 16 + dy + swing, CYAN)
        put(canvas, 4 + dx, 20 + dy + swing, AMBER if not hurt else HURT)
        return

    # The source weapon is drawn from local x=5; this glove at frame x=22 is
    # therefore its rear grip after EchoPlayer translates the 32 px source.
    hand_x = 22 + dx - recoil
    polygon(canvas, [(17 + dx, 13 + dy), (21 + dx - recoil, 13 + dy + swing),
                     (25 + dx - recoil, 15 + dy + swing), (25 + dx - recoil, 19 + dy + swing),
                     (21 + dx - recoil, 21 + dy), (17 + dx, 18 + dy)], edge)
    polygon(canvas, [(18 + dx, 14 + dy), (21 + dx - recoil, 15 + dy + swing),
                     (23 + dx - recoil, 16 + dy + swing), (23 + dx - recoil, 18 + dy + swing),
                     (21 + dx - recoil, 19 + dy), (19 + dx, 17 + dy)], SLATE)
    rect(canvas, hand_x - 1, 16 + dy + swing, hand_x + 1, 18 + dy + swing, NAVY)
    put(canvas, hand_x, 15 + dy + swing, CYAN)
    rect(canvas, hand_x, 17 + dy + swing, hand_x + 1, 18 + dy + swing, HURT if hurt else AMBER)
    put(canvas, hand_x + 2, 17 + dy + swing, CYAN_HI)


def draw_overhead(canvas: list[list[Color]], animation: str, frame: int) -> None:
    if animation == "idle":
        bob = (0, -1, 0, 1)[frame % 4]
        draw_shadow(canvas, 26 + max(bob, 0))
        draw_core(canvas, dy=bob)
        draw_arm(canvas, -1, dy=bob, swing=0 if frame % 2 else 1)
        draw_arm(canvas, 1, dy=bob, swing=0 if frame % 2 else -1)
        draw_head(canvas, dy=bob, lamp_phase=frame % 3)
        return

    if animation == "run":
        bob = (0, -1, 0, -1, 0, -1)[frame % 6]
        sway = (-1, 0, 1, 1, 0, -1)[frame % 6]
        draw_shadow(canvas, 26, abs(sway))
        draw_core(canvas, dx=sway, dy=bob)
        draw_arm(canvas, -1, dx=sway, dy=bob, swing=-sway)
        draw_arm(canvas, 1, dx=sway, dy=bob, swing=sway)
        draw_head(canvas, dx=sway, dy=bob, lamp_phase=frame % 3)
        return

    if animation == "attack":
        recoil = (0, 1, 2, 2, 1, 0)[frame % 6]
        draw_shadow(canvas, 26)
        draw_core(canvas, dx=-recoil)
        draw_arm(canvas, -1, dx=-recoil, swing=1)
        draw_arm(canvas, 1, recoil=recoil)
        draw_head(canvas, dx=-recoil, lamp_phase=2)
        if frame == 2:
            put(canvas, 30, 16, CYAN_HI)
            put(canvas, 31, 16, AMBER)
        return

    if animation == "run_attack":
        bob = (0, -1, 0, -1, 0, -1)[frame % 6]
        sway = (-1, 0, 1, 1, 0, -1)[frame % 6]
        recoil = (0, 1, 2, 1, 0, 1)[frame % 6]
        draw_shadow(canvas, 26, abs(sway))
        draw_core(canvas, dx=sway - recoil, dy=bob)
        draw_arm(canvas, -1, dx=sway - recoil, dy=bob, swing=-sway)
        draw_arm(canvas, 1, dx=sway, dy=bob, swing=sway, recoil=recoil)
        draw_head(canvas, dx=sway - recoil, dy=bob, lamp_phase=2 if frame in [2, 5] else frame % 2)
        if frame in [2, 5]:
            put(canvas, 30, 16 + bob, CYAN_HI)
        return

    if animation == "dash":
        forward = (0, 1, 2, 3)[frame % 4]
        for trail in range(3):
            alpha = 150 - trail * 35
            rect(canvas, 2 - trail * 2, 12 + trail, 10 + forward - trail, 19 + trail, (7, 87, 129, alpha))
            put(canvas, 3 - trail * 2, 15 + trail, (38, 214, 231, alpha))
        draw_shadow(canvas, 26, 1)
        draw_core(canvas, dx=forward, dy=-1)
        draw_arm(canvas, -1, dx=forward, dy=-1, swing=-1)
        draw_arm(canvas, 1, dx=forward, dy=-1, swing=1)
        draw_head(canvas, dx=forward, dy=-1, lamp_phase=2)
        return

    if animation == "hurt":
        shake = (0, -1, 0)[frame % 3]
        draw_shadow(canvas, 26)
        draw_core(canvas, dx=shake, hurt=True)
        draw_arm(canvas, -1, dx=shake, swing=1, hurt=True)
        draw_arm(canvas, 1, dx=shake, recoil=1, hurt=True)
        draw_head(canvas, dx=shake, lamp_phase=1, hurt=True)
        if frame == 1:
            put(canvas, 3, 10, WHITE)
            put(canvas, 28, 22, WHITE)
        return

    if animation == "pulse":
        # Pulse is a deliberate six-frame one-shot: the core charges, both
        # arms open to release the wave, then the light collapses back into the
        # runner. The larger world-space ring is drawn by EchoPlayer so this
        # sheet remains a readable 32px character asset in Pixelorama.
        charge = (0, 1, 2, 3, 2, 1)[frame % 6]
        draw_shadow(canvas, 26, 1 if charge >= 2 else 0)
        draw_core(canvas, dx=0, dy=-1 if charge >= 3 else 0)
        draw_arm(canvas, -1, swing=-1 - charge // 2)
        draw_arm(canvas, 1, swing=1 + charge // 2, recoil=1 if charge >= 2 else 0)
        draw_head(canvas, lamp_phase=2)
        # Frame-local pixel sparks make the authored sheet visibly animate even
        # when the procedural world-space wave is hidden by another layer.
        spark_color = CYAN_HI if frame in (2, 3) else CYAN
        if charge >= 1:
            put(canvas, 6 - charge, 16, spark_color)
            put(canvas, 25 + charge, 16, spark_color)
        if charge >= 2:
            put(canvas, 9, 8 - charge // 2, PURPLE)
            put(canvas, 21, 24 + charge // 2, PURPLE)
        if charge >= 3:
            rect(canvas, 12, 14, 17, 15, CYAN_HI)
            put(canvas, 10, 16, PINK)
            put(canvas, 19, 16, PINK)
        return

    if animation == "death":
        if frame < 3:
            fall = frame
            draw_shadow(canvas, 26 + fall, fall)
            draw_core(canvas, dx=-fall, dy=fall)
            draw_arm(canvas, -1, dx=-fall, dy=fall, swing=fall)
            draw_arm(canvas, 1, dx=-fall, dy=fall, recoil=fall)
            draw_head(canvas, dx=-fall, dy=fall, lamp_phase=frame % 2)
            return
        draw_shadow(canvas, 28)
        if frame == 3:
            polygon(canvas, [(6, 20), (11, 16), (21, 17), (25, 21), (20, 25), (9, 24)], OUTLINE)
            polygon(canvas, [(9, 19), (18, 18), (22, 21), (18, 23), (10, 22)], NAVY)
            rect(canvas, 11, 20, 17, 21, PURPLE_DARK)
            put(canvas, 20, 20, CYAN_DARK)
            return
        if frame == 4:
            polygon(canvas, [(8, 22), (13, 19), (22, 21), (22, 24), (16, 25), (9, 24)], OUTLINE)
            rect(canvas, 12, 22, 18, 23, NAVY)
            put(canvas, 10, 23, PURPLE)
            put(canvas, 21, 22, AMBER)
            return
        put(canvas, 8, 26, PURPLE)
        put(canvas, 13, 22, CYAN)
        put(canvas, 18, 25, CYAN_HI)
        put(canvas, 23, 22, AMBER)
        put(canvas, 27, 26, PINK)
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
        draw_overhead(frame, name, frame_index)
        frame_name = f"echo_runner_overhead_{name}_{frame_index}.png"
        write_png(os.path.join(OUT, frame_name), frame)
        frame_files.append(frame_name)
        paste(strip, frame, frame_index * W)
    strip_name = f"echo_runner_overhead_{name}_{count}x32.png"
    write_png(os.path.join(OUT, strip_name), strip)
    return {"frames": count, "fps": fps, "loop": loop, "strip": strip_name, "files": frame_files}


def save_preview(animation_specs: dict[str, tuple[int, int, bool]]) -> str:
    scale = 8
    cell = W * scale
    gap = 16
    preview = image(max(spec[0] for spec in animation_specs.values()) * (cell + gap) + gap,
                    len(animation_specs) * (cell + gap) + gap)
    fill(preview, (10, 16, 37, 255))
    for row, (name, (count, _, _)) in enumerate(animation_specs.items()):
        for frame_index in range(count):
            frame = image()
            draw_overhead(frame, name, frame_index)
            x = gap + frame_index * (cell + gap)
            y = gap + row * (cell + gap)
            rect(preview, x - 4, y - 4, x + cell + 3, y + cell + 3, (19, 30, 58, 255))
            paste_scaled(preview, frame, x, y, scale)
    filename = "echo_runner_overhead_preview_8x.png"
    write_png(os.path.join(OUT, filename), preview)
    return filename


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    animation_specs = {
        "idle": (4, 6, True),
        "run": (6, 10, True),
        "attack": (6, 12, False),
        "run_attack": (6, 12, True),
        "dash": (4, 16, False),
        "hurt": (3, 10, False),
        "pulse": (6, 12, False),
        "death": (6, 8, False),
    }
    model = image()
    draw_overhead(model, "idle", 0)
    write_png(os.path.join(OUT, "echo_runner_overhead_model_32.png"), model)
    animations = {
        name: save_animation(name, count, fps, loop)
        for name, (count, fps, loop) in animation_specs.items()
    }
    preview_name = save_preview(animation_specs)
    manifest = {
        "character": "Echo Runner — overhead aiming rig",
        "source": "Original hard-edge pixel art based on the approved literal bird's-eye concept.",
        "frame_size": {"width": 32, "height": 32},
        "canvas": "RGBA PNG, transparent background",
        "source_facing": "right (+X)",
        "rotation_contract": {
            "pivot": {"x": 15, "y": 16},
            "weapon_grip": {"x": 22, "y": 17},
            "description": "Rotate player sprite and weapon together by aim_direction.angle() around the player origin.",
        },
        "recommended_import": {"filter": "Nearest", "mipmaps": False, "scale": "4x or 6x"},
        "preview": preview_name,
        "animations": animations,
    }
    with open(os.path.join(OUT, "animation_manifest.json"), "w", encoding="utf-8") as handle:
        json.dump(manifest, handle, ensure_ascii=False, indent=2)
        handle.write("\n")


if __name__ == "__main__":
    main()
