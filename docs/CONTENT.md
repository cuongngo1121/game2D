# Nội dung NEON RESONANCE

Tài liệu này mô tả bộ dữ liệu và tài sản có sẵn trong dự án. Logic sử dụng dữ
liệu nằm trong các hệ thống gameplay; một định nghĩa có mặt trong JSON không
thay thế cho kiểm thử hành vi trong game.

## Dữ liệu có thể chỉnh sửa

Các file `data/*.json` là mảng JSON UTF-8, không có object bọc ngoài.

| File | Nội dung | Trường chính |
| --- | --- | --- |
| `data/weapons.json` | 12 vũ khí | `id`, `name`, `description`, `cooldown`, `damage`, `speed`, `range`, `energy`, `behavior`, `icon`, `sprite`, `sfx` |
| `data/upgrades.json` | 13 nâng cấp | `id`, `name`, `description`, `max_stacks`, `compatible` |
| `data/enemies.json` | 10 loại địch thường | `id`, `name`, `hp`, `speed`, `damage`, `reward`, `role`, `sprite` |
| `data/stages.json` | 5 khu vực | `id`, `name`, `subtitle`, `description`, `boss`, `boss_id`, `bpm`, `color`, `enemy_ids`, `room_templates`, `boss_obstacles`, `hazard`, `music_layers` |

`cooldown` tính bằng giây, tốc độ theo pixel/giây, `range` theo pixel trong
viewport thiết kế 1280×720. `energy` là mức tiêu hao mỗi lần hệ thống vũ khí
kích hoạt. `compatible: []` là nâng cấp dùng chung; mảng có ID chỉ rõ các vũ khí
có thể nhận tác dụng. Các đường dẫn tài sản dùng tiền tố `res://` của Godot.

ID vũ khí ổn định: `pistol`, `smg`, `shotgun`, `rail`, `beam`, `disc`, `arc`,
`wave`, `glitch`, `orbit`, `blade`, `chord`. `behavior` trùng ID. Pulse Pistol
và Resonance Blade có chi phí năng lượng bằng 0.

Khi vũ khí không đủ năng lượng, hệ thống dùng tạm Pulse Pistol để người chơi
tiếp tục tấn công. Có thể gọi lại Pistol bằng phím R hoặc lựa chọn trong menu
tạm dừng; không yêu cầu một ngón tay thứ ba khi chiến đấu trên cảm ứng.

Ba tổ hợp được thể hiện trong dữ liệu và mô tả lựa chọn:

1. Bass Shotgun + Đạn nảy: nhiều viên đạn đổi hướng khi gặp vật cản.
2. Arc Conductor + Dây dẫn: thêm mắt xích và tầm lan điện.
3. Dash ngân vang + Hợp âm bùng nổ: Perfect Dash tạo thêm cộng hưởng để dùng
   Pulse Burst, đồng thời Pulse Burst có vùng tác động lớn hơn.

## Năm khu vực

| ID | Khu vực / boss | Nhạc | Hình học và vai trò nội dung |
| --- | --- | --- | --- |
| 0 | ECHO TERMINAL / CONDUCTOR-01 | 90 BPM; trống + motif | Cột ga, ghế dài, đường đi rộng; drone áp sát và quạt đạn; đường ray điện. |
| 1 | BASS FOUNDRY / SUBWOOFER | 100 BPM; thêm bass | Khối máy chữ nhật, dãy máy lệch nhau; charger và turret; piston. |
| 2 | LUMINOUS GROVE / CHOIR WIDOW | 110 BPM; thêm pad, hợp âm | Cụm vườn rời tạo đường đi quanh; splitter và support; xung đánh dấu trễ. |
| 3 | PRISM SPIRE / REFRACTOR | 120 BPM; thêm lead, arpeggio | Cột kính mảnh và vùng trú; sniper và spiral; laser cảnh báo. |
| 4 | SILENT CORE / NULL MAESTRO | 128 BPM; hợp nhất các lớp và bè đối đáp | Vật cản lệch trục, đấu trường cuối mở; warden phối hợp vai trò cũ; ô sàn theo chuỗi. |

