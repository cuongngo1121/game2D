# REFACTOR - boss 64x64

Native 64x64 RGBA pixel frames for the PRISM SPIRE boss. The player-supplied
model at `assets/concepts/bosses/refractor_reference_user_source_v2.png` is
the source of truth. The runtime loads the horizontal sheets for `boss3`.

| Animation | Frames | FPS | Loop | Runtime state |
| --- | ---: | ---: | :---: | --- |
| `idle` | 4 | 6 | Yes | Core pulse and floating prism orbit |
| `move` | 6 | 10 | Yes | Mechanical leg glide and refraction trail |
| `attack` | 4 | 12 | No | Laser charge and prism burst |
| `hurt` | 3 | 10 | No | Magenta refraction damage response |
| `death` | 6 | 8 | No | Prism-collapse disintegration before reward UI |

Each `*_Nx64.png` is the runtime spritesheet. Numbered PNG files are
individual editable frames. Regenerate the whole package with:

```powershell
.\tools\generate_refractor_64.ps1
```
