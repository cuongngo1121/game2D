# NEON RESONANCE

Game hành động bắn súng top-down, offline, dành cho Android chiều ngang và Windows.
Bạn vào vai **ECHO RUNNER**, đi qua năm khu vực của thành phố **NOCTIS**, khôi phục từng lớp nhạc và đối đầu **THE SILENCE**.

Dự án dùng **Godot 4.5.2 Standard + GDScript**, renderer **Compatibility / OpenGL**. Toàn bộ mã nguồn, dữ liệu, hình ảnh, WAV, font và công cụ riêng của dự án nằm trong thư mục này.

## Chơi trên máy tính

Trong PowerShell:

```powershell
Set-Location 'C:\Project\Game Android 2D'
.\tools\run_pc.ps1
```

Mở editor:

```powershell
.\tools\run_pc.ps1 -Editor
```

Các script này dùng Godot portable tại `.tools/godot/` và lưu dữ liệu chơi tại `.tools/play_appdata/`. Đây là cách chạy khuyến nghị trong môi trường Codex hiện tại: lần chạy ban đầu không có quyền tạo log trong AppData mặc định đã khiến Godot bị crash. Cấu hình portable và đường dẫn log trong dự án đã chạy được cả headless lẫn cửa sổ OpenGL. Không cần chạy lại file executable theo cách đã gây lỗi.

Bản Windows sau export nằm tại `builds/windows/NEON-RESONANCE.exe`. Nếu chạy executable trực tiếp ngoài môi trường hạn chế, game dùng thư mục dữ liệu ứng dụng bình thường của Windows.

## Cài Android

APK debug sau export: `builds/android/NEON-RESONANCE-debug.apk`.

Chép APK sang điện thoại rồi mở để cài, hoặc dùng ADB:

```powershell
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" devices
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" install -r '.\builds\android\NEON-RESONANCE-debug.apk'
```

Chỉ chạy lệnh cài khi đúng thiết bị của bạn đã hiện trong danh sách ADB. APK debug này phục vụ cài thử trực tiếp; chưa phải bản đã phát hành lên Google Play. Dự án không dùng tài khoản, Internet, quảng cáo hay giao dịch trong ứng dụng.

## Vòng lặp debug trên Android

Bạn có thể vừa đặt breakpoint trên PC vừa kiểm tra cùng bản build trên điện thoại. Mở một cửa sổ PowerShell để chạy Godot editor:

```powershell
Set-Location 'C:\Project\Game Android 2D'
.\tools\run_pc.ps1 -Editor
```

