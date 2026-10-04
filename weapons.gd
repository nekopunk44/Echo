extends RefCounted
## Параметры оружия по уровням (1..5). Эффекты считаются в main.gd (tick_weapons).
## dmg — базовый урон; cd — перезарядка в секундах (плёнка «Скоростная съёмка» её сокращает).

const PARAMS := {
    "cassette": [   # count — кассет за бросок, pierce — врагов за один полёт, ret — множитель урона на возврате
        {"dmg": 1.2, "count": 1, "pierce": 3, "ret": 1.0, "cd": 0.9},
        {"dmg": 1.7, "count": 1, "pierce": 3, "ret": 1.0, "cd": 0.9},
        {"dmg": 1.7, "count": 2, "pierce": 3, "ret": 1.0, "cd": 0.9},
        {"dmg": 1.7, "count": 2, "pierce": 5, "ret": 1.0, "cd": 0.9},
        {"dmg": 1.7, "count": 2, "pierce": 5, "ret": 2.0, "cd": 0.9},
    ],
    "bat": [        # arc — дуга удара в градусах (360 = по кругу)
        {"dmg": 2.0, "arc": 110.0, "radius": 100.0, "cd": 1.3},
        {"dmg": 2.8, "arc": 110.0, "radius": 100.0, "cd": 1.3},
        {"dmg": 2.8, "arc": 160.0, "radius": 100.0, "cd": 1.3},
        {"dmg": 2.8, "arc": 160.0, "radius": 100.0, "cd": 0.95},
        {"dmg": 2.8, "arc": 360.0, "radius": 115.0, "cd": 0.95},
    ],
    "remote": [     # freeze — сколько секунд враги стоят на паузе
        {"dmg": 2.2, "radius": 200.0, "freeze": 1.0, "cd": 1.7},
        {"dmg": 2.2, "radius": 200.0, "freeze": 1.6, "cd": 1.7},
        {"dmg": 2.2, "radius": 260.0, "freeze": 1.6, "cd": 1.7},
        {"dmg": 2.2, "radius": 260.0, "freeze": 1.6, "cd": 1.3},
        {"dmg": 3.0, "radius": 300.0, "freeze": 2.0, "cd": 1.3},
    ],
    "flashlight": [ # dmg — за тик (каждые 0.12 с), len/w — длина и ширина конуса, dur — сколько светит,
                    # ramp — за сколько секунд ожог растёт до x2 (0 = без нарастания)
        {"dmg": 0.45, "len": 260.0, "w": 36.0, "dur": 1.2, "ramp": 0.0, "cd": 2.2},
        {"dmg": 0.45, "len": 340.0, "w": 36.0, "dur": 1.2, "ramp": 0.0, "cd": 2.2},
        {"dmg": 0.45, "len": 340.0, "w": 64.0, "dur": 1.2, "ramp": 0.0, "cd": 2.2},
        {"dmg": 0.45, "len": 340.0, "w": 64.0, "dur": 1.2, "ramp": 1.0, "cd": 2.2},
        {"dmg": 0.60, "len": 360.0, "w": 70.0, "dur": 1.8, "ramp": 0.8, "cd": 2.2},
    ],
    "popgun": [     # count — зёрен за выстрел, radius — радиус взрыва зерна
        {"dmg": 1.0, "count": 2, "radius": 55.0, "cd": 1.1},
        {"dmg": 1.0, "count": 3, "radius": 55.0, "cd": 1.1},
        {"dmg": 1.0, "count": 3, "radius": 75.0, "cd": 1.1},
        {"dmg": 1.0, "count": 3, "radius": 75.0, "cd": 0.8},
        {"dmg": 1.2, "count": 5, "radius": 85.0, "cd": 0.8},
    ],
    "pricetags": [  # count — сколько врагов метит, dur — сколько живёт метка, mult — множитель урона по метке,
                    # boom_r / boom_dmg — взрыв помеченного врага при смерти
        {"dmg": 1.6, "count": 2, "dur": 5.0, "mult": 1.3, "boom_r": 0.0, "boom_dmg": 0.0, "cd": 1.0},
        {"dmg": 1.6, "count": 2, "dur": 8.0, "mult": 1.3, "boom_r": 0.0, "boom_dmg": 0.0, "cd": 1.1},
        {"dmg": 1.6, "count": 2, "dur": 8.0, "mult": 1.6, "boom_r": 0.0, "boom_dmg": 0.0, "cd": 1.1},
        {"dmg": 1.6, "count": 2, "dur": 8.0, "mult": 1.6, "boom_r": 90.0, "boom_dmg": 2.0, "cd": 1.0},
        {"dmg": 1.6, "count": 4, "dur": 8.0, "mult": 1.6, "boom_r": 110.0, "boom_dmg": 3.0, "cd": 1.0},
    ],
    "flash": [      # arc/radius — конус вспышки, blind — сколько секунд враги слепы, hit — урон при столкновении слепых
        {"dmg": 0.5, "arc": 70.0, "radius": 220.0, "blind": 1.5, "hit": 1.0, "cd": 2.6},
        {"dmg": 0.5, "arc": 70.0, "radius": 220.0, "blind": 2.2, "hit": 1.0, "cd": 2.6},
        {"dmg": 0.5, "arc": 120.0, "radius": 260.0, "blind": 2.2, "hit": 1.0, "cd": 2.6},
        {"dmg": 0.5, "arc": 120.0, "radius": 260.0, "blind": 2.2, "hit": 2.0, "cd": 2.6},
        {"dmg": 0.8, "arc": 360.0, "radius": 280.0, "blind": 3.0, "hit": 2.5, "cd": 2.0},
    ],
    # ---- монтаж (2 предмета -> 1), по 3 уровня ----
    "rewind": [     # Кассета + Магнит: на возврате кассеты тянут врагов (pull_r — радиус, pull — скорость)
        {"dmg": 1.9, "count": 2, "pierce": 5, "ret": 1.5, "pull_r": 150.0, "pull": 220.0, "cd": 0.9},
        {"dmg": 2.4, "count": 2, "pierce": 5, "ret": 1.5, "pull_r": 180.0, "pull": 280.0, "cd": 0.9},
        {"dmg": 2.4, "count": 3, "pierce": 6, "ret": 2.0, "pull_r": 210.0, "pull": 340.0, "cd": 0.85},
    ],
    "homerun": [    # Бита + Вспышка: удар и ослепляющий взрыв в точке удара (boom_r)
        {"dmg": 3.0, "arc": 160.0, "radius": 110.0, "boom_r": 130.0, "blind": 2.0, "hit": 1.5, "cd": 1.1},
        {"dmg": 3.8, "arc": 160.0, "radius": 115.0, "boom_r": 160.0, "blind": 2.0, "hit": 2.0, "cd": 1.0},
        {"dmg": 3.8, "arc": 360.0, "radius": 125.0, "boom_r": 190.0, "blind": 3.0, "hit": 2.5, "cd": 0.9},
    ],
    "stopframe": [  # Пульт + Фонарь: волна паузы, затем луч сжигает замороженных (bdmg — урон луча за тик)
        {"dmg": 2.4, "radius": 300.0, "freeze": 1.8, "len": 340.0, "w": 70.0, "bdmg": 0.6, "ramp": 0.8, "dur": 1.8, "cd": 3.0},
        {"dmg": 2.4, "radius": 340.0, "freeze": 2.2, "len": 380.0, "w": 80.0, "bdmg": 0.7, "ramp": 0.7, "dur": 2.2, "cd": 3.0},
        {"dmg": 3.0, "radius": 360.0, "freeze": 2.4, "len": 400.0, "w": 90.0, "bdmg": 0.9, "ramp": 0.6, "dur": 2.4, "cd": 2.8},
    ],
    "clearance": [  # Ценники + Попкорн-пушка: метки, взрыв попкорном при попадании (pop) и при смерти (boom)
        {"dmg": 1.8, "count": 3, "dur": 8.0, "mult": 1.6, "boom_r": 100.0, "boom_dmg": 2.5, "pop_r": 70.0, "pop_dmg": 1.2, "cd": 1.0},
        {"dmg": 1.8, "count": 4, "dur": 8.0, "mult": 1.6, "boom_r": 110.0, "boom_dmg": 2.5, "pop_r": 80.0, "pop_dmg": 1.2, "cd": 1.0},
        {"dmg": 1.8, "count": 4, "dur": 10.0, "mult": 1.6, "boom_r": 130.0, "boom_dmg": 3.0, "pop_r": 95.0, "pop_dmg": 1.6, "cd": 1.0},
    ],
}


static func params(id: String, lvl: int) -> Dictionary:
    var arr: Array = PARAMS[id]
    return arr[clampi(lvl, 1, arr.size()) - 1]
