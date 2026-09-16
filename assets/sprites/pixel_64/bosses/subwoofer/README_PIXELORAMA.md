# SUBWOOFER — boss 64×64

Native 64×64 RGBA pixel frames for the BASS FOUNDRY boss. The visual source is
the player-supplied Subwoofer model at `assets/concepts/bosses/subwoofer_reference_user_v2.png`.
The runtime loads the horizontal sheets below through `EnemySystem` for `boss1`.

| Animation | Frames | FPS | Loop | Runtime state |
| --- | ---: | ---: | :---: | --- |
| `idle` | 4 | 6 | Yes | Waiting and boss preview |
| `move` | 6 | 10 | Yes | Boss path movement |
| `attack` | 4 | 12 | No | Beat attack / charge |
| `hurt` | 3 | 10 | No | Damage reaction |
| `death` | 6 | 8 | No | Defeat before reward UI |

Each `*_Nx64.png` is the runtime spritesheet. The numbered files are its
individual editable frames. Regenerate all assets with:

```powershell
.\tools\generate_subwoofer_64.ps1
```
