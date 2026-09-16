# Nguồn tài sản và giấy phép

## Đồ họa và âm thanh riêng của NEON RESONANCE

Các file trong `assets/sprites/`, `assets/icons/`, `assets/tiles/`, `assets/icon.svg`
và toàn bộ WAV trong `assets/audio/` được tạo riêng cho dự án bằng
`tools/generate_assets.py`. Chúng không sử dụng ảnh, sprite, bản nhạc hoặc sample
âm thanh lấy từ game khác. Các tên nhân vật, bố cục pixel và giai điệu được viết
cho bối cảnh NOCTIS trong yêu cầu dự án.

Tài sản dạng SVG gồm hình chữ nhật và đường đa giác trên lưới pixel; không cần
dịch vụ tạo ảnh để dựng lại. Âm thanh được tổng hợp trực tiếp từ dao động sine,
các họa âm và nguồn nhiễu có seed cố định; không cần thư viện nhạc hoặc plugin
tổng hợp thương mại. `assets/audio/manifest.json` ghi thông số từng bản xuất.

Bộ thử nghiệm pixel-art tùy chọn trong `assets/characters/pixel_32/` được tạo
riêng cho project bằng `tools/generate_pixel_character.py`. PNG cuối cùng được
vẽ bằng các primitive pixel nguyên số, không chứa sprite bên thứ ba và không
sao chép tài sản của Soul Knight. Một concept study tạo bằng công cụ AI chỉ
được dùng để tham khảo silhouette/palette; không được phân phối như một asset
gameplay riêng và không thay đổi nguồn gốc gốc của các PNG trong thư mục này.

Bộ sprite pixel combat và animation trong `assets/sprites/pixel_32/enemies/` và
`assets/sprites/pixel_32/weapons/` được tạo riêng bằng
`tools/generate_pixel_combat_assets.py` và
`tools/generate_pixel_combat_animations.py`. Mỗi frame gameplay là ảnh RGBA
32×32, được rasterize bằng primitive nguyên số từ palette của project. Concept
sheet AI của roster địch và vũ khí chỉ đóng vai trò tham khảo hướng silhouette;
các file cuối cùng trong project không phải ảnh copy từ concept sheet hay từ
game khác. SVG cũ được giữ lại làm fallback kỹ thuật và không thay đổi quyền sở
hữu của các asset pixel mới.

## Nền menu do người dùng cung cấp

`assets/backgrounds/menu_neon_space_dark.png` là bản chỉnh tối từ ảnh nền do
người dùng cung cấp trong cuộc trò chuyện, được giữ lại làm nền menu cũ/nguồn
tham chiếu. Ảnh tham chiếu không kèm thông tin giấy phép trong dự án; trước khi
phát hành game, cần xác minh quyền sử dụng thương mại/phân phối của ảnh gốc.
Bản chỉnh tối không thay đổi quyền sở hữu hoặc điều kiện của ảnh nguồn.

`assets/backgrounds/menu_resonance_console_v1.png` là nền menu runtime hiện
tại, được tạo bằng ImageGen ngày 2026-09-13 theo brief NEON RESONANCE. Asset có
nền sao tối, đường cộng hưởng tím/cyan, sàn lưới và năm khung hành động trống;
text tiếng Việt, vùng focus/hover và hitbox hình chữ nhật vẫn do
`scripts/ui/game_ui.gd` dựng ở runtime. Ảnh không chứa chữ, logo hay tài sản
lấy từ game khác. Trước khi phát hành thương mại, cần kiểm tra lại điều khoản
công cụ tạo ảnh và quyết định có giữ, vẽ lại hoặc thay thế asset này.

`assets/backgrounds/armory_loadout_matrix_v1.png` là nền kho vũ khí runtime,
được tạo bằng ImageGen ngày 2026-09-13 theo brief NEON RESONANCE. Asset có
mười hai khoang module trống, khung điều khiển trở lại và trang trí command-deck
cyan/magenta; nó không chứa chữ, tên súng, icon hay trạng thái trang bị cố định.
`scripts/ui/game_ui.gd` dựng dữ liệu và hitbox runtime, còn
`scripts/ui/weapon_loadout_state.gd` vẽ riêng trạng thái chọn/trang bị/mở khóa.
Ảnh không chứa logo hoặc tài sản lấy từ game khác. Trước khi phát hành thương
mại, cần kiểm tra lại điều khoản công cụ tạo ảnh và quyết định có giữ, vẽ lại
hoặc thay thế asset này.

