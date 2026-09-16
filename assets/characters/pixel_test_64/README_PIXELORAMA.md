# Pixel test assets — 64x64

Các file trong thư mục này được làm để mở trực tiếp trong Pixelorama.

## Quy ước

- Mỗi ô animation: `64x64 px`.
- Sprite sheet chạy ngang, không có khoảng cách giữa các ô.
- Nền trong suốt; đã dùng nearest-neighbor và alpha cứng để tránh viền mờ.
- Nhân vật chính: ECHO RUNNER. Enemy mẫu: NEON DRONE.

## File

| File | Nội dung | Số frame | FPS gợi ý | Lặp |
|---|---|---:|---:|---|
| `echo_runner_model_64.png` | Model đứng yên | 1 | - | - |
| `echo_runner_idle_4x64.png` | Idle bob nhẹ | 4 | 8 | Có |
| `echo_runner_run_6x64.png` | Run test | 6 | 12 | Có |
| `echo_runner_shoot_4x64.png` | Bắn + muzzle flash | 4 | 12 | Không |
| `echo_runner_dash_4x64.png` | Dash + speed streak | 4 | 16 | Không |
| `echo_runner_hurt_3x64.png` | Hurt flash | 3 | 12 | Không |
| `echo_runner_death_6x64.png` | Fade/disappear test | 6 | 10 | Không |
| `neon_drone_model_64.png` | Model drone | 1 | - | - |
| `neon_drone_idle_4x64.png` | Drone hover | 4 | 8 | Có |
| `neon_drone_hit_3x64.png` | Drone hit flash | 3 | 12 | Không |

## Mở trong Pixelorama

1. `File > Open` và chọn một sheet.
2. Ở Import Options chọn `Spritesheet`.
3. Đặt `Frame width = 64`, `Frame height = 64`; chọn số cột đúng theo tên file.
4. Đặt FPS theo bảng trên rồi chạy preview animation.
5. Nếu muốn vẽ tiếp, lưu bản làm việc thành `.pxo`; giữ PNG gốc làm bản export.

Đây là bộ test chuyển động/nhịp animation. Các frame được dựng từ model master và thêm chuyển động nhỏ để bạn kiểm tra pipeline import trước khi polish từng pixel thủ công.
