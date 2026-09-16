# Echo Runner — bộ pixel 32×32

Đây là bộ sprite thử nghiệm riêng cho Pixelorama. Mỗi frame cuối là PNG RGBA
đúng **32×32 pixel**, nền trong suốt, không anti-alias và có cùng mốc chân để
ghép animation không bị rung. Bộ này đã được nối vào phần hiển thị của
`EchoPlayer`; các SVG cũ vẫn được giữ làm fallback nếu thiếu spritesheet.

## Có gì trong thư mục

| Asset | Frame | FPS gợi ý | Lặp | Mục đích |
| --- | ---: | ---: | :---: | --- |
| `echo_runner_model_32.png` | 1 | — | — | Model đứng yên để chỉnh pixel |
| `echo_runner_idle_4x32.png` | 4 | 6 | Có | Thở/nhấp visor rất nhẹ |
| `echo_runner_run_6x32.png` | 6 | 10 | Có | Chạy, chân và tay đổi nhịp |
| `echo_runner_attack_4x32.png` | 4 | 12 | Không | Nâng súng và lóe nòng |
| `echo_runner_dash_4x32.png` | 4 | 16 | Không | Dash sang phải, có vệt cyan |
| `echo_runner_hurt_3x32.png` | 3 | 10 | Không | Nhấp màu đỏ khi nhận sát thương |
| `echo_runner_death_6x32.png` | 6 | 8 | Không | Ngã rồi tan thành các hạt sáng |

Mỗi spritesheet nằm trên một hàng ngang: `N×32 × 32`. Các file rời có dạng
`echo_runner_<animation>_<index>.png`; dùng chúng nếu muốn kéo từng frame vào
Pixelorama và sửa thủ công.

## Mở và test trong Pixelorama

1. Mở một file `*_Nx32.png`, ví dụ `echo_runner_run_6x32.png`.
2. Dùng chức năng import/slice spritesheet với kích thước ô **32×32**; đặt số
   cột bằng số frame trong bảng trên và số hàng là **1**.
3. Mở Animation workspace, giữ thứ tự từ trái sang phải, đặt FPS theo bảng.
4. Đặt zoom 800% hoặc 1600% và tắt smoothing/anti-alias. Khi xuất lại, giữ
   PNG RGBA và không đổi kích thước canvas.

Nếu Pixelorama của bạn không có thao tác slice trực tiếp, hãy mở các file frame
rời rồi copy từng frame vào một animation mới. Tên file đã đánh số để thứ tự
không bị nhầm.

## Gắn thử vào Godot

Với `AnimatedSprite2D`, tạo `SpriteFrames`, chọn **Add frames from a Sprite
Sheet**, chọn đúng sheet rồi đặt `H Frames` thành 4, 6, 4, 4, 3 hoặc 6 tùy
animation. Đặt `Speed Scale` theo FPS mong muốn. Ở node sprite, dùng texture
filter **Nearest** và scale nguyên như 4× hoặc 6× để giữ cạnh pixel sắc.

Mốc neo quy ước là `(15, 28)` trong canvas 32×32, gần giữa hai bàn chân. Khi
đổi model hoặc vẽ frame mới, nên giữ mốc này và giữ vùng va chạm gameplay riêng
khỏi phần súng/vệt hiệu ứng.

## Tạo lại bộ asset

Từ thư mục gốc project chạy:

```powershell
python .\tools\generate_pixel_character.py
```

Script chỉ dùng thư viện chuẩn Python để vẽ pixel nguyên bản và ghi PNG. Bảng
thông số đầy đủ nằm trong `animation_manifest.json`. `echo_runner_preview_8x.png`
là ảnh xem nhanh phóng to bằng nearest-neighbor; không dùng ảnh preview làm
texture gameplay.

Thiết kế dùng silhouette chiến binh cyberpunk nhỏ, palette navy/cyan/tím và
đèn amber riêng cho NEON RESONANCE. Đây là asset gốc của project, chỉ lấy cảm
hứng ở mức độ dễ đọc của game top-down hành động; không sao chép sprite của
Soul Knight hay game thương mại nào.
