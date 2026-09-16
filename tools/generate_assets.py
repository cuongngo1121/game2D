"""Rebuild NEON RESONANCE original SVGs, PCM loops, SFX, and editable content.

Python 3.10+, standard library only. Run from any working directory.
All artwork and audio are original procedural compositions made for this game.
Fonts are separate vendored SIL OFL assets; this script never downloads files.
"""
from __future__ import annotations

import array
import json
import math
from pathlib import Path
import random
import wave

ROOT = Path(__file__).resolve().parents[1]
RATE = 22050
TAU = math.tau
COLORS = ["#35E7FF", "#FFAB64", "#88FFC9", "#9B87FF", "#FF6A91"]

WEAPONS = [
    ("pistol", "Pulse Pistol", "Không tốn năng lượng. Tự dùng tạm khi súng khác cạn pin; gọi lại bằng R hoặc mục Pistol trong menu tạm dừng.", .30, 18, 630, 800, 0),
    ("smg", "Neon SMG", "Liên thanh nhanh, đạn nhẹ. Mạnh khi giữ được tầm bắn và theo mục tiêu.", .09, 7, 700, 690, 1),
    ("shotgun", "Bass Shotgun", "Bảy viên tỏa quạt; áp sát để gom sát thương. Kết hợp tốt với Đạn nảy.", .72, 12, 550, 420, 4),
    ("rail", "Rail Synth", "Đường đạn rất nhanh, xuyên nhiều mục tiêu thẳng hàng.", .90, 56, 1200, 1100, 6),
    ("beam", "Prism Beam", "Giữ bắn để duy trì tia đánh các mục tiêu trên đường thẳng, dừng tại vật cản; tiêu hao năng lượng liên tục.", .10, 9, 1500, 570, 1),
    ("disc", "Echo Disc", "Đĩa xuyên địch trên đường bay ra, quay về phía người chơi và có thể đánh lần nữa.", .65, 25, 470, 500, 4),
    ("arc", "Arc Conductor", "Phóng điện qua tối đa ba mục tiêu ở gần. Mỗi tầng Dây dẫn tăng thêm hai mục tiêu.", .55, 25, 900, 470, 5),
    ("wave", "Wave Cannon", "Sóng rộng chậm, xuyên qua nhiều địch; cần dự đoán đường di chuyển.", .88, 35, 320, 650, 6),
    ("glitch", "Glitch Launcher", "Đạn chậm nổ khi va chạm hoặc hết thời gian bay; gây sát thương trong một vùng.", .95, 48, 350, 430, 6),
    ("orbit", "Orbit Driver", "Thả ba vệ tinh quay quanh người chơi trong bốn giây; hữu ích khi đang né.", 1.30, 15, 240, 115, 7),
    ("blade", "Resonance Blade", "Chém vùng cự ly gần phía trước và phá đạn thường trong vùng. Không tốn năng lượng.", .38, 34, 0, 108, 0),
    ("chord", "Chord Caster", "Ba nốt đi theo các quỹ đạo lệch nhau, phủ đường tiến quân của địch.", .52, 16, 520, 700, 4),
]

