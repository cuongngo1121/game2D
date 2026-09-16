"""Generate editable 32x32 enemy and weapon animation sheets.

The static combat roster is the source pose. Animation frames are derived with
integer pixel offsets, palette swaps, and small effect accents so the output is
deterministic and remains convenient to edit in Pixelorama.
"""

from __future__ import annotations

import json
from pathlib import Path

from generate_pixel_combat_assets import (
    ENEMY_KINDS,
    PALETTE,
    PixelSprite,
    SIZE,
    WEAPON_KINDS,
    draw_enemy,
    draw_weapon,
    write_png,
)


ROOT = Path(__file__).resolve().parents[1]
ENEMY_ANIM_OUT = ROOT / "assets" / "sprites" / "pixel_32" / "enemies" / "animations"
WEAPON_ANIM_OUT = ROOT / "assets" / "sprites" / "pixel_32" / "weapons" / "animations"

ENEMY_ANIMATIONS = {
    "idle": {"frames": 4, "fps": 6.0, "loop": True},
    "move": {"frames": 6, "fps": 10.0, "loop": True},
    "attack": {"frames": 4, "fps": 12.0, "loop": False},
    "hurt": {"frames": 3, "fps": 10.0, "loop": False},
    "death": {"frames": 6, "fps": 8.0, "loop": False},
}
WEAPON_ANIMATIONS = {
    "recoil": {"frames": 3, "fps": 18.0, "loop": False},
}


def blank() -> tuple[int, int, int, int]:
    return PALETTE["transparent"]


def blit(source: PixelSprite, dx: int = 0, dy: int = 0) -> PixelSprite:
    result = PixelSprite()
    for y in range(SIZE):
        for x in range(SIZE):
            target_x = x + dx
            target_y = y + dy
            if 0 <= target_x < SIZE and 0 <= target_y < SIZE:
                result.pixels[target_y][target_x] = source.pixels[y][x]
    return result


def set_pixel(sprite: PixelSprite, x: int, y: int, color: str) -> None:
    sprite.set(x, y, color)


def add_motion_trail(sprite: PixelSprite, frame: int) -> None:
    colors = ["blue", "cyan", "violet"]
    if frame in (1, 4):
        for x in range(1, 5):
            set_pixel(sprite, x, 14, colors[(x + frame) % len(colors)])
            set_pixel(sprite, x, 17, colors[(x + frame + 1) % len(colors)])
    elif frame in (2, 5):
        for x in range(2, 6):
            set_pixel(sprite, x, 15, colors[(x + frame) % len(colors)])


def add_attack_flash(sprite: PixelSprite, kind: str, frame: int) -> None:
    if frame == 0:
        set_pixel(sprite, 28, 16, "orange")
        return
    if frame == 1:
        for x in range(26, 32):
            set_pixel(sprite, x, 15, "coral")
            set_pixel(sprite, x, 16, "orange")
            set_pixel(sprite, x, 17, "coral")
        return
    if frame == 2:
        for x in range(24, 32):
            set_pixel(sprite, x, 14, "violet")
            set_pixel(sprite, x, 16, "ice")
            set_pixel(sprite, x, 18, "violet")
        return
    # Follow-through: a small core spark remains after the attack.
    set_pixel(sprite, 27, 13 if kind in ("sniper", "turret") else 16, "ice")
    set_pixel(sprite, 29, 16, "orange")


