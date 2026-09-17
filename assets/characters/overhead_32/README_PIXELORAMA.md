# ECHO RUNNER — overhead 32 px sprite pack

The source model faces right. Godot rotates the character and the separately
drawn weapon by the same `aim_direction.angle()`, so the amber pixel on the
right glove remains at the weapon grip. Do not draw a second weapon into these
frames.

## Pixelorama import

Open a `*Nx32.png` sheet as a spritesheet, set width and height to `32`, then
use the number before `x32` as the column count. Keep transparent alpha and
nearest-neighbor filtering. Enable looping only for `idle`, `run`, and
`run_attack`.

| Animation | Frames | FPS | Loop |
| --- | ---: | ---: | --- |
| idle | 4 | 6 | yes |
| run | 6 | 10 | yes |
| attack | 6 | 12 | no |
| run_attack | 6 | 12 | yes while the firing window is active |
| dash | 4 | 16 | no |
| hurt | 3 | 10 | no |
| pulse | 6 | 12 | no |
| death | 6 | 8 | no |

`pulse` is the six-frame one-shot used when Resonance reaches 100. The sprite
frames animate the runner's charge/release pose; the expanding world-space
wave is drawn by `EchoPlayer` so its radius follows the Pulse upgrade level.
