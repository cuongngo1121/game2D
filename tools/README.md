# Local development and export scripts

All commands below run from the repository root in PowerShell. The scripts use
Godot 4.5.2 under `.tools/godot`, enable its portable `_sc_` mode, and redirect
process `APPDATA` into `.tools`. They restore environment variables when finished.
This keeps test saves separate from play saves and avoids changing the user's
global Godot editor configuration.

```powershell
# Play, or open the editor.
.\tools\run_pc.ps1
.\tools\run_pc.ps1 -Editor

# Build, cài APK debug lên điện thoại USB và mở game.
.\tools\android_debug.ps1 -Build -Install -Launch

# Theo dõi log Android; nhấn Ctrl+C để dừng.
.\tools\android_debug.ps1 -Logs

# Xóa log cũ rồi mở lại game.
.\tools\android_debug.ps1 -ClearLog -Launch

# Chụp gfxinfo framestats và meminfo của package đang chạy.
.\tools\android_debug.ps1 -Performance

# Khi có nhiều thiết bị/emulator:
.\tools\android_debug.ps1 -DeviceSerial R58M... -Install -Launch

# Run the focused rhythm/audio/save checks.
.\tools\run_tests.ps1

# Import first when setting up a fresh checkout; choose additional test scripts.
.\tools\run_tests.ps1 -Import -Tests @('tests/rhythm_save_test.gd')

# Configure the SDK/JDK and local debug key without exporting a game build.
.\tools\export_android.ps1 -PrepareOnly

# Export a signed Android debug APK, verify its signature, and also export Windows.
.\tools\export_android.ps1 -AlsoWindows

# SDK/JDK paths can be supplied explicitly on another machine.
.\tools\export_android.ps1 -AndroidSdkPath 'D:\Android\Sdk' -JavaSdkPath 'D:\Java\jdk-17'
```

`export_android.ps1` first checks `ANDROID_SDK_ROOT`, then `ANDROID_HOME`, then the
standard Windows Android SDK location. Java uses `JAVA_HOME`, with Android Studio's
bundled `jbr` as fallback. The standard Android SDK build tools 35.0.0 and platform
35 must exist. The prebuilt APK template path is used, so this script does not
start Gradle, install packages, or download dependencies.

The required engine templates are `.tools/templates/android_debug.apk`,
`android_release.apk`, `windows_debug_x86_64.exe`, and
`windows_release_x86_64.exe` from the official Godot 4.5.2 template archive.
`export_presets.cfg` references these local files. Runtime JSON under `data/` is
included in exports; tooling, tests, documentation, and downloaded tools are not.

Outputs are `builds/android/NEON-RESONANCE-debug.apk` and, with `-AlsoWindows`,
`builds/windows/NEON-RESONANCE.exe`. Android contains ARMv7 and ARM64 libraries.
The APK is signed with `.tools/debug.keystore`, a local development key using
Android's public standard debug password. It is suitable for sideload testing.
Store release signing and publication require a separate release key and process.

Development play saves are under `.tools/play_appdata/Godot/app_userdata/`.
Focused test saves use `.tools/test_appdata/Godot/app_userdata/`; the save tests
create uniquely named files and remove those files after their checks. Exported
games use Godot's normal platform-specific `user://` application data directory.
Logs from these scripts are under `.tools/`.

`android_debug.ps1` dùng `adb install -r`, giữ dữ liệu ứng dụng hiện tại, mở activity
`com.godot.game.GodotApp` và lọc log Godot vào `.tools/android_logcat.txt`. Script
chỉ chạy các bước tương ứng với switch bạn truyền; nếu không có thiết bị ở trạng
thái `device`, nó dừng và in danh sách ADB hiện tại.

Relevant official references:
[Android export](https://docs.godotengine.org/en/4.5/tutorials/export/exporting_for_android.html),
[command line usage](https://docs.godotengine.org/en/4.5/tutorials/editor/command_line_tutorial.html),
and [portable editor mode](https://docs.godotengine.org/en/4.5/classes/class_editorpaths.html).
