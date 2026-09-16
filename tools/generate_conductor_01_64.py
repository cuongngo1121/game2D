"""Generate the editable 64x64 CONDUCTOR-01 boss sprite and animation set.

The high-resolution concept is kept separately as visual direction.  This
generator deliberately produces native 64px RGBA pixel frames with integer
primitives, so the runtime never has to blur or downsample a concept render and
every frame remains easy to revise in Pixelorama.
"""

from __future__ import annotations

import json
from pathlib import Path

from generate_pixel_combat_assets import PALETTE, PixelSprite, write_png


ROOT = Path(__file__).resolve().parents[1]
SIZE = 64
OUT = ROOT / "assets" / "sprites" / "pixel_64" / "bosses" / "conductor_01"
ANIMATION_OUT = OUT / "animations"

ANIMATIONS = {
    "idle": {"frames": 4, "fps": 6.0, "loop": True},
    "move": {"frames": 6, "fps": 10.0, "loop": True},
    "attack": {"frames": 4, "fps": 12.0, "loop": False},
    "hurt": {"frames": 3, "fps": 10.0, "loop": False},
    "death": {"frames": 6, "fps": 8.0, "loop": False},
}


def blank() -> tuple[int, int, int, int]:
    return PALETTE["transparent"]


def copy_sprite(source: PixelSprite, dx: int = 0, dy: int = 0) -> PixelSprite:
    result = PixelSprite(SIZE, SIZE)
    for y in range(SIZE):
        for x in range(SIZE):
            target_x = x + dx
            target_y = y + dy
            if 0 <= target_x < SIZE and 0 <= target_y < SIZE:
                result.pixels[target_y][target_x] = source.pixels[y][x]
    return result


def outline_polygon(
    sprite: PixelSprite,
    outer: list[tuple[int, int]],
    inner: list[tuple[int, int]],
    fill: str,
) -> None:
    sprite.polygon(outer, "ink")
    sprite.polygon(inner, fill)


def draw_conductor() -> PixelSprite:
    """Build the v2 CONDUCTOR-01: a compact sonic maestro with horn pods."""
    sprite = PixelSprite(SIZE, SIZE)

    # Crowned baton aerial: the unmistakable visual signature of the conductor.
    sprite.circle(32, 5, 5, "ink")
    sprite.diamond(32, 5, 3, "purple")
    sprite.diamond(32, 5, 1, "white")
    sprite.rect(29, 10, 7, 13, "ink")
    sprite.rect(31, 10, 3, 12, "navy")
    sprite.rect(32, 11, 1, 11, "violet")
    sprite.polygon([(27, 16), (30, 13), (31, 19), (33, 19), (34, 13), (38, 16), (37, 22), (27, 22)], "ink")
    sprite.rect(29, 17, 7, 3, "purple")
    sprite.rect(31, 17, 3, 2, "pink")

    # Central circular resonance engine. Keep this large and readable at 64px.
    outline_polygon(
        sprite,
        [(32, 18), (43, 21), (50, 30), (50, 43), (43, 53), (32, 59), (21, 53), (14, 43), (14, 30), (21, 21)],
        [(32, 21), (40, 24), (46, 31), (46, 41), (40, 49), (32, 54), (24, 49), (18, 41), (18, 31), (24, 24)],
        "deep",
    )
    sprite.ring(32, 37, 15, 3, "ink")
    sprite.ring(32, 37, 12, 2, "navy")
    sprite.ring(32, 37, 10, 1, "cyan")
    sprite.circle(32, 37, 8, "purple")
    sprite.circle(32, 37, 6, "violet")
    sprite.rect(22, 36, 20, 3, "pink")
    sprite.rect(24, 37, 16, 1, "white")
    sprite.diamond(32, 37, 3, "white")
    sprite.rect(24, 25, 16, 2, "blue")
    sprite.rect(27, 25, 10, 1, "cyan")
    sprite.rect(27, 51, 10, 3, "ink")
    sprite.rect(29, 52, 6, 1, "cyan")
    for x in (20, 42):
        sprite.rect(x, 29, 2, 15, "purple")
        sprite.rect(x + 1, 31, 1, 9, "cyan")

    # The large left pod is a circular speaker. The right pod is an angular horn:
    # the asymmetry makes this redesign recognisable without sacrificing balance.
    outline_polygon(
        sprite,
        [(1, 20), (7, 14), (18, 15), (24, 23), (24, 40), (17, 48), (7, 47), (1, 41)],
        [(4, 22), (9, 18), (16, 19), (20, 25), (20, 38), (15, 44), (9, 43), (4, 39)],
        "navy",
    )
    sprite.ring(11, 31, 11, 2, "ink")
    sprite.ring(11, 31, 8, 2, "cyan")
    sprite.circle(11, 31, 5, "deep")
    sprite.circle(11, 31, 2, "blue")
    sprite.set(10, 30, "ice")
    sprite.rect(4, 20, 9, 2, "violet")
    sprite.rect(17, 23, 2, 11, "cyan")

    outline_polygon(
        sprite,
        [(63, 18), (54, 14), (45, 17), (41, 24), (42, 41), (49, 48), (59, 47), (63, 42)],
        [(59, 19), (53, 18), (48, 20), (45, 26), (46, 38), (51, 44), (57, 43), (59, 39)],
        "navy",
    )
    sprite.polygon([(58, 22), (49, 25), (47, 32), (57, 39)], "deep")
    sprite.polygon([(57, 25), (51, 27), (50, 32), (56, 36)], "purple")
    sprite.ring(55, 31, 5, 2, "ink")
    sprite.ring(55, 31, 3, 1, "pink")
    sprite.rect(46, 22, 8, 2, "cyan")
    sprite.rect(59, 25, 2, 12, "violet")

    # Two small control arms and two lower tuning-fork emitters preserve the
    # reference's four-arm read while keeping the game silhouette compact.
    for x, y in ((19, 43), (45, 43)):
        sprite.circle(x, y, 3, "ink")
        sprite.circle(x, y, 1, "cyan")
    sprite.line(19, 44, 9, 50, "ink")
    sprite.line(20, 44, 10, 50, "blue")
    sprite.line(45, 44, 55, 50, "ink")
    sprite.line(44, 44, 54, 50, "blue")
    for x, sign in ((7, 1), (57, -1)):
        sprite.line(x, 48, x + sign * 4, 56, "ink")
        sprite.line(x + sign, 49, x + sign * 4, 55, "cyan")
        sprite.line(x + sign * 4, 54, x + sign * 7, 54, "ink")
        sprite.line(x + sign * 4, 58, x + sign * 7, 58, "ink")
        sprite.set(x + sign * 6, 54, "violet")
        sprite.set(x + sign * 6, 58, "violet")

    # Lower stabiliser and cyan beat vents complete the floating chassis.
    sprite.polygon([(28, 54), (36, 54), (39, 60), (32, 63), (25, 60)], "ink")
    sprite.polygon([(30, 56), (34, 56), (36, 59), (32, 61), (28, 59)], "blue")
    sprite.diamond(32, 59, 2, "cyan")
    sprite.rect(28, 57, 2, 1, "violet")
    sprite.rect(34, 57, 2, 1, "violet")
    return sprite


