# Weapon pixel roster

Các file `weapon_<id>_32.png` là model súng/vũ khí cầm trên tay, mỗi file đúng
32×32 pixel, RGBA trong suốt và dùng palette neon chung với nhân vật.

Thứ tự trong `weapon_models_8x.png` là:

`pistol`, `smg`, `shotgun`, `rail`, `beam`, `disc`, `arc`, `wave`, `glitch`,
`orbit`, `blade`, `chord`.

Game ưu tiên các PNG này khi hiển thị vũ khí trong tay; SVG gốc vẫn còn làm
fallback. Icon UI nằm riêng trong `assets/icons/` và không bị thay đổi.

## Animation recoil

Thư mục `animations/` có `weapon_<id>_recoil_3x32.png` và ba frame rời tương
ứng. Animation chạy ở 18 FPS trong khoảng 0,18 giây khi bắn, gồm kéo súng lùi,
lóe nòng và trở về pose gốc. Đây là animation hình ảnh ngắn; loại đạn, sát
thương, projectile và âm thanh vẫn do hệ thống vũ khí hiện tại điều khiển.

Có thể sinh lại toàn bộ bằng:

```text
python tools/generate_pixel_combat_assets.py
python tools/generate_pixel_combat_animations.py
```