Trong editor, đặt breakpoint trong `scripts/main.gd`, `scripts/player/player.gd`, `scripts/combat/enemy_system.gd` hoặc `scripts/audio/rhythm_manager.gd`, rồi bấm Play để debug nhanh bằng PC. Godot có Debugger panel và stack trace khi chương trình dừng tại breakpoint; xem [Debugger panel của Godot](https://docs.godotengine.org/en/4.5/tutorials/scripting/debug/debugger_panel.html).

Khi cần kiểm tra hành vi thật trên Android, bật Developer options và USB debugging trên điện thoại, chấp nhận hộp thoại RSA, rồi mở cửa sổ thứ hai:

```powershell
Set-Location 'C:\Project\Game Android 2D'
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" devices -l
.\tools\android_debug.ps1 -Build -Install -Launch
```

Giữ log trong cửa sổ thứ ba:

```powershell
.\tools\android_debug.ps1 -Logs
```

Để lấy một snapshot nhanh về frame time và bộ nhớ sau khi chơi vài phút:

```powershell
.\tools\android_debug.ps1 -Performance
```

Kết quả nằm ở `.tools/android_perf.txt`. Đây là số đo trên thiết bị cụ thể; không nên suy ra FPS trung bình từ một snapshot duy nhất.

Khi tái hiện lỗi, dùng `-ClearLog -Launch` để bắt đầu phiên sạch. Log được ghi vào `.tools/android_logcat.txt`; khi cần chẩn đoán, gửi file này cùng seed, khu vực, phòng, thao tác cuối và model Android. Nếu có nhiều thiết bị, thêm `-DeviceSerial <serial>`.

Vòng lặp nên giữ mỗi lần thay đổi nhỏ: sửa một hành vi hoặc asset → chạy test mục tiêu trên PC → build/cài APK debug → tái hiện bằng cùng seed → lưu log và ảnh màn hình → sửa tiếp. `adb install -r` giữ dữ liệu ứng dụng; script không tự xóa dữ liệu. Khi cần kiểm tra cài đặt mới hoàn toàn, gỡ package có chủ đích rồi cài lại.

Godot hỗ trợ remote debugger bằng tham số `--remote-debug <protocol>://<host/IP>[:port]`; xem [Command line tutorial](https://docs.godotengine.org/en/4.5/tutorials/editor/command_line_tutorial.html). Với project này, cách ổn định nhất là chạy breakpoint trong editor trên PC và dùng APK debug/ADB để kiểm tra phần chỉ có trên Android. One-click deploy từ editor có thể dùng sau khi SDK/JDK đã cấu hình, nhưng vẫn cần điện thoại thật để xác minh cảm ứng, âm thanh, safe area và hiệu năng.

## Điều khiển

| Thao tác | Cảm ứng Android | Bàn phím / chuột |
| --- | --- | --- |
| Di chuyển | Kéo vùng trái; joystick nhận vị trí bắt đầu của ngón | WASD |
| Bắn | Giữ BẮN; mặc định tự ngắm vào địch có đường nhìn | Giữ chuột trái, ngắm bằng chuột |
| Dash | Chạm DASH; có thể trượt ngón từ BẮN sang DASH | Space |
| Pulse Burst | Chạm PULSE khi đủ cộng hưởng | Q |
| Đổi súng | ĐỔI | Tab |
| Tương tác | DÙNG hiện khi đứng gần cửa hoặc trạm hỗ trợ | E |
| Gọi lại súng miễn phí | Mục Gọi lại Pulse Pistol trong Pause | R |
| Tạm dừng | Nút Ⅱ hoặc nút Back Android | Esc / P |
| Bản đồ | Nút BẢN ĐỒ | Bấm BẢN ĐỒ bằng chuột |

Hai ngón đủ để vừa đi vừa chiến đấu. Khi trượt ngón đang giữ BẮN sang DASH, súng tiếp tục trong một khoảng ngắn trong lúc dash. Có thể tắt tự ngắm để dùng hướng kéo ở nút bắn làm hướng ngắm. Pause, chọn thưởng, mở settings và chuyển ứng dụng đều xóa thao tác đang giữ; khi trở lại phải chủ động tiếp tục.

## Tự vẽ ranh giới di chuyển route map (LV1 và LV2, PC development)

Hai khu vực route map đầu tiên không còn lấy vùng đi được từ một hình chữ nhật lớn. [`data/map_boundaries_lv1.json`](data/map_boundaries_lv1.json) lưu polygon theo pixel gốc của ảnh ECHO TERMINAL; [`data/map_boundaries_lv2.json`](data/map_boundaries_lv2.json) làm điều tương tự cho ảnh BASS FOUNDRY amber. **Cùng một polygon** được dùng để vẽ khung vùng đi được và chặn nhân vật/địch, vì vậy sửa một nơi sẽ không làm viền map và va chạm lệch nhau.

World LV1 lúc chơi có kích thước **4320 × 2304** — lớn `2,25×` theo mỗi chiều so với bản 1920 × 1024 cũ (diện tích đi lại khoảng `5,06×`). World LV2 giữ tỉ lệ 4:3 của bản amber, **2896 × 2172**, từ texture gốc **1448 × 1086**. Editor luôn hiển thị pixel gốc của ảnh để dễ canh tường; hệ thống tự nhân cùng tỉ lệ này cho ảnh, polygon, điểm vào phòng và lối đi, nên phóng to world không làm thay đổi tọa độ đã vẽ.

Mở game trên Windows bằng `./tools/run_pc.ps1`, đi vào khu vực muốn chỉnh, rồi nhấn **F6** để mở **MAP BOUNDARY EDITOR · LV1** hoặc **LV2** tương ứng. Editor tự nhớ bước lưới, zoom và vị trí xem khi đóng/mở lại cùng khu vực; chuyển từ LV1 sang LV2 sẽ đổi ảnh và JSON đúng khu vực, đồng thời đưa khung nhìn về tâm ảnh mới. Đây là công cụ cho lúc phát triển trên PC, không phải màn hình xuất hiện cho người chơi Android.

- Chọn phòng qua các nút `1 C1` … `6 Boss`, hoặc phím `1`–`6`.
- Editor mở với **lưới snap 8 px**: đỉnh mới và mọi thao tác kéo đều tự nhảy vào tọa độ rời rạc bội số của 8, không tạo các số lẻ khó canh tường. Dùng nút `−/+` ở hàng LƯỚI hoặc phím `G` để đổi giữa `2`, `4`, `8`, `16` và `32 px`. Mức `2 px` là khoảng cách nhỏ nhất giữa hai điểm snap, bằng một nửa mức nhỏ nhất cũ (`4 px`); nên dùng cùng zoom để canh chính xác mép tường.
- Bấm trái trong ảnh để thêm đỉnh; bấm/kéo một chấm vàng để chỉnh đỉnh đã có. Sau khi chọn một đỉnh, dùng mũi tên để dịch chính xác `± bước lưới`; giữ Shift + mũi tên để dịch `4 × bước lưới`.
- Lăn chuột để phóng to/thu nhỏ quanh con trỏ. Giữ chuột giữa rồi kéo để di chuyển vùng đang xem; nút `1:1` hoặc phím `0` đưa ảnh về khung nhìn đầy đủ 100%. Zoom chỉ đổi cách nhìn, không tự thay đổi tọa độ hay polygon.
- Bấm phải, `Z` hoặc Backspace để bỏ đỉnh cuối. Nếu muốn vẽ hoàn toàn lại một phòng, `C`/`XÓA PHÒNG` lần đầu chỉ hỏi xác nhận, lần thứ hai trong 2,5 giây mới xóa.
- `R`/`KHÔI PHỤC` cũng cần xác nhận hai lần và chỉ trả phòng đang chọn về polygon mẫu. Đây là cách an toàn để quay lại bố cục ban đầu khi vẽ thử sai.
- Nhấn `S` hoặc `LƯU S` để kiểm tra rồi ghi tệp JSON. Mỗi phòng cần ít nhất ba đỉnh, có diện tích thực và không có hai cạnh tự cắt. Nếu sai, editor báo lý do và **không** ghi dữ liệu hỏng.
- `Esc`, F6 hoặc `ĐÓNG` đóng editor. Nếu có thay đổi chưa lưu, phải đóng lần thứ hai trong 2,5 giây; thao tác đó phục hồi polygon đã lưu thay vì để map đang chơi rơi vào trạng thái dở dang.

Sau khi lưu, tiếp tục/chạy lại game bình thường để kiểm tra nhân vật có bị chặn đúng tường hay không. Khi thay ảnh nền của LV1 hoặc LV2, phải vẽ lại polygon của chính khu vực đó vì các điểm này dựa trên pixel ảnh gốc.

## Các cơ chế cần biết

- **Máu và khiên:** khiên nhận sát thương trước. Sau 4 giây không trúng đòn, khiên hồi 13 điểm/giây; nâng cấp có thể thay đổi thời gian chờ. Một lần trúng đòn cho 0,85 giây bất tử để tránh mất toàn bộ máu bởi một cụm đạn.
- **Dash:** kích hoạt ngay, bất tử 0,23 giây, di chuyển nhanh 0,19 giây, hồi ban đầu 1,65 giây. Dash tránh đạn, laser và vùng sàn theo cùng quy tắc bất tử; không xuyên vật cản.
- **Perfect Dash:** thực hiện dash trong khoảng ±120 ms quanh beat khi đang giao tranh nhận 18 cộng hưởng. Một lần nhấn chỉ được ghi nhận một lần. Di chuyển, bắn và dash lệch nhịp vẫn diễn ra ngay.
- **Resonance:** tăng khi hạ địch và Perfect Dash; giảm 14 khi bị đánh. Giữ bắn không tự nhận thưởng nhịp. Khi đầy 100, Pulse Burst gây 95 sát thương trong bán kính 155 px và xóa đạn thường trong vùng. Laser và nguy hiểm trên sàn không bị xóa.
- **Năng lượng:** tự hồi; hạ địch rơi thêm năng lượng và tín dụng. Nếu súng đang cầm không đủ năng lượng, thao tác bắn tự dùng Pulse Pistol miễn phí tạm thời. Không có tình trạng hết pin khiến người chơi mất hoàn toàn khả năng tấn công.
- **Cảnh báo:** đòn nặng có thời gian báo trước ít nhất `max(0,8 giây, 2 beat)`. Đường/vùng cảnh báo được khóa trước lúc đánh. Nguy hiểm dùng cả hình dạng, đường viền, nét gạch và lõi sáng; vẫn đọc được khi tắt tiếng.
- **Nhạc:** mỗi màn có ba WAV cùng playhead: khám phá, chiến đấu và boss. Đổi phối ở đầu ô nhịp. Nhịp dùng playhead âm thanh đã tính độ trễ đầu ra; headless dùng clock mô phỏng riêng để test. Frame chậm không phát bù hàng loạt đòn đánh.

## Tiến trình một lượt

Mỗi khu vực có **bốn phòng chiến đấu**, **một phòng hỗ trợ trên nhánh phụ** và **một boss**. Bốn phòng chiến đấu chọn từ ba mẫu hình học riêng theo seed; mỗi phòng có 3–4 đợt địch. Cửa tính cả đợt chưa xuất hiện nên không mở sớm. Chọn một nâng cấp hoặc hồi máu sau khi dọn phòng. Phòng hỗ trợ cho một lần dùng: rương súng, cửa hàng hoặc trạm hồi phục theo seed. Boss chỉ mở khi đã dọn đủ bốn phòng chính.

Sau boss, nhận thưởng rồi đi qua cổng chuyển khu vực. Thắng boss thứ năm và dùng cổng cuối sẽ khôi phục NOCTIS, mở màn hình Victory. Khi thất bại, vũ khí/nâng cấp/tín dụng trong lượt mất; mảnh cộng hưởng dùng để mở thêm lựa chọn súng ban đầu. Mọi vũ khí vẫn có thể tìm trong lượt mà không cần mở khóa trước, không có chỉ số vĩnh viễn bắt buộc phải cày.

| Khu vực | BPM | Cơ chế nổi bật | Boss |
| --- | ---: | --- | --- |
| ECHO TERMINAL — Ga Vọng Âm | 90 | Đường ray điện, drone áp sát, quạt đạn | CONDUCTOR-01 |
| BASS FOUNDRY — Xưởng Hạ Âm | 100 | Piston, băng chuyền, máy lao, cung sóng | SUBWOOFER |
| LUMINOUS GROVE — Vườn Dữ Liệu | 110 | Dấu xung đứng yên, đạn tách, triệu hồi giới hạn | CHOIR WIDOW |
| PRISM SPIRE — Tháp Lăng Kính | 120 | Laser khóa đường và phản xạ một lần, đạn xoắn | REFRACTOR |
| SILENT CORE — Lõi Tĩnh Lặng | 128 | Nguy hiểm sàn theo chuỗi, tổ hợp vai trò, ba phase | NULL MAESTRO |

Chi tiết 12 vũ khí, 13 nâng cấp, asset và nguồn sinh: [docs/CONTENT.md](docs/CONTENT.md).

## Lưu và tiếp tục

Checkpoint là **toàn bộ snapshot**: seed, khu vực/phòng, danh sách đã dọn và đã nhận thưởng, HP/khiên/năng lượng/cộng hưởng, hai súng, ô đang cầm, nâng cấp, tiền, thời gian và thống kê.

Mốc lưu: khởi đầu lượt/khu vực và sau khi hoàn tất lựa chọn thưởng hoặc dịch vụ phòng hỗ trợ. Đi vào một phòng chưa hoàn thành giữ checkpoint phòng an toàn gần nhất. Nếu hệ điều hành đóng game giữa giao tranh, tiếp tục sẽ quay về mốc đó; tiến trình chưa được checkpoint có thể phải chơi lại. Không lưu lẫn trạng thái giữa hai thời điểm.

Save có phiên bản, checksum, revision, ghi tệp tạm rồi thay thế và bản phục hồi. Khi chết/thắng, checkpoint được xóa trong cùng snapshot cập nhật thống kê. Bản mới hợp lệ được ưu tiên khi phục hồi, tránh khôi phục checkpoint cũ của lượt đã chết. Cài đặt và nội dung mở khóa lưu riêng về mặt logic nhưng cùng một snapshot vật lý.

## Build lại

Công cụ đã dùng trong môi trường này:

- Godot **4.5.2 Standard**, cùng export templates **4.5.2.stable**.
- Android SDK Platform **35**, Build Tools **35.0.0**, Platform Tools có ADB.
- JBR **21.0.10** của Android Studio; Godot khuyến nghị OpenJDK 17 và hỗ trợ bản mới hơn.
- Python **3.14** cho sinh asset/kiểm tra dữ liệu; script sử dụng standard library, tương thích Python 3.10+.

```powershell
Set-Location 'C:\Project\Game Android 2D'
.\tools\export_android.ps1 `
  -JavaSdkPath 'C:\Program Files\Android\Android Studio\jbr' `
  -AlsoWindows
```

Có thể truyền `-AndroidSdkPath`, `-JavaSdkPath`, `-GodotPath` khi máy khác có đường dẫn khác. `-PrepareOnly` chỉ chuẩn bị cấu hình. Script sinh debug keystore tại `.tools/debug.keystore` nếu chưa có, cấu hình editor portable, xuất APK và kiểm tra chữ ký bằng `apksigner`; `-AlsoWindows` xuất thêm `.exe`.

Preset Android dùng template trực tiếp, không Gradle. Mức SDK thực tế lấy từ template và được ghi trong báo cáo sau khi đọc manifest APK; các trường override dành riêng Gradle để trống.

Nếu chuyển riêng mã nguồn sang máy khác: tải [Godot 4.5.2 và export templates chính thức](https://godotengine.org/download/archive/4.5.2-stable/), giải nén engine vào `.tools/godot/`; đặt `android_debug.apk`, `android_release.apk`, `windows_debug_x86_64.exe` và `windows_release_x86_64.exe` từ templates vào `.tools/templates/`. Hướng dẫn công cụ chi tiết: [tools/README.md](tools/README.md). Tài liệu engine: [export Android cho Godot 4.5](https://docs.godotengine.org/en/4.5/tutorials/export/exporting_for_android.html).

## Kiểm thử

```powershell
python .\tests\test_content.py
.\tools\run_tests.ps1 -Tests @(
  'tests/rhythm_save_test.gd',
  'tests/combat_test.gd',
  'tests/gameplay_test.gd'
)
```

`tests/render_smoke.gd` cần renderer thật, tạo ảnh PNG từ viewport và bơm sự kiện ScreenTouch để kiểm tra GUI. Không chạy script này với `--headless` vì nó chờ frame render. Báo cáo bằng chứng và phần chưa kiểm chứng: [docs/TEST_REPORT.md](docs/TEST_REPORT.md). Ảnh từ runtime nằm trong `builds/screenshots/`.

## Cấu trúc nguồn

```text
project.godot / scenes/main.tscn    Cấu hình engine và composition scene
scripts/main.gd                    Điều phối lượt, thưởng, chuyển phòng, checkpoint
scripts/player/                    Player, input đa chạm, 12 hành vi vũ khí
scripts/combat/                    Địch/boss/bẫy, pooling và va chạm projectile
scripts/core/                      Đồ thị phòng có seed, save/settings
scripts/audio/                     Đồng hồ beat và lớp nhạc/SFX
scripts/world/                     Vẽ phòng, đồ trang trí, hiệu ứng
scripts/ui/                        Menu, HUD, modal, cài đặt, safe area
data/                             Dữ liệu màn, địch, súng, nâng cấp có thể chỉnh
assets/                           SVG, WAV, font và giấy phép
tests/                            Kiểm tra dữ liệu, logic và render
tools/                            Sinh asset, chạy, test, export
builds/                           Sản phẩm export và ảnh kiểm tra
```

Không có nội dung mạng hay engine phụ. Mã gameplay dùng các module riêng; các con số chiến đấu bổ sung như cửa sổ dash nằm trong module tương ứng. Thay dữ liệu JSON trực tiếp để cân bằng; nếu chạy lại `tools/generate_assets.py`, cần cập nhật cả nguồn sinh vì script sẽ ghi lại dữ liệu và asset.

## Nguồn và giấy phép

Đồ họa SVG và nhạc/SFX synth do dự án tự sinh, không dùng asset Soul Knight. Font Noto Sans đi kèm SIL Open Font License. Xem [docs/ASSET_LICENSES.md](docs/ASSET_LICENSES.md). Godot là công cụ mã nguồn mở theo MIT.

## Giới hạn hiện tại

Đây là bản playable đầu tiên có toàn bộ tuyến năm khu vực, không phải bản đã được playtest và chứng nhận phát hành. Phần player hiện dùng pixel-art 32×32 với animation idle/run/attack/dash/hurt/death; các sprite SVG procedural cũ vẫn được dùng cho fallback và các asset khác. Nhạc gồm loop điện tử bốn ô nhịp với các lớp liên kết, có thể lặp rõ khi chơi lâu. Chưa có cân bằng qua người chơi thật để xác minh thời lượng 25–40 phút, độ công bằng của mọi tổ hợp seed và chất lượng điều khiển trên nhiều kích thước điện thoại.

Chưa đo 60 FPS, độ trễ âm thanh, rung, đa chạm vật lý, camera khuyết, khóa màn hình hoặc khôi phục sau hệ điều hành kill trên Android thật. Kiểm thử tiến trình dùng sát thương điều khiển để xác nhận state machine; không thay thế một lượt thắng bằng kỹ năng của người chơi. Không tuyên bố APK đã cài trên điện thoại nếu chưa có bằng chứng trong báo cáo.