`assets/backgrounds/settings_calibration_console_v1.png` là pass nền Cài đặt đầu
tiên, được tạo bằng ImageGen ngày 2026-09-14 theo brief NEON RESONANCE. Nó được
giữ để truy xuất lịch sử và không còn được runtime nạp: các khoang slider, ray,
tick, housing công tắc và khung hành động đã bake trong ảnh có thể lệch với chữ,
giá trị và vùng chạm Godot động.

`assets/backgrounds/settings_calibration_console_v2.png` là nền Cài đặt runtime
hiện tại, được tạo bằng ImageGen ngày 2026-09-14 bằng cách chỉnh v1. Asset chỉ
cung cấp khung máy cyan/tím chi tiết ở ngoài, hai viền panel lớn và nền tối sạch
bên trong; nó không chứa text, nameplate, hàng cài đặt, slider, tick, value chip,
công tắc, nút hành động hoặc trạng thái cố định. `scripts/ui/game_ui.gd` dựng
từng hộp cài đặt đơn giản cùng label tiếng Việt, giá trị động, HSlider, Button
toggle, hitbox và nút lưu ở runtime, để vị trí hiển thị và vùng chạm dùng cùng
một geometry source. Ảnh không chứa logo hoặc tài sản lấy từ game khác. Trước khi
phát hành thương mại, cần kiểm tra lại điều khoản công cụ tạo ảnh và quyết định
có giữ, vẽ lại hoặc thay thế asset này.

## Concept nền ECHO TERMINAL tạo bằng AI

`assets/backgrounds/echo_terminal_backdrop.png` là bản nền thử nghiệm cho khu vực
ECHO TERMINAL, được tạo bằng công cụ ImageGen trong phiên phát triển ngày
2026-09-07 theo bảng màu LED tím/xanh và các motif waveform của dự án. File này
đã được đưa vào runtime làm nền trang trí; collision, ray và đường đi vẫn do mã
gameplay quyết định. Đây là asset do AI hỗ trợ tạo, không chứa logo, chữ hoặc tài
sản lấy từ game khác. Trước khi phát hành thương mại, cần kiểm tra lại điều khoản
công cụ tạo ảnh và quyết định có giữ, vẽ lại hoặc thay thế asset này hay không.

`assets/backgrounds/bass_foundry_route_concept.png` là concept route cho khu vực
BASS FOUNDRY / Xưởng Hạ Âm, được tạo bằng ImageGen ngày 2026-09-07 từ sơ đồ
luồng phòng do người dùng cung cấp. Ảnh mô tả thứ tự phòng chiến đấu, nhánh hỗ
trợ và buồng boss bằng motif băng tải, piston và loa trầm; không chứa chữ, logo
hay tài sản lấy từ game khác. Đây là tài liệu định hướng mỹ thuật, không thay thế
geometry, collision, hoặc lộ trình gameplay của khu vực 2.

`assets/backgrounds/bass_foundry_route_background_concept_v5_amber_foundry.png`
là route amber gốc, được tạo bằng ImageGen ngày 2026-09-07 từ cùng sơ đồ luồng
phòng do người dùng cung cấp, dùng motif tường cơ khí, sàn kim loại và LED
cam/vàng, không chứa chữ, logo hoặc tài sản lấy từ game khác.

`assets/backgrounds/bass_foundry_route_background_concept_v5_amber_foundry_tiled_restored_hd.png`
là texture runtime HD 5120 × 3840. Nó được tạo trong phiên phát triển 2026-09-08
bằng cách phục hồi riêng từng section phòng/hành lang từ route amber gốc, rồi
blend trở lại đúng bố cục của ảnh gốc. Collision không lấy từ pixel ảnh: nó dùng
polygon do người phát triển vẽ trong `data/map_boundaries_lv2.json`, theo cùng
tọa độ gốc 1448 × 1086 của map. Trước khi phát hành thương mại, cần kiểm tra lại
điều khoản công cụ tạo ảnh và quyết định có giữ, vẽ lại hoặc thay thế asset này.

## Concept route cho ba khu vực cuối tạo bằng AI

Các file sau là concept map 1448 × 1086 được tạo bằng ImageGen trong phiên phát
triển 2026-09-08, dựa trên sơ đồ luồng phòng do người dùng cung cấp:

- `assets/backgrounds/luminous_grove_route_background_concept_v1.png`: VƯỜN DỮ LIỆU, tường biometal xanh ngọc/lục và mạch dữ liệu dạng lá tích hợp trong sàn.
- `assets/backgrounds/prism_spire_route_background_concept_v1.png`: THÁP LĂNG KÍNH, sàn lăng kính phẳng tím/cyan và tường kim loại quang phổ.
- `assets/backgrounds/silent_core_route_background_concept_v1.png`: LÕI TĨNH LẶNG, tường obsidian tối và các đường cộng hưởng hồng-trắng tiết chế.