Mỗi khu vực có ba mẫu phòng chiến đấu và một cấu hình vật cản riêng cho boss.
Mỗi vật cản là `[x, y, width, height]` tuyệt đối, nằm trong
`Rect2(64,112,1152,480)`. Điểm xuất phát gần `(120,350)` và cửa ra gần
`(1150,350)` luôn được nối bằng đường đi. Trình tạo kiểm tra đường đi trên lưới
8 px sau khi nới vật cản thêm 15 px cho hitbox nhân vật; đây là kiểm tra hình
học tĩnh, không phải bằng chứng hoàn thành encounter trên điện thoại.

ID địch: `drone`, `fan`, `charger`, `turret`, `splitter`, `support`, `sniper`,
`spiral`, `warden`, `skirmisher`. `boss_id` dùng tên nội dung; hệ thống combat
có thể định danh runtime bằng `boss0` đến `boss4` theo chỉ số màn.

## Đồ họa

Nhân vật, địch thường và vũ khí cầm trên tay dùng lưới 32×32; boss 96×96. Player
dùng bộ pixel-art tại `assets/characters/pixel_32/`, địch thường dùng
`assets/sprites/pixel_32/enemies/`, còn vũ khí dùng
`assets/sprites/pixel_32/weapons/`. Boss, icon UI và môi trường vẫn có SVG hình
học góc cạnh với `shape-rendering="crispEdges"`. Runtime ưu tiên PNG pixel và
giữ SVG tương ứng làm fallback khi thiếu file; tất cả texture nên dùng filtering
Nearest trong game.

Phần SVG là bộ đồ họa procedural riêng cho mức playable đầu tiên: silhouette
và màu nguy hiểm được ưu tiên để đọc trận đấu. Player có thêm bộ pixel-art
32×32 có frame idle/run/attack/dash/hurt/death, phù hợp cho test và chỉnh sửa
trong Pixelorama.

Camera gameplay là `Camera2D` con của player: zoom mặc định 1,35×, bám theo
người chơi bằng smoothing nhẹ và giới hạn trong viewport logic 1280×720. Vì HUD
được dựng ngoài nhánh `world`, camera chỉ cuộn/phóng phần đấu trường; thanh máu,
nút cảm ứng và menu vẫn cố định trên màn hình như phong cách Soul Knight.

- Echo Runner: `assets/sprites/player.svg`, cùng các biến thể `player_idle`,
  `player_run_0`, `player_run_1`, `player_attack`, `player_dash`, `player_hurt`,
  `player_death` có đuôi `.svg`.
- Địch thường: `assets/sprites/pixel_32/enemies/enemy_<id>_32.png`, với SVG
  `assets/sprites/enemy_<id>.svg` làm fallback. Contact sheet và thứ tự model nằm
  trong `assets/sprites/pixel_32/enemies/README_PIXELORAMA.md`; spritesheet
  animation nằm trong thư mục `animations/`.
- Boss: `assets/sprites/boss_1.svg` đến `boss_5.svg`.
- Vũ khí: `assets/sprites/pixel_32/weapons/weapon_<id>_32.png` cho cầm trên tay,
  `assets/icons/weapon_<id>.svg` cho UI; SVG `assets/sprites/weapon_<id>.svg`
  là fallback. Recoil/muzzle animation nằm trong thư mục `animations/`.
- Môi trường: `assets/tiles/stage_<1..5>_floor.svg` và `_wall.svg`. Khu vực ECHO
  TERMINAL hiện có thêm nền thử nghiệm `assets/backgrounds/echo_terminal_backdrop.png`;
  đây là lớp trang trí được `RoomView` vẽ dưới vật cản, không thay thế dữ liệu
  collision trong `data/stages.json`.
- Nhặt đồ: `assets/icons/currency.svg`, `energy.svg`, `health.svg`.
- Icon ứng dụng: `assets/icon.svg` (128×128).
- Font: Noto Sans Regular/Bold có file OFL đi kèm tại `assets/fonts/`.

Biến thể hình ảnh có sẵn cho các trạng thái nhân vật, kẻ địch và recoil vũ khí;
hệ animation gameplay quyết định thời điểm hiển thị và thời lượng của từng trạng
thái. Enemy death được render như hiệu ứng tách khỏi danh sách collision trong
thời gian ngắn, nên việc hiển thị animation không trì hoãn phần thưởng hay wave.

