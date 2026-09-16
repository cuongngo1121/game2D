# NULL MAESTRO - boss 64x64

Native 64x64 RGBA pixel frames for the SILENT CORE final boss. The canonical
concept is `assets/concepts/bosses/null_maestro_reference_generated_v1.png`.
The runtime loads the horizontal sheets below for `boss4`.

| Animation | Frames | FPS | Loop | Runtime state |
| --- | ---: | ---: | :---: | --- |
| `idle` | 4 | 6 | Yes | Silent core pulse and note-shard orbit |
| `move` | 6 | 10 | Yes | Conducting glide and beat trails |
| `attack` | 4 | 12 | No | Ring/laser command burst |
| `hurt` | 3 | 10 | No | Chromatic glitch when damaged |
| `death` | 6 | 8 | No | Quiet disintegration before victory UI |

Each `*_Nx64.png` is the runtime spritesheet. Numbered PNG files are
individual editable frames. Regenerate the complete package with:

```powershell
.\tools\generate_null_maestro_64.ps1
```
