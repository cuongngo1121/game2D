# Kiểm chứng dữ liệu và tài sản

Ngày kiểm tra: 2026-09-06. Môi trường: Windows, Python 3.14, standard library.

Lệnh đã thực thi: `python tests/test_content.py`.

Kết quả ban đầu: **8 tests PASS**, thời gian báo bởi unittest: **1,376 giây**.
Sau khi đồng bộ mô tả vũ khí với gameplay, lần kiểm tra tiếp theo cũng có
**8 tests PASS**, thời gian **0,849 giây**. Sau đó kiểm tra lại phần mô tả hệ số
nâng cấp đã chỉnh tiếp tục **8/8 PASS** (0,846 giây). Các hệ số mô tả nâng cấp được đồng bộ
theo implementation của player/run: tốc độ +23 px/s, dash -0,23 s, khiên +20,
chờ hồi khiên -0,7 s, pin +30, hồi năng lượng +3,5/s, hút đồ +50 px,
Pulse Burst +30 sát thương/+32 px bán kính mỗi tầng.

| Kiểm tra | Bằng chứng |
| --- | --- |
| Số lượng nội dung và ID | 12 vũ khí, 13 nâng cấp, 13 địch thường (gồm 3 elite sau khoảng nghỉ), 5 màn, 5 boss có tên riêng; ID không trùng. |
| Tương thích nâng cấp | Tất cả ID trong `compatible` trỏ tới vũ khí có thật; Pistol dùng 0 năng lượng; mọi icon/sprite/SFX được tham chiếu tồn tại. |
| Đường đi và vật cản | 20 layouts (15 phòng + 5 arena) × 2 bán kính 11/15 px = 40 trường hợp; mọi ô sàn trống trên lưới 8 px kết nối với điểm gần spawn `(130,350)`; đi được tới `(1152,352)`. |
| Lane cửa | Kiểm tra x = 114/120/130/1150 trên đoạn y = 200..500; không có vật cản lấn lane khi đã nới theo radius. |
| SVG | 61 SVG đọc được bằng XML parser; player có 7 biến thể trạng thái, 10 enemy sprite, 5 boss sprite; đầy đủ sprite/icon 12 vũ khí. |
| Nhạc | 15 WAV mono PCM16 22.050 Hz; số frame đúng 16 beat theo BPM; các bản phối có SHA-256 PCM khác nhau; peak ≤ 0,86; mẫu đầu/cuối bằng 0; không có file im lặng. |
| SFX | 26 file, gồm đủ 12 vũ khí và các sự kiện bắt buộc; thời lượng ngắn dưới 2 giây. |
| Font | Đọc trực tiếp bảng cmap của hai TTF: đủ ký tự trong JSON và toàn bộ nguyên âm tiếng Việt có dấu, Đ/đ, chữ hoa/thường; OFL hiện diện. |
| Manifest | 41 mục âm thanh trùng frame count/sample rate của 41 WAV. |

Dung lượng tài sản nguồn sau tạo: 106 file, 7.398.047 byte (khoảng 7,06 MiB),
bao gồm WAV, SVG, font, giấy phép và manifest. Không bao gồm cache nhập asset
của Godot.

| Màn | BPM | Frame mỗi biến thể | Thời lượng thực |
| --- | ---: | ---: | ---: |
| Echo Terminal | 90 | 235.200 | 10,666667 s |
| Bass Foundry | 100 | 211.680 | 9,600000 s |
| Luminous Grove | 110 | 192.436 | 8,727256 s |
| Prism Spire | 120 | 176.400 | 8,000000 s |
| Silent Core | 128 | 165.375 | 7,500000 s |

Sai số tại BPM 110 là dưới nửa sample do số mẫu nguyên; ba biến thể cùng màn
có độ dài bằng nhau. Cấu trúc loop có giới hạn fade 3 ms tại hai mép để tránh
click; kiểm tra tĩnh không thay thế nghe chuyển lớp qua thiết bị âm thanh.

Chưa kiểm chứng bằng bộ test này: graph phòng theo seed do Run controller
sinh, va chạm/đòn đánh trong Godot, boss hoàn thành được bằng tay, 25–40 phút
một lượt, cảm giác nhạc khi crossfade, đa chạm trên Android, độ trễ nhạc thực
tế và hiệu năng thiết bị. Các phần đó cần được ghi nhận riêng trong báo cáo
runtime của dự án.
