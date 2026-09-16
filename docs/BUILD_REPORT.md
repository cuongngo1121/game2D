# NEON RESONANCE — build verification

Build date: 2026-09-07, local timezone Asia/Saigon.
Engine: Godot 4.5.2 stable, official commit `6ce3de25a`.
Renderer configured for the game: Compatibility / OpenGL.

## Delivered artifacts

| Artifact | Bytes | MiB | SHA-256 |
| --- | ---: | ---: | --- |
| `builds/android/NEON-RESONANCE-debug.apk` | 62,058,309 | 59.18 | `A5C68569D0DEBA1EB123CCC4802B01C637671ACEC620567C09F33C4F90FC3EBF` |
| `builds/windows/NEON-RESONANCE.exe` | 96,457,168 | 91.99 | `7B036B6B606B17D72467FCBD021B67FE94FE243199FB28CD99CC3FC930C9AA5A` |

The Windows executable contains its resource pack. The Android APK uses the local
development keystore at `.tools/debug.keystore`; it is a sideload testing build.
The `.apk.idsig` sidecar is not required for ordinary APK installation.
This APK was rebuilt after adding the ECHO TERMINAL backdrop and includes the
imported `echo_terminal_backdrop.png` texture in the Godot resource pack.

## APK contents and manifest

The final APK was inspected with Android SDK 35.0.0 `aapt`, and its ZIP entries were
checked directly:

- Package: `com.noctis.neonresonance`.
- Display name: `NEON RESONANCE`.
- Version: `0.1.0`, version code `1`.
- Minimum SDK: **24**, meaning Android 7.0 or later.
- Target SDK: **35**; compile SDK: 35.
- CPU libraries: **ARM64 (`arm64-v8a`) and ARMv7 (`armeabi-v7a`)**.
- Fixed landscape orientation; small, normal, large, and xlarge screen support.
- Normal launcher activity: `com.godot.game.GodotApp`.
- The manifest declares only **`android.permission.VIBRATE`**. It does not declare
  Internet or network-state permission.
- The ordinary `LAUNCHER` intent category is present; the game is not registered
  as a replacement home-screen launcher.
- Android `appCategory` is game (`0` in Android's manifest enum).
- All four runtime data files are included: `enemies.json`, `stages.json`,
  `upgrades.json`, and `weapons.json`.
- `assets/licenses/Godot.txt` and `assets/fonts/OFL.txt` are included.
- No files from project `.tools/`, `tools/`, `tests/`, `docs/`, or `builds/` were
  found in the APK's runtime assets.

Android SDK `apksigner verify --verbose` succeeded. APK signature schemes **v2 and
v3** verified with **one signer**. The minimum supported Android version does not
require a v1 signature.

## Build execution

The build used official Godot 4.5.2 Android and Windows export templates, Android
SDK build tools 35.0.0, platform 35, and Android Studio's bundled JBR 21.
Godot editor settings were stored in `.tools/godot/editor_data`; process APPDATA
was redirected into the workspace. Global user editor configuration was not used
as the project's export configuration.

The first Android attempt stopped before creating an APK because Android texture
import had not been enabled. Godot's exporter returned an empty configuration
error. Inspection of Godot's exporter identified the missing prerequisite:

```ini
[rendering]
textures/vram_compression/import_etc2_astc=true
```

After adding this project configuration, the corrected Android export and the
Windows export both completed successfully. There was one successful build per
target; successful builds were not repeated.

The non-Gradle preset leaves `gradle_build/min_sdk` and `target_sdk` empty because
those overrides apply to Gradle builds only. The prebuilt APK template determines
the verified minimum SDK 24 and target SDK 35.

Reproduction command from the repository root:

```powershell
.\tools\export_android.ps1 `
  -JavaSdkPath 'C:\Program Files\Android\Android Studio\jbr' `
  -AlsoWindows
```

For another machine, pass `-AndroidSdkPath` and `-JavaSdkPath` as appropriate. See
`tools/README.md` for setup and development commands.

## Validation boundaries

- The focused rhythm/audio/save suite passed **50 checks** on Godot 4.5.2.
- The safe-area suite passed **18 checks**, covering uniform fitting, asymmetric
  insets, existing letterboxing, repeated refresh without cumulative scaling,
  unchanged world coordinates, CanvasLayer placement, raw touch coordinate
  conversion, built-in GUI clicks, and cleanup. Its reproducible source is
  `tests/safe_area_test.gd`.
- The exported Windows executable completed a **90-frame headless startup smoke**
  with exit code 0 and no missing-resource or GDScript errors. A headless startup
  does not establish visual quality or interactive playability.
- This restricted Windows environment logged a root-certificate-store error from
  Godot startup. Headless editor setup also logged editor RID/ObjectDB teardown
  warnings; the packaged headless smoke logged an ObjectDB teardown warning.
  These warnings remain recorded rather than being represented as clean logs.
- **No Android device installation, physical multitouch test, mobile audio
  latency measurement, battery/thermal test, or real-device frame-rate test was
  performed for these artifacts.** Android signature/manifest verification proves
  package structure and signing; it does not substitute for on-device playtesting.
- Store release signing and publication are outside this delivered debug build.

Relevant evidence logs remain in `.tools/export_android.log`,
`.tools/export_windows.log`, `.tools/rhythm_save_test.log`,
`.tools/safe_area_check.log`, and `.tools/windows_export_smoke.log`.

Official references: [Godot Android export](https://docs.godotengine.org/en/4.5/tutorials/export/exporting_for_android.html),
[Godot viewport transforms](https://docs.godotengine.org/en/4.5/tutorials/2d/2d_transforms.html),
and [Godot Android exporter implementation](https://github.com/godotengine/godot/blob/4.5-stable/platform/android/export/export_plugin.cpp).