def make_enemy_frame(kind: str, action: str, frame: int) -> PixelSprite:
    source = draw_enemy(kind)
    if action == "idle":
        return blit(source, dy=[0, -1, 0, 1][frame])
    if action == "move":
        result = blit(source, dy=[0, 1, 0, -1, 0, 1][frame])
        add_motion_trail(result, frame)
        return result
    if action == "attack":
        result = blit(source, dy=[1, 0, -1, 0][frame])
        add_attack_flash(result, kind, frame)
        if frame == 1:
            set_pixel(result, 15, 3, "ice")
            set_pixel(result, 16, 2, "white")
        return result
    if action == "hurt":
        result = blit(source, dy=[0, 1, 0][frame])
        if frame == 1:
            for y in range(SIZE):
                for x in range(SIZE):
                    pixel = result.pixels[y][x]
                    if pixel != blank() and pixel != PALETTE["ink"] and pixel != PALETTE["deep"]:
                        result.pixels[y][x] = PALETTE["white"] if (x + y) % 2 else PALETTE["coral"]
            set_pixel(result, 4, 7, "white")
            set_pixel(result, 27, 24, "white")
        return result
    if action == "death":
        result = PixelSprite()
        cutoff = 31 - frame * 4
        for y in range(SIZE):
            for x in range(SIZE):
                pixel = source.pixels[y][x]
                if pixel == blank():
                    continue
                keep = y <= cutoff
                if frame >= 3:
                    keep = keep and ((x * 3 + y + frame) % 5 != 0)
                if keep:
                    target_y = y + min(2, frame // 2)
                    if target_y < SIZE:
                        result.pixels[target_y][x] = pixel
        for x, y, color in [
            (4 + frame, 5 + (frame % 3), "coral"),
            (26 - frame, 8 + (frame % 2), "orange"),
            (7 + (frame % 2), 25 - frame, "violet"),
            (24, 24 - (frame % 3), "cyan"),
        ]:
            set_pixel(result, x, y, color)
        return result
    raise ValueError(f"Unknown enemy animation: {action}")


def make_weapon_frame(kind: str, action: str, frame: int) -> PixelSprite:
    if action != "recoil":
        raise ValueError(f"Unknown weapon animation: {action}")
    source = draw_weapon(kind)
    result = blit(source, dx=[0, -2, -1][frame])
    if frame == 1:
        for x in range(27, 32):
            set_pixel(result, x, 14, "coral")
            set_pixel(result, x, 15, "orange")
            set_pixel(result, x, 16, "white")
            set_pixel(result, x, 17, "orange")
        set_pixel(result, 30, 13, "coral")
        set_pixel(result, 30, 18, "coral")
    elif frame == 2:
        set_pixel(result, 29, 15, "orange")
        set_pixel(result, 30, 16, "coral")
    return result


def make_sheet(frames: list[PixelSprite]) -> PixelSprite:
    sheet = PixelSprite(len(frames) * SIZE, SIZE)
    for index, frame in enumerate(frames):
        for y in range(SIZE):
            for x in range(SIZE):
                sheet.pixels[y][index * SIZE + x] = frame.pixels[y][x]
    return sheet


def write_animation_set(
    names: list[str],
    configs: dict[str, dict[str, object]],
    output_dir: Path,
    frame_factory,
    prefix: str,
) -> list[dict[str, object]]:
    entries: list[dict[str, object]] = []
    for name in names:
        for action, config in configs.items():
            frame_count = int(config["frames"])
            frames = [frame_factory(name, action, frame) for frame in range(frame_count)]
            stem = f"{prefix}_{name}_{action}_{frame_count}x32"
            write_png(output_dir / f"{stem}.png", make_sheet(frames))
            frame_paths: list[str] = []
            for frame_index, frame in enumerate(frames):
                frame_path = output_dir / f"{stem}_{frame_index}.png"
                write_png(frame_path, frame)
                frame_paths.append(str(frame_path.relative_to(ROOT)).replace("\\", "/"))
            entries.append({
                "id": name,
                "animation": action,
                "frames": frame_count,
                "fps": float(config["fps"]),
                "loop": bool(config["loop"]),
                "sheet": str((output_dir / f"{stem}.png").relative_to(ROOT)).replace("\\", "/"),
                "frame_paths": frame_paths,
            })
    return entries


def main() -> None:
    enemy_entries = write_animation_set(
        ENEMY_KINDS, ENEMY_ANIMATIONS, ENEMY_ANIM_OUT, make_enemy_frame, "enemy"
    )
    weapon_entries = write_animation_set(
        WEAPON_KINDS, WEAPON_ANIMATIONS, WEAPON_ANIM_OUT, make_weapon_frame, "weapon"
    )
    manifest = {
        "format": "RGBA PNG",
        "frame_dimensions": {"width": SIZE, "height": SIZE},
        "filter": "nearest",
        "enemies": enemy_entries,
        "weapons": weapon_entries,
    }
    manifest_path = ROOT / "assets" / "sprites" / "pixel_32" / "combat_animation_manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(
        f"Generated {len(enemy_entries)} enemy animation sheets and "
        f"{len(weapon_entries)} weapon animation sheets in {ENEMY_ANIM_OUT.parent.parent}"
    )


if __name__ == "__main__":
    main()