UPGRADES = [
    ("speed", "Bước sóng nhanh", "Tăng 23 px/giây tốc độ di chuyển mỗi tầng; tốc độ ban đầu 205 px/giây.", 3, []),
    ("dash", "Tụ dash", "Giảm 0,23 giây hồi dash mỗi tầng, từ 1,65 giây; không thấp hơn 0,65 giây.", 3, []),
    ("shield", "Khiên hòa âm", "Tăng 20 khiên tối đa và nạp ngay phần khiên tăng thêm.", 4, []),
    ("shield_delay", "Mạch ổn định", "Giảm 0,7 giây chờ hồi khiên mỗi tầng, từ 4 giây; không thấp hơn 1,2 giây.", 3, []),
    ("energy", "Pin cộng hưởng", "Tăng 30 năng lượng tối đa mỗi tầng và nạp đầy pin ngay khi chọn.", 3, []),
    ("regen", "Thu hồi điện tích", "Tăng 3,5 năng lượng hồi mỗi giây cho mỗi tầng; tốc độ hồi ban đầu 5 mỗi giây.", 3, []),
    ("pierce", "Nốt xuyên", "Đạn xuyên thêm một mục tiêu mỗi tầng. Chỉ áp dụng cho vũ khí bắn đạn phù hợp.", 2, ["pistol", "smg", "shotgun", "rail", "disc", "wave", "chord"]),
    ("bounce", "Đạn nảy", "Đạn nảy thêm một lần khi chạm vật cản. Shotgun phủ góc phòng hiệu quả hơn.", 2, ["pistol", "smg", "shotgun", "rail", "chord"]),
    ("explosion", "Dư âm vỡ", "Hạ địch có 22% cơ hội mỗi tầng tạo một vụ nổ nhỏ gây sát thương địch ở gần.", 3, []),
    ("magnet", "Nam châm nốt", "Tăng 50 px bán kính hút vật phẩm mỗi tầng; bán kính ban đầu 65 px.", 3, []),
    ("perfect_wave", "Dash ngân vang", "Perfect Dash: mỗi tầng +4 cộng hưởng, gây 14 sát thương và đẩy 40 px trong vùng 100 px. Xóa đạn thường trong 70 px.", 2, []),
    ("pulse", "Hợp âm bùng nổ", "Pulse Burst thêm 30 sát thương và 32 px bán kính mỗi tầng; ban đầu 95 sát thương, 155 px.", 3, []),
    ("chain", "Dây dẫn", "Arc Conductor lan thêm hai mục tiêu mỗi tầng và tìm mục tiêu xa hơn.", 3, ["arc"]),
]

ENEMIES = [
    ("drone", "Drone săn âm", 42, 94, 9, 4, "Áp sát và bắn nốt đơn; buộc người chơi di chuyển."),
    ("fan", "Robot quạt âm", 56, 43, 10, 5, "Giữ khoảng cách, bắn quạt đạn có khe rộng."),
    ("charger", "Búa trầm", 79, 57, 14, 6, "Khóa hướng và báo trước rồi lao thẳng; có khoảng hồi."),
    ("turret", "Tháp hạ âm", 86, 0, 12, 7, "Đứng yên, phóng cung sóng, dùng cover để đổi vị trí."),
    ("splitter", "Hạt vọng", 65, 51, 11, 7, "Bắn đạn trễ tách nhánh sau khi đi một đoạn."),
    ("support", "Nụ hòa âm", 60, 35, 8, 8, "Hỗ trợ các địch ở gần, ưu tiên xử lý sớm."),
    ("sniper", "Lăng kính bắn tỉa", 58, 39, 17, 8, "Báo toàn bộ đường laser, khóa hướng trước khi bắn."),
    ("spiral", "Drone xoắn ốc", 82, 49, 11, 8, "Bắn chuỗi đạn xoay chậm; tìm khe rồi di chuyển cùng khe."),
    ("warden", "Kẻ giữ im lặng", 100, 40, 15, 10, "Đánh dấu vùng nguy hiểm tại vị trí đã khóa rồi phát xung."),
    ("skirmisher", "Bóng nhiễu", 69, 110, 12, 9, "Di chuyển ngang và bắn loạt định hướng, thay đổi góc giao tranh."),
]