def add_idle_pulse(sprite: PixelSprite, frame: int) -> None:
    pulse_positions = [(30, 34), (32, 33), (34, 34), (32, 36)]
    x, y = pulse_positions[frame]
    sprite.set(x, y, "white")
    if frame in (1, 3):
        sprite.set(32, 18, "ice")
    if frame == 2:
        sprite.set(14, 35, "ice")
        sprite.set(50, 35, "ice")


def add_move_trails(sprite: PixelSprite, frame: int) -> None:
    for offset, color in enumerate(("blue", "cyan", "violet")):
        x = 20 + offset * 5
        sprite.rect(x, 60 + (frame % 2), 3, 2, color)
        sprite.rect(41 - offset * 5, 60 + ((frame + 1) % 2), 3, 2, color)


def add_attack_charge(sprite: PixelSprite, frame: int) -> None:
    if frame == 0:
        sprite.ring(32, 34, 13, 1, "violet")
        return
    if frame == 1:
        sprite.ring(32, 34, 15, 2, "pink")
        sprite.circle(32, 34, 5, "white")
        return
    if frame == 2:
        sprite.rect(30, 18, 4, 17, "ice")
        sprite.rect(29, 19, 6, 16, "cyan")
        sprite.rect(31, 19, 2, 16, "white")
        for x in range(3, 62, 8):
            sprite.set(x, 34 + ((x // 8) % 2), "violet")
        return
    sprite.ring(32, 34, 12, 1, "cyan")
    sprite.set(32, 34, "white")


def add_hurt_flash(sprite: PixelSprite, frame: int) -> None:
    """Give every Hurt frame an immediate, distinct readable impact."""
    if frame == 0:
        # The first frame is the one rendered immediately after a shot. A sharp
        # core inversion and cyan sparks make the hit legible before the full flash.
        sprite.ring(32, 37, 13, 1, "ice")
        sprite.rect(29, 35, 7, 5, "ice")
        sprite.rect(31, 34, 3, 7, "white")
        for x, y in ((7, 17), (16, 49), (48, 20), (58, 45), (32, 10)):
            sprite.circle(x, y, 1, "cyan")
        return
    if frame == 1:
        # Peak impact: the metal conductor briefly turns white/coral.
        for y in range(SIZE):
            for x in range(SIZE):
                pixel = sprite.pixels[y][x]
                if pixel not in (blank(), PALETTE["ink"], PALETTE["deep"]):
                    sprite.pixels[y][x] = PALETTE["white"] if (x + y) % 2 else PALETTE["coral"]
        for x, y in ((9, 20), (54, 22), (23, 55), (42, 57), (32, 12)):
            sprite.circle(x, y, 2, "white")
        return
    # Recovery frame: a violet core sputter and displaced sparks communicate the
    # recoil rather than returning to the standing pose.
    sprite.ring(32, 37, 14, 1, "violet")
    sprite.circle(32, 37, 5, "purple")
    sprite.rect(31, 34, 3, 7, "white")
    for x, y in ((5, 29), (14, 15), (23, 57), (44, 54), (55, 18), (61, 36)):
        sprite.circle(x, y, 1, "pink")


def make_frame(action: str, frame: int) -> PixelSprite:
    source = draw_conductor()
    if action == "idle":
        result = copy_sprite(source, dy=(0, -1, 0, 1)[frame])
        add_idle_pulse(result, frame)
        return result
    if action == "move":
        result = copy_sprite(source, dx=(0, 1, 1, 0, -1, -1)[frame], dy=(0, 1, 0, -1, 0, 1)[frame])
        add_move_trails(result, frame)
        return result
    if action == "attack":
        result = copy_sprite(source, dy=(1, 0, -1, 0)[frame])
        add_attack_charge(result, frame)
        return result
    if action == "hurt":
        # Recoil, peak flash, recovery: no frame is a copy of the idle model.
        result = copy_sprite(source, dx=(-1, 0, 1)[frame], dy=(0, -1, 1)[frame])
        add_hurt_flash(result, frame)
        return result
    if action == "death":
        result = PixelSprite(SIZE, SIZE)
        cutoff = 62 - frame * 9
        for y in range(SIZE):
            for x in range(SIZE):
                pixel = source.pixels[y][x]
                if pixel == blank() or y > cutoff:
                    continue
                if frame >= 2 and (x * 5 + y * 3 + frame) % (6 - min(frame, 4)) == 0:
                    continue
                target_y = y + min(3, frame // 2)
                if target_y < SIZE:
                    result.pixels[target_y][x] = pixel
        for x, y, color in ((8 + frame * 2, 20, "cyan"), (55 - frame * 2, 25, "violet"), (25, 56 - frame * 2, "pink"), (39, 52 - frame, "white")):
            sprite_x = min(SIZE - 2, max(1, x))
            sprite_y = min(SIZE - 2, max(1, y))
            result.circle(sprite_x, sprite_y, 1 + (frame % 2), color)
        return result
    raise ValueError(f"Unknown action: {action}")


def make_sheet(frames: list[PixelSprite]) -> PixelSprite:
    sheet = PixelSprite(len(frames) * SIZE, SIZE)
    for index, frame in enumerate(frames):
        for y in range(SIZE):
            for x in range(SIZE):
                sheet.pixels[y][index * SIZE + x] = frame.pixels[y][x]
    return sheet


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    ANIMATION_OUT.mkdir(parents=True, exist_ok=True)
    canonical = draw_conductor()
    write_png(OUT / "conductor_01_model_64.png", canonical)
    entries: list[dict[str, object]] = []
    preview_frames: list[PixelSprite] = []
    for action, config in ANIMATIONS.items():
        frame_count = int(config["frames"])
        frames = [make_frame(action, frame) for frame in range(frame_count)]
        stem = f"conductor_01_{action}_{frame_count}x64"
        sheet_path = ANIMATION_OUT / f"{stem}.png"
        write_png(sheet_path, make_sheet(frames))
        frame_paths: list[str] = []
        for index, frame in enumerate(frames):
            frame_path = ANIMATION_OUT / f"{stem}_{index}.png"
            write_png(frame_path, frame)
            frame_paths.append(str(frame_path.relative_to(ROOT)).replace("\\", "/"))
        entries.append({
            "id": "conductor_01",
            "animation": action,
            "frames": frame_count,
            "fps": float(config["fps"]),
            "loop": bool(config["loop"]),
            "sheet": str(sheet_path.relative_to(ROOT)).replace("\\", "/"),
            "frame_paths": frame_paths,
        })
        preview_frames.append(frames[min(1, len(frames) - 1)])
    write_png(OUT / "conductor_01_preview_5x.png", make_sheet(preview_frames).scaled(4))
    manifest = {
        "format": "RGBA PNG",
        "frame_dimensions": {"width": SIZE, "height": SIZE},
        "filter": "nearest",
        "source_concept": "assets/concepts/bosses/conductor_01_reference_generated_v2.png",
        "runtime_kind": "boss0",
        "animations": entries,
    }
    (OUT / "animation_manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(f"Generated CONDUCTOR-01 64px model and {len(entries)} animation sheets in {OUT}")


if __name__ == "__main__":
    main()