`assets/backgrounds/prism_spire_route_background_concept_v2_orthogonal.png`
là bản chỉnh của concept THÁP LĂNG KÍNH tạo bằng ImageGen ngày 2026-09-08,
dùng bản v1 làm ảnh đích và ảnh route xanh do người dùng cung cấp làm tham chiếu
góc nhìn. V2 giữ nguyên lộ trình phòng/hành lang, nhưng đổi khung tường, mép
hành lang và các mảng sàn thành mặt bằng chính diện với cạnh ngang/dọc, góc
vuông rõ ràng; bỏ hoa văn sàn chéo hình thoi để thuận tiện đối chiếu khi vẽ
polygon ranh giới di chuyển. Đây là asset tham chiếu mỹ thuật, chưa thay thế
texture runtime HD hay dữ liệu collision trong `data/map_boundaries_lv4.json`.

`assets/backgrounds/prism_spire_route_background_concept_v3_boundary_clearance.png`
là bản tham chiếu kế tiếp tạo bằng ImageGen ngày 2026-09-08 từ v2 orthogonal.
Nó giữ nguyên nền panel kim loại tím/xanh, tường, LED, void, cửa và toàn bộ
silhouette room/corridor; chỉ dọn chi tiết sàn phụ như ống, lỗ kỹ thuật, cable
và greeble trong một dải một-panel sát mép trong tường/góc. Mục đích là làm rõ
vùng đặt vertex khi trace polygon ranh giới di chuyển, không phải thay đổi
collision, texture runtime HD hay ngụ ý rằng dải đó là một vật cản mới.

`assets/backgrounds/luminous_grove_route_background_user_six_stitched_hd_v18.png`
là texture runtime HD 5120 × 3840 trước đó của LUMINOUS GROVE. Nó được stitch
trực tiếp từ sáu ảnh người dùng duyệt trong
`assets/backgrounds/luminous_grove_sections_v15_user_six/`: Combat 1, Combat 2,
Combat 3, Hỗ trợ, Combat 4 và Boss. `tools/compose_luminous_grove_v10_hd.ps1`
đặt sáu source vào toạ độ route native 1448 × 1086 rồi bake thành một atlas duy
nhất. Trong mode `-DirectSectionStitch`, pixel ngoài void dùng source với alpha
1.0 và chỉ feather 12 px tại mép crop; ở nơi source rectangle chồng nhau,
composer chọn source có floor polygon gần nhất (hoà bằng thứ tự section) để
không tạo mảng chữ nhật mềm. Geometry plate chỉ còn là nền an toàn tại void/gap.
Tại thời điểm tạo, gameplay và Boundary Editor cùng nạp v18; không có tile overlay khi chơi và
collision vẫn lấy từ polygon, không lấy từ pixel ảnh.

Các bản `..._tiled_restored_hd_v2.png`, `..._seamless_hd_v3.png` và
`..._blended_section_hd_v4.png` vẫn được giữ lại để truy xuất lịch sử, nhưng
không còn được runtime hoặc Boundary Editor sử dụng. Collision không lấy từ pixel ảnh:
nó dùng polygon trong `data/map_boundaries_lv3.json`, với cùng toạ độ gốc
1448 × 1086, nên thay texture không làm thay đổi đường đi.

`assets/backgrounds/luminous_grove_route_background_user_final_fixed_hd_v29.png`
là texture runtime HD 5120 × 3840 hiện tại của LUMINOUS GROVE. Đây là PNG map
hoàn chỉnh đã được người dùng sửa và cung cấp ngày 2026-09-09. File được copy
nguyên byte vào project (không resize, crop, ghép section, vá cục bộ hay phủ
tile) để giữ nguyên chất lượng và các junction mà người dùng đã duyệt. Cả
`RoomView`, Boundary Editor và camera probe cùng preload v29. Collision vẫn do
polygon trong `data/map_boundaries_lv3.json` quyết định, không được sinh từ
pixel asset.

`assets/backgrounds/prism_spire_route_background_concept_v1_tiled_restored_hd_v1.png`
là atlas HD cũ của PRISM SPIRE, được giữ lại để truy xuất lịch sử và không còn
được gameplay, Boundary Editor hoặc camera probe nạp.