STAGES = [
    {"name": "ECHO TERMINAL", "subtitle": "GA VỌNG ÂM", "description": "Ga tàu im tiếng. Tìm lại nhịp trống đầu tiên và mở đường ray đến xưởng loa.", "boss": "CONDUCTOR-01", "boss_id": "conductor", "bpm": 90, "enemy_ids": ["drone", "fan", "skirmisher"], "music_layers": ["drums", "motif"],
     "room_templates": [[[320,180,96,128],[672,400,160,64]], [[288,176,96,112],[576,448,288,64],[880,176,80,112]], [[352,160,64,160],[352,416,64,128],[736,272,160,80]]], "boss_obstacles": [[272,192,64,112],[272,432,64,112]], "hazard": "rail"},
    {"name": "BASS FOUNDRY", "subtitle": "XƯỞNG HẠ ÂM", "description": "Piston và màng loa khổng lồ. Thu hồi bè bass khỏi dây chuyền bị chiếm quyền.", "boss": "SUBWOOFER", "boss_id": "subwoofer", "bpm": 100, "enemy_ids": ["charger", "turret", "drone", "fan"], "music_layers": ["drums", "motif", "bass"],
     "room_templates": [[[304,208,208,64],[592,416,240,64],[944,176,64,112]], [[288,160,128,144],[576,400,128,144],[864,160,128,144]], [[288,432,160,80],[448,192,320,64],[864,368,96,160]]], "boss_obstacles": [[352,160,128,64],[352,480,128,64]], "hazard": "piston"},
    {"name": "LUMINOUS GROVE", "subtitle": "VƯỜN DỮ LIỆU", "description": "Cây quang học lưu giữ hợp âm. Dập các nụ loa nhiễu để khôi phục khu vườn.", "boss": "CHOIR WIDOW", "boss_id": "choir_widow", "bpm": 110, "enemy_ids": ["splitter", "support", "charger", "fan"], "music_layers": ["drums", "motif", "bass", "pad"],
     "room_templates": [[[288,192,96,96],[512,432,96,96],[752,224,128,96]], [[320,240,80,80],[544,160,96,96],[672,416,112,112],[928,208,64,96]], [[272,416,112,112],[480,192,112,112],[736,368,112,112],[960,192,64,96]]], "boss_obstacles": [[288,192,64,64],[288,464,64,64]], "hazard": "echo"},
    {"name": "PRISM SPIRE", "subtitle": "THÁP LĂNG KÍNH", "description": "Tín hiệu phản xạ qua các trụ kính. Đọc đường laser để giành lại giai điệu lead.", "boss": "REFRACTOR", "boss_id": "refractor", "bpm": 120, "enemy_ids": ["sniper", "spiral", "skirmisher", "support"], "music_layers": ["drums", "motif", "bass", "pad", "lead", "arp"],
     "room_templates": [[[352,160,48,144],[352,416,48,128],[704,256,48,176],[944,160,48,112]], [[272,208,96,64],[528,416,96,64],[752,176,96,64],[960,400,64,96]], [[384,176,64,176],[640,400,64,144],[864,176,64,176]]], "boss_obstacles": [[288,176,48,128],[288,432,48,112]], "hazard": "laser"},
    {"name": "SILENT CORE", "subtitle": "LÕI TĨNH LẶNG", "description": "Bản phối đang vỡ vụn trong lõi thành phố. Hợp nhất các lớp nhạc và chấm dứt THE SILENCE.", "boss": "NULL MAESTRO", "boss_id": "null_maestro", "bpm": 128, "enemy_ids": ["warden", "sniper", "spiral", "skirmisher", "charger", "support"], "music_layers": ["drums", "motif", "bass", "pad", "lead", "arp", "countermelody"],
     "room_templates": [[[304,160,160,80],[496,432,160,80],[752,240,64,144],[928,464,80,64]], [[320,224,96,96],[592,160,96,96],[592,448,96,96],[896,256,96,96]], [[288,176,64,144],[448,448,176,64],[704,192,176,64],[960,368,64,144]]], "boss_obstacles": [], "hazard": "sequence"},
]


def write_json(path: str, data) -> None:
    target = ROOT / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def content() -> None:
    weapons = [dict(zip(["id", "name", "description", "cooldown", "damage", "speed", "range", "energy"], row)) for row in WEAPONS]
    for weapon in weapons:
        weapon.update(behavior=weapon["id"], icon=f'res://assets/icons/weapon_{weapon["id"]}.svg', model=f'res://assets/sprites/pixel_32/weapons/weapon_{weapon["id"]}_32.png', sprite=f'res://assets/sprites/weapon_{weapon["id"]}.svg', sfx=f'res://assets/audio/sfx_weapon_{weapon["id"]}.wav')
    write_json("data/weapons.json", weapons)
    write_json("data/upgrades.json", [dict(zip(["id", "name", "description", "max_stacks", "compatible"], row)) for row in UPGRADES])
    enemies = [dict(zip(["id", "name", "hp", "speed", "damage", "reward", "role"], row)) for row in ENEMIES]
    for enemy in enemies:
        enemy["sprite"] = f'res://assets/sprites/enemy_{enemy["id"]}.svg'
    write_json("data/enemies.json", enemies)
    for idx, stage in enumerate(STAGES):
        stage.update(id=idx, color=COLORS[idx], boss_sprite=f"res://assets/sprites/boss_{idx+1}.svg", beats_per_bar=4, loop_beats=16, offset_seconds=0.0)
    write_json("data/stages.json", STAGES)


