# Báo cáo kiểm thử — NEON RESONANCE 0.1

Ngày thực hiện: **06/09/2026**. Engine thực tế: **Godot 4.5.2.stable.official.6ce3de25a** trên Windows. Kiểm tra đồ họa dùng **OpenGL 3.3 Compatibility, NVIDIA GeForce RTX 3050 Laptop GPU, driver 556.12**. Không có thiết bị trong kết quả `adb devices` tại thời điểm kiểm tra.

## Kết quả đã có bằng chứng

| Nhóm | Kết quả | Phạm vi thực tế |
| --- | --- | --- |
| Dữ liệu/asset | 8/8 test đạt | 12 vũ khí, 13 nâng cấp, 10 địch, 5 khu vực; tham chiếu asset; font tiếng Việt; 15 WAV đúng số frame/BPM; SVG hợp lệ; 40 trường hợp hình học phòng với hitbox 11/15 px. |
| Nhạc/nhịp/lưu | 50 kiểm tra đạt | Beat, pause/resume, offset, ±120 ms, clock im tiếng, loop/stall không phát bù, đổi lớp ở bar, giới hạn SFX, round-trip snapshot, checksum/corruption recovery và xóa checkpoint khi kết thúc. |
| Combat | 82 kiểm tra đạt | Swept collision với tường/mục tiêu, cover, hit ledger, xuyên/nảy có giới hạn, đạn nổ trễ/đĩa/tách nhánh, Pulse, pooling, 10 hành vi địch, 11 tổ hợp boss/phase, cảnh báo khóa đường, giới hạn triệu hồi, tìm đường, callback chết/đổi phase trong vòng xử lý. |
| Gameplay trên main scene | 327 kiểm tra đạt | 5.000 tổ hợp seed/khu vực nối đủ 6 phòng, tái tạo ổn định; tiến trình đủ 30 phòng và 5 boss bằng sát thương điều khiển; phần thưởng một lần; trạm hỗ trợ; chuyển khu vực; checkpoint JSON; thắng/chết/chơi lại; cả 12 vũ khí gây sát thương; khiên/dash/Perfect/Pulse; nâng cấp và ba tổ hợp; input đa chạm tổng hợp. |
| Safe area | 18 kiểm tra đạt | Fit đồng nhất, giữ tỷ lệ, vùng letterbox, biến đổi ngược tọa độ touch/GUI, refresh không tích lũy sai số hoặc liên tục reset thao tác. Dùng safe rect tổng hợp trên máy tính. |
| Render và GUI cảm ứng | 20 kiểm tra đạt, 11 PNG | Render thực bằng OpenGL; ScreenTouch vào Bắt đầu, Settings, Lưu, chọn thưởng; GUI vẫn nhận đúng sau transform safe area; delta băng chuyền, dash trên băng chuyền và đổi cường độ nhạc khi boss chuyển phase. |
| APK | Xuất thành công; chữ ký hợp lệ | APK ARMv7 + ARM64, package `com.noctis.neonresonance`, landscape, min SDK 24, target SDK 35, quyền VIBRATE và không có INTERNET. Kiểm tra bằng `apksigner` và `aapt`. |
| Windows export | Xuất thành công; smoke mở được | Chạy chính `builds/windows/NEON-RESONANCE.exe` bằng OpenGL trên GPU nêu trên trong 180 frame. Không thấy lỗi script hoặc thiếu resource trong log đồ họa. Headless packaged startup riêng exit 0. |

Các nhóm trên là kiểm tra riêng và tích hợp có mục tiêu; không diễn giải tổng số assertion thành số giờ chơi hoặc chứng nhận chất lượng phát hành.

## Nội dung các ảnh runtime

Thư mục `builds/screenshots/` chứa ảnh do `Viewport.get_texture().get_image()` của Godot tạo, không phải ảnh thiết kế mô phỏng:

1. `01-menu-16x9.png`: menu.
2. `02-combat-16x9.png`: phòng chiến đấu khu vực đầu, cảnh báo đường ray và HUD.
3. `03-settings-16x9.png`: settings tiếng Việt.
4. `04-rewards-16x9.png`: chọn nâng cấp.
5. `05-map-16x9.png`: bản đồ và quyền đi tới phòng liền kề.
6. `06-final-boss-16x9.png`: đấu trường NULL MAESTRO.
7. `07-final-boss-20x9.png`: nội dung game khi cửa sổ rộng 20:9.
8. `08-settings-20x9.png`: settings trong cửa sổ rộng.
9. `09-victory-20x9.png`: màn hình Victory trong kịch bản render điều khiển.
10. `10-menu-simulated-notch.png`: menu thu gọn vào vùng an toàn giả lập.
11. `11-combat-simulated-notch.png`: gameplay sau khi nhấn Bắt đầu qua transform.

Ở kiểm tra 20:9, cửa sổ native là **1600×720**, nội dung logic vẫn **1280×720**, nằm giữa với letterbox hai bên. PNG chụp **viewport logic**, không chứa toàn bộ viền cửa sổ native. Đây là bằng chứng giữ tỷ lệ nội dung trong cửa sổ rộng; chưa phải ảnh của điện thoại 20:9.

Vùng camera khuyết mô phỏng dùng safe rect `(90,24,1190,680)` trong cửa sổ 1280×720. Godot áp dụng một phép scale/translate cho toàn bộ canvas; raw touch được biến đổi ngược theo engine. Kiểm tra xác nhận chạm nút ở tọa độ sau scale vẫn bắt đầu được lượt. Giá trị `DisplayServer.get_display_safe_area()` trên Android vật lý chưa được đo.

## Đo tải projectile

