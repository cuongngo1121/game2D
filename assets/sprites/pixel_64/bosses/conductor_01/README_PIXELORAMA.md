# CONDUCTOR-01 — boss 64×64

Đây là bộ sprite pixel v2 của CONDUCTOR-01, boss đầu tiên ở ECHO TERMINAL. Model
là một sonic maestro lơ lửng với lõi sóng tím, loa tròn bên trái, loa kèn góc
bên phải, gậy chỉ huy và hai cặp tay âm thoa. Mỗi frame có đúng 64×64 pixel RGBA
nền trong suốt; runtime scale lên 120 world pixels với nearest filtering, nên
vẫn sắc nét trên màn hình mà không nội suy ảnh concept.

| Animation | Frame | FPS | Lặp | Khi chạy |
| --- | ---: | ---: | :---: | --- |
| `idle` | 4 | 6 | Có | Boss lơ lửng/chờ giữa nhịp. |
| `move` | 6 | 10 | Có | Boss dịch chuyển theo quỹ đạo trong arena. |
| `attack` | 4 | 12 | Không | Boss phát volley/rail warning theo beat. |
| `hurt` | 3 | 10 | Không | Giật lùi/lõi đảo sáng → flash va chạm → lõi tím hồi phục; luôn đọc được ngay từ phát trúng đầu tiên. |
| `death` | 6 | 8 | Không | Boss tan rã trong 0,75 giây trước reward UI. |

Các file `*_0.png`, `*_1.png`… là frame rời, thuận tiện mở trong Pixelorama.
File `*_Nx64.png` là spritesheet nằm ngang mà `EnemySystem` nạp trực tiếp.

Nguồn thiết kế tham khảo: `assets/concepts/bosses/conductor_01_reference_generated_v2.png`.
Không scale trực tiếp ảnh tham khảo vào game. Asset runtime được tạo bằng các
primitive pixel nguyên với lệnh:

```text
python tools/generate_conductor_01_64.py
```