def svg(path: str, body: str, size: int = 32) -> None:
    target = ROOT / "assets" / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="0 0 {size} {size}" shape-rendering="crispEdges">{body}</svg>\n', encoding="utf-8")


def rect(x, y, w, h, color):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{color}"/>'


def art() -> None:
    dark, cyan, white, purple, coral = "#241044", "#35E7FF", "#E6F7FF", "#9B4DFF", "#FF7D8A"
    player = rect(6,25,20,4,"#100923") + rect(10,23,5,5,purple) + rect(19,23,5,5,purple) + rect(8,11,18,13,dark) + rect(9,4,16,13,purple) + rect(6,7,4,9,dark) + rect(24,7,4,9,dark) + rect(10,9,14,6,cyan) + rect(12,10,10,2,white) + rect(11,18,12,4,"#3478FF") + rect(4,15,5,8,cyan) + rect(25,15,4,8,cyan) + rect(16,18,3,5,white)
    svg("sprites/player.svg", player)
    for state in ["idle", "attack", "dash", "hurt", "death", "run_0", "run_1"]:
        body = player
        if state == "dash":
            body = rect(0,10,8,3,cyan) + rect(2,19,6,3,purple) + player
        elif state == "hurt":
            body = player.replace(purple, "#FFFFFF").replace(cyan,coral)
        elif state == "death":
            body = rect(7,23,19,5,dark) + rect(9,21,14,3,purple) + rect(20,25,5,3,cyan)
        elif state == "attack":
            body += rect(25,14,7,4,white)
        elif state == "run_0":
            body += rect(9,26,6,4,cyan)
        elif state == "run_1":
            body += rect(19,26,6,4,cyan)
        svg(f"sprites/player_{state}.svg",body)
    enemy_bodies = [
        rect(6,7,20,18,dark)+rect(10,4,12,24,purple)+rect(3,10,5,12,coral)+rect(24,10,5,12,coral)+rect(11,12,10,5,white),
        rect(5,9,22,17,dark)+rect(9,4,14,21,purple)+rect(4,17,5,5,coral)+rect(14,15,4,9,coral)+rect(23,17,5,5,coral)+rect(11,8,10,3,white),
        '<path d="M4 22V12L16 2L28 12V22L22 28H10Z" fill="#FF7D8A"/>'+rect(9,10,14,13,dark)+rect(12,6,8,7,white)+rect(12,22,8,6,purple),
        rect(3,24,26,5,purple)+rect(6,9,20,16,dark)+rect(10,3,12,17,coral)+rect(13,4,6,11,white)+rect(4,14,4,8,purple)+rect(24,14,4,8,purple),
        '<path d="M16 2L28 10V22L16 30L4 22V10Z" fill="#88FFC9"/>'+rect(10,10,12,12,dark)+rect(13,5,6,7,coral)+rect(5,18,7,6,coral)+rect(20,18,7,6,coral),
        rect(14,20,4,10,"#88FFC9")+rect(5,23,11,4,"#46BAAA")+rect(18,19,10,4,"#46BAAA")+rect(7,4,18,17,purple)+rect(4,8,24,9,dark)+rect(12,6,8,13,"#88FFC9")+rect(9,10,14,5,white),
        rect(8,7,15,19,dark)+rect(10,4,11,10,purple)+rect(14,0,4,32,coral)+rect(7,13,18,5,purple)+rect(11,7,9,4,white)+rect(6,25,6,5,purple)+rect(21,25,6,5,purple),
        '<path d="M4 4H19V9H9V23H23V14H18V19H14V9H28V28H4Z" fill="#9B87FF"/>'+rect(11,11,10,10,dark)+rect(13,13,6,6,white)+rect(0,13,5,6,coral),
        rect(5,8,22,20,dark)+rect(7,5,18,5,coral)+rect(4,2,5,9,purple)+rect(23,2,5,9,purple)+rect(10,13,12,4,white)+rect(13,19,6,7,coral)+rect(1,13,4,11,purple)+rect(27,13,4,11,purple),
        '<path d="M4 6H23L28 14L24 23L12 28L6 21Z" fill="#3478FF"/>'+rect(8,9,17,12,dark)+rect(11,12,13,4,coral)+rect(3,22,12,5,purple)+rect(21,3,7,4,white),
    ]
    for row, body in zip(ENEMIES, enemy_bodies):
        svg(f"sprites/enemy_{row[0]}.svg",rect(5,27,22,3,"#100923")+body)
    # Each silhouette has a different number and placement of emitters.
    bosses = [
        rect(18,12,60,67,dark)+rect(23,4,50,17,purple)+rect(16,23,64,12,cyan)+rect(23,38,50,26,purple)+rect(7,41,15,38,cyan)+rect(75,41,15,38,cyan)+rect(25,72,15,19,purple)+rect(57,72,15,19,purple)+rect(31,43,34,13,white)+rect(33,65,29,5,coral),
        rect(9,11,78,73,"#FFAB64")+rect(15,17,66,61,dark)+rect(24,23,48,49,purple)+rect(32,31,32,32,"#FFAB64")+rect(40,39,16,16,white)+rect(2,20,12,18,dark)+rect(82,20,12,18,dark)+rect(2,65,12,18,dark)+rect(82,65,12,18,dark),
        '<path d="M44 8H54V30H68V41H83V71H91V82H72V64H59V83H39V65H24V82H5V71H13V41H28V30H44Z" fill="#88FFC9"/>'+rect(25,29,47,38,dark)+rect(31,35,35,23,purple)+rect(36,40,7,7,white)+rect(53,40,7,7,white)+rect(42,53,13,8,coral)+rect(14,17,15,15,purple)+rect(68,17,15,15,purple),
        '<path d="M48 3L91 78H5Z" fill="#9B87FF"/><path d="M48 15L80 72H16Z" fill="#241044"/><path d="M48 29L66 62H30Z" fill="#35E7FF"/>'+rect(42,43,12,12,white)+rect(42,0,12,13,coral)+rect(0,74,16,14,coral)+rect(80,74,16,14,coral)+rect(24,81,48,5,purple),
        rect(30,5,36,8,coral)+rect(20,13,56,16,purple)+rect(29,20,38,41,dark)+rect(34,28,28,7,white)+rect(43,42,10,10,coral)+rect(22,56,52,27,purple)+rect(9,34,15,35,coral)+rect(72,34,15,35,coral)+rect(3,61,14,12,white)+rect(79,61,14,12,white)+rect(27,83,12,10,dark)+rect(58,83,12,10,dark)+rect(0,20,17,4,cyan)+rect(79,9,17,4,cyan),
    ]
    for idx, body in enumerate(bosses):
        svg(f"sprites/boss_{idx+1}.svg",rect(16,87,64,7,"#100923")+body,96)
    shapes = [
        rect(5,12,24,7,cyan)+rect(9,18,6,11,purple)+rect(26,13,6,4,white),
        rect(3,10,26,10,"#3478FF")+rect(6,20,6,8,purple)+rect(18,20,5,6,cyan)+rect(10,7,13,3,white),
        rect(3,10,29,6,"#FFAB64")+rect(3,17,29,6,coral)+rect(7,23,7,6,purple),
        rect(0,13,32,5,white)+rect(6,10,20,11,purple)+rect(27,11,5,9,cyan)+rect(8,21,5,8,dark),
        rect(3,10,21,13,purple)+rect(5,14,26,5,cyan)+rect(25,8,4,17,white)+rect(8,23,6,6,dark),
        rect(7,4,18,25,purple)+rect(3,9,26,15,cyan)+rect(9,10,14,12,dark)+rect(13,13,6,6,white),
        rect(5,11,20,12,"#88FFC9")+rect(10,7,12,4,purple)+rect(22,3,4,11,white)+rect(22,20,4,10,white)+rect(8,23,6,6,dark),
        rect(3,9,24,15,"#3478FF")+rect(7,12,24,9,cyan)+rect(12,13,4,7,white)+rect(21,13,4,7,white)+rect(5,24,7,5,purple),
        rect(4,7,21,19,purple)+rect(8,11,24,11,coral)+rect(26,8,6,17,white)+rect(8,26,7,4,dark),
        rect(8,8,16,16,dark)+rect(12,12,8,8,cyan)+rect(2,2,8,8,purple)+rect(22,3,8,8,white)+rect(22,23,8,8,purple)+rect(2,23,8,8,white),
        '<path d="M6 28L2 24L22 4L31 1L28 10Z" fill="#35E7FF"/>'+rect(3,22,8,7,purple)+rect(16,9,4,4,white),
        rect(3,9,22,14,purple)+rect(6,11,26,3,cyan)+rect(6,15,26,3,white)+rect(6,19,26,3,coral)+rect(8,23,6,7,dark),
    ]
    for row, body in zip(WEAPONS, shapes):
        svg(f"icons/weapon_{row[0]}.svg",body)
        svg(f"sprites/weapon_{row[0]}.svg",body)
    # App icon is vector-native; readable at small launcher sizes.
    svg("icon.svg",'<rect width="128" height="128" rx="24" fill="#0B0718"/>'+rect(12,20,16,88,purple)+rect(100,20,16,88,purple)+rect(28,44,16,40,cyan)+rect(84,44,16,40,cyan)+rect(44,28,16,72,white)+rect(68,28,16,72,white)+rect(60,12,8,104,cyan),128)
    for idx, color in enumerate(COLORS):
        svg(f"tiles/stage_{idx+1}_floor.svg",rect(0,0,32,32,"#0F0C20")+rect(0,0,32,1,dark)+rect(0,0,1,32,dark)+rect(26,27,3,1,color))
        svg(f"tiles/stage_{idx+1}_wall.svg",rect(0,0,32,32,dark)+rect(2,2,28,24,"#302050")+rect(3,3,26,3,color)+rect(4,11,24,2,"#493463")+rect(7,18,18,5,"#1A1030"))
    svg("icons/currency.svg",'<path d="M10 2H22L30 10V22L22 30H10L2 22V10Z" fill="#FFCD70"/>'+rect(13,8,6,16,dark)+rect(9,13,14,6,dark))
    svg("icons/energy.svg",'<path d="M18 1L5 18H13L10 31L28 11H19L23 1Z" fill="#35E7FF"/>')
    svg("icons/health.svg",'<path d="M5 4H13L16 8L19 4H27L31 10V17L16 31L1 17V10Z" fill="#FF7D8A"/>'+rect(5,8,7,4,white))