Sảnh chính ghép năm lớp nhà máy `background/2 Background/1.png` đến `5.png`
(576×324, tỷ lệ 16:9) từ bộ asset Craftpix mới thêm. Bốn lớp tiền cảnh tự cuộn
ngang liên tục ở tốc độ parallax khác nhau; mỗi lớp dùng cặp ảnh lật gương để
nối vòng không giật. Nền được phủ tối nhẹ để giữ tiêu đề dễ đọc. Năm nút neon
được dựng riêng trong `scripts/ui/game_ui.gd`. Chỉ sảnh chính dùng các lớp này;
nền map và gameplay không thay đổi.

## Âm thanh thực

Có 15 bản phối nhạc WAV thật: 5 màn × `explore`, `combat`, `boss`.
Đường dẫn: `assets/audio/stage_<1..5>_<variant>.wav`.

Tất cả là PCM signed 16-bit, mono, 22.050 Hz. Một loop là 16 beat, tương đương
4 ô nhịp 4/4. Số frame là `round(16 × 60 / BPM × 22050)`. BPM 110 cần làm tròn
không quá nửa sample; thời lượng thực theo file là mốc cho loop. Cả ba biến thể
của cùng màn có số frame và vị trí motif bằng nhau, thuận tiện đổi lớp tại
beat/bar khi giữ cùng playhead. Không phát nối tiếp toàn bộ file khám phá rồi
mới bật file chiến đấu, vì cách đó sẽ thay đổi pha nhịp.

Khám phá vẫn có motif và kick nhẹ. Combat tăng trống, thêm hi-hat và bass
offbeat khi bè bass đã được mở. Boss thêm ostinato, hi-hat nhanh và fill snare.
Các màn 2–5 lần lượt thêm bass, pad, lead/arpeggio, rồi bè đối đáp. Âm đuôi của
các nốt được quấn về đầu buffer để bản phối tuần hoàn. Fade bảo vệ 3 ms tại
mép WAV đưa mẫu đầu/cuối về 0 để tránh click. Giới hạn peak 0,86 để giữ headroom.

Có 26 SFX, gồm đủ 12 file `sfx_weapon_<id>.wav`, `sfx_shoot`, `sfx_hit`,
`sfx_dash`, `sfx_perfect`, `sfx_hurt`, `sfx_pickup`, `sfx_door`, `sfx_buy`,
`sfx_boss`, `sfx_pulse`, `sfx_shield_break`, `sfx_shield_regen`, `sfx_victory`,
`sfx_ui`. Các hiệu ứng ngắn, có attack/release để giảm click; game cần giới hạn
voice đồng thời và đặt âm lượng SFX thấp hơn nhịp chính.

Thông số chính xác từng file, frame count, peak, BPM, số beat, sai số làm tròn
loop có trong `assets/audio/manifest.json`.

## Dựng lại

Tại thư mục dự án, chạy `python tools/generate_assets.py` bằng Python 3.10+.
Chỉ dùng standard library; không cần pip, mạng, synthesizer bên ngoài hoặc
dịch vụ tạo ảnh. Font đã được vendored và không bị trình tạo thay đổi.

Lệnh này ghi lại JSON dữ liệu, toàn bộ SVG gốc và WAV từ định nghĩa trong
script. Nếu đã cân bằng trực tiếp trong JSON, hãy giữ thay đổi đó hoặc cập nhật
định nghĩa nguồn trong script trước khi sinh lại. Seed nhạc/SFX được cố định;
kết quả trên cùng Python/platform có thể đối chiếu bằng hash.

## Giới hạn kiểm chứng

Trình tạo kiểm tra số lượng nội dung và đường đi tĩnh, nhưng không xác nhận
thời lượng lượt chơi 25–40 phút, độ công bằng của tổ hợp pattern, chất lượng
loa điện thoại, độ trễ Bluetooth hoặc 60 FPS trên Android. Các điều đó cần
playtest/runtime theo hướng dẫn kiểm thử của dự án. Không suy ra kiểm chứng
gameplay chỉ từ số lượng file asset.