Giữ **300 projectile đang hoạt động**, **10 mục tiêu** và **3 vật cản**, chạy **600 tick mô phỏng**. Lần đo cuối của `combat_test.gd`: trung bình **4,370 ms/tick** cho vòng xử lý va chạm trên CPU máy tính, giữ đủ cả 300 viên. Pool được tái sử dụng; không xóa đạn để làm đẹp số đo.

Phép đo này chạy **headless**, không tính renderer, GPU, input vật lý, hệ điều hành Android, âm thanh thực hoặc toàn bộ chi phí frame. **Không chứng minh đạt 60 FPS trên Android.**

## Các lỗi đã gặp và xử lý

- **Godot crash truy cập bộ nhớ ở lần khởi động đầu:** log test trước crash ghi không tạo được `user://logs` ở AppData mặc định trong sandbox. Chạy lại bằng APPDATA riêng trong workspace và `--log-file` rõ ràng chạy được. Scripts play/test/export đều áp dụng cách này, không thay môi trường hệ thống vĩnh viễn. Không có kết luận RAM máy bị hỏng từ hộp thoại Windows.
- **Nút GUI không nhận touch khi tắt mouse emulation:** bật `emulate_mouse_from_touch` cho Godot Control; input gameplay bỏ qua chuột giả lập để ngón joystick không vô tình bắn. Đã kiểm tra lại bằng ScreenTouch, không chỉ chuột trái.
- **Mô tả tràn thẻ / thanh boss đè chữ:** sửa thứ tự áp dụng wrap/font/kích thước và đặt lại kích thước thanh sau theme. Đã xem PNG mới xác nhận chữ trong thẻ và thanh boss riêng với tên.
- **Lỗi `can_process()` khi thay overlay ngay trong callback nút:** giữ node ở tree tới lúc queue-free, ẩn và vô hiệu tương tác trước. Log render cuối không còn lỗi này.
- **Sai số nhỏ khi refresh safe area làm reset input:** dùng ngưỡng so sánh translation 0,01 px. Test nhiều refresh liên tiếp đạt.
- **Export Android báo “configuration errors” nhưng không ghi nguyên nhân:** thiếu `rendering/textures/vram_compression/import_etc2_astc=true`. Đã thêm, export và verify APK thành công sau sửa.

Không chạy lặp lại lệnh thành công nếu code liên quan không đổi. Các lần re-render phục vụ sửa lỗi layout hoặc kiểm tra phần mới (safe area, băng chuyền, phase audio). Không chạy lại toàn bộ các suite để lấy số đẹp.

## Thông báo môi trường còn thấy

Godot trong sandbox Windows ghi `Failed to read the root certificate store.` Game không có truy cập mạng và thông báo này không chặn load resource, render hoặc xuất/verify APK. Không tự thay kho chứng chỉ Windows.

Một số lần headless editor/test hoặc đóng gói headless ghi `ObjectDB instances leaked at exit`; các lần đó vẫn đạt assertion/exit được nêu. Đã dọn tham chiếu trong composition root; **log render nguồn cuối và smoke Windows OpenGL không còn cảnh báo ObjectDB**, nhưng chưa kiểm toán toàn bộ tài nguyên trên mọi vòng đời Android. Không tuyên bố hết mọi lỗi bộ nhớ chỉ từ một smoke test.

## Chưa kiểm chứng / công việc playtest còn lại

- Chưa cài APK lên Android thật hoặc chạy giả lập Android.
- Chưa xác minh điều khiển bằng hai ngón thực, độ trễ âm thanh theo loa/Bluetooth, rung, notification/focus, khóa màn hình, safe area thực hoặc process kill trên thiết bị.
- Chưa xác minh mục tiêu 60 FPS trên điện thoại tầm trung hay đo pin/nhiệt/RAM.
- Chưa có lượt thắng 5 màn do người chơi thật thực hiện; test đủ tuyến dùng sát thương điều khiển để kiểm tra tiến trình, phần thưởng và state. Cảm giác combat và việc mọi pattern luôn cho đường né cần playtest riêng.
- Chưa cân bằng và đo thời lượng 25–40 phút. Số đợt, HP, giá và nâng cấp hiện là giá trị khởi đầu có thể chỉnh.
- Đồ họa/animation procedural và loop bốn ô nhịp là mức playable đầu tiên; độ phong phú, độ lặp và độ dễ đọc trên điện thoại nhỏ cần đánh giá thực tế.
- Chưa ký release, tạo AAB hoặc phát hành lên cửa hàng. APK là bản debug cài thử.

## Tái tạo bằng chứng

```powershell
python .\tests\test_content.py
.\tools\run_tests.ps1 -Tests @('tests/rhythm_save_test.gd')
.\tools\run_tests.ps1 -Tests @('tests/combat_test.gd')
.\tools\run_tests.ps1 -Tests @('tests/gameplay_test.gd')
```

`safe_area_test.gd` và `render_smoke.gd` cần window/render thật. Chạy Godot console với APPDATA trong `.tools/test_appdata`, `--path` thư mục dự án, `--script res://tests/<tên>.gd` và `--log-file` nằm trong `.tools/`; **không dùng `--headless` cho render_smoke**. Chi tiết build/hash/manifest: [BUILD_REPORT.md](BUILD_REPORT.md).

Log gốc trong `.tools/`: `rhythm_save_test.log`, `combat_test.log`, `gameplay_test.log`, `render_smoke.log`, `render_stdout.log`, `render_stderr.log`, `export_android.log`, `export_windows.log` và `packaged_runtime.log`. Thư mục này là công cụ/dữ liệu cục bộ, được bỏ qua trong `.gitignore`.