def midi(number: int) -> float:
    return 440.0 * 2 ** ((number - 69) / 12)


def add_note(buf: list[float], start: float, duration: float, note: int, volume: float, voice: str = "pluck", pan_unused: float = 0.0) -> None:
    start_i = round(start * RATE)
    count = round(duration * RATE)
    frequency = midi(note)
    attack = 0.014 if voice == "pad" else 0.004
    for j in range(count):
        t = j / RATE
        phase = TAU * frequency * t
        if voice == "bass":
            sample = math.sin(phase) * .80 + math.sin(phase * 2) * .14 + math.sin(phase * 3) * .06
            envelope = min(1.0, t / attack) * math.exp(-t * 3.5)
        elif voice == "pad":
            sample = (math.sin(phase) + .26 * math.sin(phase * 1.003) + .15 * math.sin(phase * 2)) / 1.41
            envelope = min(1.0, t / .12, (duration - t) / .22) * .72
        else:
            sample = math.sin(phase) * .72 + math.sin(phase * 2) * .20 + math.sin(phase * 4) * .08
            envelope = min(1.0, t / attack) * math.exp(-t * (8.0 if voice == "arp" else 4.6))
        # Short release gives zero-valued note edges. Tail wraps to the beginning.
        envelope *= min(1.0, max(0.0, duration - t) / .025)
        buf[(start_i + j) % len(buf)] += sample * envelope * volume