`assets/backgrounds/prism_spire_route_background_user_geometry_v2.png` là
geometry plate 1448 × 1086 do người dùng cung cấp ngày 2026-09-09 cho PRISM
SPIRE. Nó quyết định đầy đủ silhouette, phòng, hành lang, door, bề dày wall và
void. `tools/compose_prism_spire_safe_hd_v2.ps1` upscale geometry plate theo
một transform duy nhất lên 5120 × 3840, rồi chỉ blend detail của sáu section
(Combat 1, Combat 2, Hỗ trợ, Combat 3, Combat 4, Boss) trong region lấy từ
`data/map_boundaries_lv4.json`. Sáu junction được keepout để geometry plate
luôn phục hồi wall/LED/corridor liên tục; black void trong detail source được
color-key thành trong suốt trước khi blend.

`assets/backgrounds/prism_spire_route_background_concept_v1_refined_safe_junctions_hd_v2.png`
là atlas HD v2 trước đó của PRISM SPIRE, được giữ lại để so sánh lịch sử và
không còn được runtime nạp.

`assets/backgrounds/prism_spire_route_background_concept_v1_refined_room_detail_safe_junctions_hd_v3.png`
là atlas HD v3 trước đó của PRISM SPIRE, được giữ lại để truy xuất lịch sử và
không còn được runtime nạp.

`assets/backgrounds/prism_spire_route_background_concept_v1_refined_room_detail_safe_junctions_hd_v4.png`
là texture runtime HD hiện tại của PRISM SPIRE. Nó sử dụng trọn vẹn sáu source
detail đã tạo cho Combat 1, Combat 2, Hỗ trợ, Combat 3, Combat 4 và Boss với
opacity 0.88, vì vậy material detail của full map bám sát các ảnh phòng HD thay
vì chỉ là một lớp nhấn nhẹ. Junction keepout chỉ còn che đúng door/corridor
handoff, thay vì tạo một mảng hình chữ nhật lớn giữa bề mặt phòng. Vẫn không có
tile overlay runtime: void, silhouette ngoài map và geometry cửa nối luôn lấy
từ geometry plate. `RoomView`, Boundary Editor và camera probe cùng preload v4.
Collision vẫn là polygon của `data/map_boundaries_lv4.json` trong art space
1448 × 1086 và không được suy ra từ pixel texture.

`assets/backgrounds/silent_core_route_background_concept_v1_material_detail_v1.png`
là pass vật liệu liên tục 1448 × 1086 được tạo bằng ImageGen ngày 2026-09-09
từ concept SILENT CORE gốc. Nó chỉ bổ sung panel obsidian/gunmetal, rãnh kỹ
thuật và điểm sáng hồng-trắng tiết chế; không là nguồn collision hay route
topology.

`assets/backgrounds/silent_core_route_background_concept_v1_refined_safe_junctions_hd_v1.png`
là atlas HD v1 trước đó của SILENT CORE, được giữ lại để truy xuất lịch sử và
không còn được runtime nạp. Nó được tạo bởi
`tools/compose_silent_core_hd.ps1` bằng một transform 4:3 duy nhất: geometry
plate gốc giữ toàn bộ void, wall, doorway, room/corridor và junction, rồi pass
vật liệu được blend liên tục chỉ ở pixel map không phải void. Không có crop
hình chữ nhật hay tile overlay runtime.

`assets/backgrounds/silent_core_route_background_concept_v1_refined_room_detail_safe_junctions_hd_v2.png`
là texture runtime HD hiện tại của SILENT CORE. Nó dùng sáu source detail HD
riêng cho Combat 1, Combat 2, Combat 3, Combat 4, Hỗ trợ và Boss, được tạo từ
các crop của geometry plate bằng ImageGen ngày 2026-09-09. Script
`tools/compose_silent_core_room_detail_hd.ps1` blend các source với opacity
0.88 chỉ trong polygon phòng tương ứng. Junction keepout hẹp, void, silhouette
ngoài map và geometry cửa nối vẫn lấy từ geometry plate, nên atlas không có
tile overlay runtime và không đổi topology. `RoomView`, Map Boundary Editor và
camera probe cùng preload atlas v2. Collision vẫn là sáu polygon trong
`data/map_boundaries_lv5.json`, ở native art space 1448 × 1086; Support nối
với Combat 4 theo route nguồn, không được suy ra từ pixel texture.

## Hòm hỗ trợ theo khu vực

Năm prop nền trong suốt dưới đây được tạo bằng ImageGen ngày 2026-09-09 cho
phòng Hỗ trợ của từng khu vực. Chúng là minh hoạ runtime trong `RoomView`; vị
trí tương tác, phạm vi kích hoạt và va chạm vẫn do mã gameplay hiện có quyết
định, không được lấy từ pixel của hòm.

- `assets/props/support_chests/echo_terminal_support_chest_v1.png`: hòm kim
  loại navy, cyan và tím theo nhịp sóng của ECHO TERMINAL.
