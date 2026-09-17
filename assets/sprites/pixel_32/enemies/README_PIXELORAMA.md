# Enemy pixel roster

Các file `enemy_<id>_32.png` là sprite kẻ địch thường của NEON RESONANCE.
Mỗi file có đúng 32×32 pixel, RGBA trong suốt và được vẽ bằng palette cố định
để mở trực tiếp trong Pixelorama.

Thứ tự trong `enemy_models_8x.png` là:

`drone`, `fan`, `charger`, `turret`, `splitter`, `support`, `sniper`, `spiral`,
`warden`, `skirmisher`.

Contact sheet chỉ là bản xem nhanh phóng 8×; khi chỉnh sửa gameplay hãy sửa file
32×32 tương ứng. Có thể sinh lại toàn bộ bằng:

```text
python tools/generate_pixel_combat_assets.py
```

## Animation

Thư mục `animations/` có spritesheet và frame rời cho từng loại địch:

| Animation | Frame | FPS | Lặp | Khi chạy trong game |
| --- | ---: | ---: | :---: | --- |
| `idle` | 4 | 6 | Có | Địch đứng/đang chờ |
| `move` | 6 | 10 | Có | Địch đang di chuyển |
| `attack` | 4 | 12 | Không | Địch vừa phát cảnh báo/tấn công |
| `hurt` | 3 | 10 | Không | Địch nhận sát thương |
| `death` | 6 | 8 | Không | Hiệu ứng tan rã sau khi bị hạ |

Tên sheet có dạng `enemy_<id>_<animation>_<frame>x32.png`; file cùng tên có hậu
tố `_0.png`, `_1.png`… là frame rời để copy vào Animation workspace. Runtime
phát `idle/move/attack/hurt` trên unit sống. Khi unit chết, nó bị xóa khỏi danh
sách va chạm ngay lập tức để không ảnh hưởng reward hoặc gameplay, sau đó giữ
frame chết riêng khoảng 0,75 giây để người chơi nhìn thấy hiệu ứng.

Các hiệu ứng combat bổ sung được vẽ procedural trong runtime, không thay thế
các frame pixel gốc:

- `spawn`: vòng mở cổng, tia quét và các mảnh năng lượng chạy trong thời gian
  spawn grace; unit chưa thể va chạm/tấn công trong khoảng này.
- `fire`: recoil/muzzle flash được phát đúng lúc hazard tạo projectile, vì vậy
  không còn lệch với attack telegraph hai beat trước đó.
- `splitter`: marker hiển thị quả bom trung tâm và các nhánh dự kiến; projectile
  chính dùng hình bom có fuse, sau đó hai mảnh tách dùng hình shard riêng.

Sinh lại cả model tĩnh lẫn animation bằng:

```text
python tools/generate_pixel_combat_assets.py
python tools/generate_pixel_combat_animations.py
```

Boss vẫn giữ sprite SVG 96×96 hiện có để phân biệt kích thước và silhouette của
trận boss.