def add_drum(buf: list[float], start: float, kind: str, volume: float, rng: random.Random) -> None:
    duration = {"kick": .24, "snare": .16, "hat": .055}[kind]
    start_i = round(start * RATE)
    for j in range(round(duration * RATE)):
        t = j / RATE
        if kind == "kick":
            sample = math.sin(TAU * (45 * t + 105 * (1 - math.exp(-t * 25)) / 25)) * math.exp(-t * 20)
        elif kind == "snare":
            sample = (.78 * rng.uniform(-1, 1) + .22 * math.sin(TAU * 180 * t)) * math.exp(-t * 24)
        else:
            sample = rng.uniform(-1, 1) * math.exp(-t * 72)
        sample *= min(1., t / .001) * min(1., max(0., duration - t) / .006)
        buf[(start_i + j) % len(buf)] += sample * volume


def write_wav(path: Path, buf: list[float], gain: float = 1.0, loop: bool = False) -> dict:
    # The music events are periodic, with their decay tails wrapped at the loop.
    # A short guard fade forces an inaudible zero crossing at exact file edges.
    fade = min(round(RATE * .003), len(buf) // 2)
    for i in range(fade):
        buf[i] *= i / fade
        buf[-i - 1] *= i / fade
    peak = max(abs(value) for value in buf) or 1
    # Fixed headroom across mixes keeps transitions from jumping in loudness.
    gain = min(gain, .86 / peak)
    data = array.array("h", [round(max(-1.0, min(1.0, value * gain)) * 32767) for value in buf])
    import sys
    if sys.byteorder != "little":
        data.byteswap()
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(data.tobytes())
    return {"path": str(path.relative_to(ROOT)).replace("\\", "/"), "frames": len(buf), "rate": RATE, "duration": len(buf) / RATE, "peak": round(peak * gain, 4), "loop": loop}


def music() -> list[dict]:
    manifest = []
    # A-minor motif is shared. Later districts add harmonic/melodic layers.
    roots = [45, 41, 48, 43]  # Am, F, C, G.
    motif = [(0,69), (1.5,72), (3,76), (4,69), (5.5,67), (7,64), (8,72), (9.5,76), (11,79), (12,74), (13.5,71), (15,67)]
    for stage_idx, stage in enumerate(STAGES):
        beat = 60 / stage["bpm"]
        total = round(16 * beat * RATE)
        for level, variant in enumerate(["explore", "combat", "boss"]):
            rng = random.Random(1000 + stage_idx)
            buf = [0.0] * total
            # Same composition timeline in all intensity variants allows crossfade.
            for pos, note in motif:
                add_note(buf, pos * beat, .72 * beat, note, .078 if level == 0 else .093)
            for b in range(16):
                add_drum(buf, b * beat, "kick", .16 if level == 0 else .29, rng)
                if b % 2 == 1:
                    add_drum(buf, b * beat, "snare", .045 if level == 0 else .14, rng)
                if level >= 1:
                    add_drum(buf, (b + .5) * beat, "hat", .054, rng)
                if level == 2:
                    add_drum(buf, (b + .25) * beat, "hat", .028, rng)
                    add_drum(buf, (b + .75) * beat, "hat", .032, rng)
                if stage_idx >= 1:
                    root = roots[b // 4]
                    add_note(buf, b * beat, .68 * beat, root, .115 if level == 0 else .18, "bass")
                    if level >= 1:
                        add_note(buf, (b + .5) * beat, .35 * beat, root + (12 if b % 2 else 0), .070, "bass")
            if stage_idx >= 2:
                for bar, root in enumerate(roots):
                    for interval in [12, 15 if bar < 2 else 16, 19]:
                        add_note(buf, bar * 4 * beat, 4.4 * beat, root + interval, .031 if level == 0 else .038, "pad")
            if stage_idx >= 3:
                for b in range(32):
                    notes = [12, 19, 24, 27 if b // 8 < 2 else 28]
                    add_note(buf, b * .5 * beat, .42 * beat, roots[b // 8] + notes[b % 4], .025 if level == 0 else .046, "arp")
                for pos, note in [(2,81),(6,79),(10,84),(14,83)]:
                    add_note(buf, pos * beat, 1.2 * beat, note, .035 if level == 0 else .06)
            if stage_idx >= 4:
                for pos, note in [(0.5,76),(2.5,79),(4.5,72),(6.5,76),(8.5,79),(10.5,84),(12.5,78),(14.5,83)]:
                    add_note(buf,pos*beat,.62*beat,note,.021 if level==0 else .046)
            if level == 2:
                # Boss ostinato: minor low pulse and offbeat octave replies.
                for b in range(16):
                    add_note(buf,(b+.75)*beat,.2*beat,roots[b//4]+24,.061,"arp")
                    if b % 4 == 3:
                        add_drum(buf,(b+.5)*beat,"snare",.086,rng)
            entry = write_wav(ROOT / f"assets/audio/stage_{stage_idx+1}_{variant}.wav",buf,loop=True)
            entry.update(bpm=stage["bpm"], beats=16, variant=variant, stage=stage_idx, loop_error_samples=round(total - 16 * beat * RATE, 6))
            manifest.append(entry)
            print(entry["path"], flush=True)
    return manifest


def sfx() -> list[dict]:
    profiles = {
        "shoot": (.105, 760, 230, .27), "hit": (.10, 280, 90, .27),
        "dash": (.21, 380, 1100, .23), "perfect": (.31, 880, 1320, .25),
        "hurt": (.25, 170, 58, .32), "pickup": (.20, 660, 1320, .25),
        "door": (.30, 180, 560, .24), "buy": (.32, 523, 1047, .25),
        "boss": (.64, 85, 43, .36), "pulse": (.55, 320, 48, .35),
        "shield_break": (.26, 950, 150, .23), "shield_regen": (.30, 340, 720, .18),
        "victory": (.80, 523, 1047, .27), "ui": (.075, 700, 940, .19),
        "weapon_pistol": (.105, 760, 230, .26), "weapon_smg": (.055, 950, 310, .17),
        "weapon_shotgun": (.24, 160, 48, .29), "weapon_rail": (.31, 1300, 90, .29),
        "weapon_beam": (.11, 690, 640, .17), "weapon_disc": (.29, 460, 1040, .23),
        "weapon_arc": (.22, 990, 260, .24), "weapon_wave": (.36, 180, 60, .26),
        "weapon_glitch": (.30, 480, 54, .26), "weapon_orbit": (.42, 390, 790, .23),
        "weapon_blade": (.18, 1200, 440, .22), "weapon_chord": (.29, 523, 784, .25),
    }
    output = []
    for index,(name,(duration,first,last,volume)) in enumerate(profiles.items()):
        rng = random.Random(704+index)
        samples = []
        for i in range(round(duration * RATE)):
            t = i / RATE
            u = t / duration
            phase = TAU * (first*t + (last-first)*t*t/(duration*2))
            raw = math.sin(phase) * .74 + math.sin(phase*2) * .16
            if name in ["hit", "hurt", "boss", "weapon_shotgun", "weapon_glitch", "shield_break", "weapon_arc"]:
                raw += rng.uniform(-1,1)*.36
            if name in ["perfect", "pickup", "buy", "victory", "weapon_chord"]:
                raw = (math.sin(phase)+math.sin(phase*1.25)*.5+math.sin(phase*1.5)*.4)/1.9
            if name == "weapon_glitch":
                raw *= 1 if (int(t*48)%3 != 0) else .18
            envelope = min(1.,t/.003) * (1-u)**2
            samples.append(raw*envelope*volume)
        output.append(write_wav(ROOT / f"assets/audio/sfx_{name}.wav",samples))
    return output


def validate() -> None:
    assert len(WEAPONS)==12 and len(ENEMIES)==10 and len(UPGRADES)>=12 and len(STAGES)==5
    for stage in STAGES:
        assert len(stage["room_templates"]) >= 3
        for template in stage["room_templates"]+[stage["boss_obstacles"]]:
            for x,y,w,h in template:
                assert x>=64 and y>=112 and x+w<=1216 and y+h<=592
    # Grid reachability with a conservative player collision radius of 15 px.
    for stage in STAGES:
        for template in stage["room_templates"] + [stage["boss_obstacles"]]:
            def valid(x,y):
                return 80 <= x <= 1200 and 128 <= y <= 576 and not any(a-15<x<a+w+15 and b-15<y<b+h+15 for a,b,w,h in template)
            visited={(120,352)}
            frontier=[(120,352)]
            while frontier:
                x,y=frontier.pop()
                for dx,dy in [(8,0),(-8,0),(0,8),(0,-8)]:
                    pos=(x+dx,y+dy)
                    if pos not in visited and valid(*pos):
                        visited.add(pos)
                        frontier.append(pos)
            assert any(x>=1152 and abs(y-352)<16 for x,y in visited), f"Disconnected template {stage['name']}"


if __name__ == "__main__":
    validate()
    content()
    art()
    tracks=music()+sfx()
    write_json("assets/audio/manifest.json", {"sample_rate":RATE,"channels":1,"bits":16,"tracks":tracks})
    print(f"Generated {len(tracks)} audio files, original SVG art, and all data configs.")