- `assets/props/support_chests/bass_foundry_support_chest_v1.png`: cache cơ
  khí copper/amber, gợi các panel và lưới âm trầm của BASS FOUNDRY.
- `assets/props/support_chests/luminous_grove_support_chest_v1.png`: hòm
  biometal teal với dây mạch dây leo và chốt lõi cyan của LUMINOUS GROVE.
- `assets/props/support_chests/prism_spire_support_chest_v1.png`: hòm cobalt
  với panel lăng kính cyan/tím và khoá hình kim cương của PRISM SPIRE.
- `assets/props/support_chests/silent_core_support_chest_v1.png`: hòm
  containment obsidian/gunmetal với khoá cộng hưởng đồng tâm, cyan/trắng và
  điểm nhấn hồng tiết chế của SILENT CORE.

## CONDUCTOR-01 — concept và sprite 64px

`assets/concepts/bosses/conductor_01_reference_v1.png` là concept minh hoạ
nền trong suốt ban đầu của CONDUCTOR-01, tạo bằng ImageGen ngày 2026-09-09.
Nó được giữ lại để truy xuất lịch sử, không được runtime nạp và không quyết định
hitbox.

`assets/concepts/bosses/conductor_01_reference_generated_v2.png` là concept
minh hoạ nền trong suốt thay thế, tạo bằng ImageGen ngày 2026-09-13. V2 thiết kế
lại CONDUCTOR-01 thành sonic maestro với lõi waveform tím, loa tròn, loa kèn,
gậy chỉ huy và tay âm thoa. Nó chỉ là nguồn định hướng hình dáng, không được
runtime nạp và không quyết định hitbox.

Các PNG trong `assets/sprites/pixel_64/bosses/conductor_01/` là sprite và
animation runtime 64×64 v2 được dựng lại bằng primitive pixel nguyên theo
concept v2 bằng `tools/generate_conductor_01_64.py`. Chúng không chứa chữ,
logo hay tài sản lấy từ game khác. Collision, HP, attack beat và route của boss
vẫn do `EnemySystem`/dữ liệu gameplay quyết định, không được suy ra từ pixel
art.

Các asset concept giữ bố cục phòng/hành lang của từng sơ đồ tương ứng, không chứa
chữ, logo hay tài sản lấy từ game khác. Trước khi phát hành thương mại, cần kiểm
tra lại điều khoản công cụ tạo ảnh và quyết định có giữ, vẽ lại hoặc thay thế
tất cả asset AI này.

Dự án chưa lựa chọn giấy phép phát hành công khai cho phần mã và tài sản tự tạo.
Tài liệu này ghi nguồn gốc tài sản, không tự áp đặt giấy phép phát hành cho toàn
bộ dự án. Người sở hữu dự án có thể chọn giấy phép phù hợp khi phát hành mã nguồn.

## Font Noto Sans

Các file sau là tài sản của bên thứ ba, được giữ nguyên:

- `assets/fonts/NotoSans-Regular.ttf`
- `assets/fonts/NotoSans-Bold.ttf`
- `assets/fonts/OFL.txt`: toàn văn SIL Open Font License 1.1, gồm thông tin bản quyền.

Nguồn chính thức:

- [NotoSans-Regular.ttf](https://github.com/notofonts/noto-fonts/blob/main/hinted/ttf/NotoSans/NotoSans-Regular.ttf)
- [NotoSans-Bold.ttf](https://github.com/notofonts/noto-fonts/blob/main/hinted/ttf/NotoSans/NotoSans-Bold.ttf)
- [Giấy phép tại kho Noto](https://github.com/notofonts/noto-fonts/blob/main/LICENSE)

Ngày tải: 2026-09-06. Font được phân phối cùng game để giao diện tiếng Việt dùng
đúng dấu mà không cần kết nối mạng. Khi đóng gói lại, giữ bản quyền và file OFL
cùng font; xem toàn văn OFL để biết điều kiện cụ thể. Không cần tải font khi
chạy game hoặc khi dựng lại asset riêng của dự án.

SHA-256 của các file đã đóng gói:

| File | SHA-256 |
| --- | --- |
| `NotoSans-Regular.ttf` | `b85c38ecea8a7cfb39c24e395a4007474fa5a4fc864f6ee33309eb4948d232d5` |
| `NotoSans-Bold.ttf` | `c976e4b1b99edc88775377fcc21692ca4bfa46b6d6ca6522bfda505b28ff9d6a` |
| `OFL.txt` | `0dab92d0544f7b233403f14b84a663bdbfa746982eda629e7f4f9ffe1b036feb` |
