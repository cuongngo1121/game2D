# CHOIR WIDOW — boss 64x64

Native 64x64 RGBA pixel frames for the LUMINOUS GROVE boss. The visual source is
the player-supplied model at `assets/concepts/bosses/choir_widow_reference_user_source_v1.png`.
The runtime loads the horizontal sheets below through `EnemySystem` for `boss2`.

| Animation | Frames | FPS | Loop | Runtime state |
| --- | ---: | ---: | :---: | --- |
| `idle` | 4 | 6 | Yes | Telegraph / resting pulse |
| `move` | 6 | 10 | Yes | Leg sway and route movement |
| `attack` | 4 | 12 | No | Beat volley / summon cast |
| `hurt` | 3 | 10 | No | Damage reaction |
| `death` | 6 | 8 | No | Leaf-core collapse before reward UI |

Each `*_Nx64.png` is the runtime spritesheet. The numbered files are its
individual editable frames. Regenerate all assets with:

```powershell
.\tools\generate_choir_widow_64.ps1
```
