extends RefCounted
## Каталог оружия и плёнок. Данные, а не код: чтобы добавить предмет, добавь запись.
## kind: "weapon" (4 слота), "film" (4 слота), "special" (служебные карточки).
## Для плёнок: stat + per_level (прирост за уровень). Для оружия: lvl_desc (что даёт каждый уровень),
## числа по уровням лежат в weapons.gd.

const MAX_WEAPON_SLOTS := 4
const MAX_FILM_SLOTS := 4

const CATALOG := {
    # ---- оружие ----
    "cassette": {"kind": "weapon", "icon": 0, "name": "Кассета-бумеранг", "max": 5, "lvl_desc": [
        "Бросает кассету во врага: пробивает нескольких и возвращается к тебе.",
        "Урон кассеты +40%.",
        "+1 кассета: вторая летит в другого врага.",
        "Пробивает до 5 врагов за полёт.",
        "Возвращаясь, кассета бьёт вдвое сильнее.",
    ]},
    "bat": {"kind": "weapon", "icon": 1, "name": "Бейсбольная бита", "max": 5, "lvl_desc": [
        "Удар по врагам в дуге перед тобой, отбрасывает.",
        "Урон биты +40%.",
        "Дуга удара шире.",
        "Бьёт заметно быстрее.",
        "Удар по кругу, радиус больше.",
    ]},
    "remote": {"kind": "weapon", "icon": 2, "name": "Пульт", "max": 5, "lvl_desc": [
        "Стоп-кадр: урон по области, враги замирают и получают на 30% больше урона.",
        "Пауза длится дольше.",
        "Радиус паузы шире.",
        "Перезарядка короче.",
        "Урон, радиус и пауза выше.",
    ]},
    "flashlight": {"kind": "weapon", "icon": 3, "name": "Фонарь", "max": 5, "lvl_desc": [
        "Луч света жжёт врагов в конусе. Против ужасов урон выше на 50%.",
        "Луч длиннее.",
        "Луч шире.",
        "Чем дольше враг в луче, тем сильнее ожог.",
        "Урон выше, луч светит дольше, ожог быстрее.",
    ]},
    "popgun": {"kind": "weapon", "icon": 4, "name": "Попкорн-пушка", "max": 5, "lvl_desc": [
        "Стреляет зёрнами: каждое взрывается по области.",
        "+1 зерно за выстрел.",
        "Радиус взрыва больше.",
        "Стреляет быстрее.",
        "5 зёрен за выстрел, радиус и урон выше.",
    ]},
    "pricetags": {"kind": "weapon", "icon": 5, "name": "Ценники", "max": 5, "lvl_desc": [
        "Метит врагов: они получают на 30% больше урона от всех, и от копий тоже.",
        "Метка держится дольше.",
        "Метка усиливает урон на 60%.",
        "Помеченный враг взрывается при смерти.",
        "Помечает 4 врагов, взрыв сильнее.",
    ]},
    "flash": {"kind": "weapon", "icon": 6, "name": "Вспышка камеры", "max": 5, "lvl_desc": [
        "Вспышка в конусе ослепляет врагов: они бредут наугад и бьют друг друга.",
        "Ослепление длится дольше.",
        "Конус шире и длиннее.",
        "Ослеплённые бьют друг друга вдвое сильнее.",
        "Вспышка во все стороны, ослепление дольше, перезарядка короче.",
    ]},
    # ---- монтаж: два предмета (минимум 3-го уровня) сливаются в один, у результата 3 уровня ----
    "rewind": {"kind": "weapon", "icon": 7, "name": "Перемотка", "max": 3, "parts": ["cassette", "magnet"], "lvl_desc": [
        "Кассета-бумеранг + Магнит: 2 кассеты, возвращаясь, тянут врагов к тебе.",
        "Урон и притягивание сильнее.",
        "3 кассеты, возврат бьёт вдвое сильнее.",
    ]},
    "homerun": {"kind": "weapon", "icon": 8, "name": "Хоум-ран", "max": 3, "parts": ["bat", "flash"], "lvl_desc": [
        "Бита + Вспышка: удар с ослепляющим взрывом.",
        "Урон и радиус взрыва выше.",
        "Удар по кругу, ослепление дольше.",
    ]},
    "stopframe": {"kind": "weapon", "icon": 9, "name": "Стоп-кадр", "max": 3, "parts": ["remote", "flashlight"], "lvl_desc": [
        "Пульт + Фонарь: волна паузы, затем луч сжигает замороженных.",
        "Радиус, пауза и ожог сильнее.",
        "Урон выше, перезарядка короче.",
    ]},
    "clearance": {"kind": "weapon", "icon": 10, "name": "Распродажа", "max": 3, "parts": ["pricetags", "popgun"], "lvl_desc": [
        "Ценники + Попкорн-пушка: метки, взрыв попкорном при попадании и при смерти.",
        "+1 метка и радиус взрыва больше.",
        "Взрывы мощнее, метки живут дольше.",
    ]},
    # ---- плёнки ----
    "brightness": {"kind": "film", "icon": 11, "name": "Яркость", "desc": "Урон +12% за уровень.",
        "stat": "damage", "per_level": 0.12, "max": 5},
    "highspeed": {"kind": "film", "icon": 12, "name": "Скоростная съёмка", "desc": "Скорострельность и перезарядка оружия: +10% за уровень.",
        "stat": "fire_rate", "per_level": 0.10, "max": 5},
    "wide": {"kind": "film", "icon": 13, "name": "Широкий угол", "desc": "Размер снарядов и областей +12% за уровень.",
        "stat": "size", "per_level": 0.12, "max": 5},
    "fastrewind": {"kind": "film", "icon": 14, "name": "Быстрая перемотка", "desc": "Скорость движения +6% за уровень.",
        "stat": "speed", "per_level": 0.06, "max": 5},
    "magnet": {"kind": "film", "icon": 15, "name": "Магнит", "desc": "Радиус сбора осколков +25% за уровень.",
        "stat": "magnet", "per_level": 0.25, "max": 5},
    "armor": {"kind": "film", "icon": 16, "name": "Бронежилет из проката", "desc": "+1 защитный удар: отбрасывает врагов, 1.5 с неуязвимости. Между дублями восстанавливается.",
        "stat": "armor", "per_level": 1.0, "max": 2},
    # ---- эхо-плёнки: предлагаются, только когда у игрока уже есть копии ----
    "syncmode": {"kind": "film", "icon": 17, "echo": true, "name": "Синхро-режим",
        "desc": "Синхро-удар: окно +0.1 с и множитель урона +0.25 за уровень.",
        "stats": {"sync_window": 0.10, "sync_mult": 0.25}, "max": 3},
    "echoamp": {"kind": "film", "icon": 18, "echo": true, "name": "Эхо-усилитель",
        "desc": "Урон всех копий +15% за уровень.",
        "stats": {"ghost_dmg": 0.15}, "max": 5},
    "resonance": {"kind": "film", "icon": 19, "echo": true, "name": "Резонанс",
        "desc": "Пока копия ближе 200 px, вы оба стреляете на 10% быстрее за уровень.",
        "stats": {"resonance": 0.10}, "max": 5},
    # ---- служебное ----
    "intermission": {"kind": "special", "icon": 21, "name": "Антракт", "desc": "Всё собрано. Восстановить защитные удары.",
        "stat": "none", "per_level": 0.0, "max": 1},
    "overclock_speed": {"kind": "special", "endless": true, "icon": 20, "name": "Стабилизатор камеры",
        "desc": "Скорость передвижения +5% за уровень.", "stat": "speed", "per_level": 0.05, "max": 9999},
    "overclock_damage": {"kind": "special", "endless": true, "icon": 22, "name": "Форсаж эмульсии",
        "desc": "Урон оружия +5% за уровень.", "stat": "damage", "per_level": 0.05, "max": 9999},
    "overclock_rate": {"kind": "special", "endless": true, "icon": 23, "name": "Разгон проектора",
        "desc": "Скорострельность +5% за уровень.", "stat": "fire_rate", "per_level": 0.05, "max": 9999},
}

const HEROES := ["clerk", "courier", "guard", "projectionist", "popcorn", "critic"]
const HERO_INFO := {
    "clerk": {"name": "Клерк", "trait": "Один дополнительный переброс за забег.", "start_weapon": "cassette", "bonuses": {"reroll": 1}},
    "courier": {"name": "Курьер", "trait": "Скорость передвижения +10%.", "start_weapon": "bat", "bonuses": {"speed": 0.10}},
    "guard": {"name": "Охранник", "trait": "Один дополнительный защитный удар.", "start_weapon": "flashlight", "bonuses": {"armor": 1.0}},
    "projectionist": {"name": "Киномеханик", "trait": "Скорострельность +10%.", "start_weapon": "remote", "bonuses": {"fire_rate": 0.10}},
    "popcorn": {"name": "Продавец попкорна", "trait": "Размер оружия и эффектов +15%.", "start_weapon": "popgun", "bonuses": {"size": 0.15}},
    "critic": {"name": "Кинокритик", "trait": "Метки держатся на 30% дольше.", "start_weapon": "pricetags", "bonuses": {"mark_time": 0.30}},
}


## Какие Монтажи можно собрать: оба предмета минимум 3-го уровня, результата ещё нет.
static func montage_available(loadout) -> Array:
    var out: Array = []
    for id in CATALOG:
        var def: Dictionary = CATALOG[id]
        if not def.has("parts") or loadout.level(id) > 0:
            continue
        var ok := true
        for p in def["parts"]:
            if loadout.level(p) < 3:
                ok = false
        if ok:
            out.append(id)
    return out


static func start_weapon(hero: String) -> String:
    var hero_info: Dictionary = HERO_INFO.get(hero, {})
    var id: String = hero_info.get("start_weapon", "cassette")
    return id if CATALOG.has(id) else "cassette"


static func card_description(id: String, lvl: int, loadout = null) -> String:
    var def: Dictionary = CATALOG[id]
    if def.has("lvl_desc"):
        return def["lvl_desc"][lvl]
    var preview: Array[String] = []
    if def.has("stats"):
        for stat in def["stats"]:
            var unit := float(def["stats"][stat])
            var current := float(loadout.bonus(stat)) if loadout != null else unit * lvl
            preview.append(_format_preview(stat, current, current + unit))
    elif def.has("stat") and def["stat"] != "none":
        var unit := float(def["per_level"])
        var current := float(loadout.bonus(def["stat"])) if loadout != null else unit * lvl
        preview.append(_format_preview(def["stat"], current, current + unit))
    if preview.is_empty():
        return def["desc"]
    return "%s\n%s" % [def["desc"], " · ".join(PackedStringArray(preview))]


static func _format_preview(stat: String, current: float, next_value: float) -> String:
    var labels := {
        "damage": "УРОН", "fire_rate": "СКОРОСТРЕЛЬНОСТЬ", "size": "РАЗМЕР АТАК",
        "speed": "СКОРОСТЬ", "magnet": "РАДИУС СБОРА", "armor": "ЗАРЯДЫ ЗАЩИТЫ",
        "sync_window": "ОКНО СИНХРО-УДАРА", "sync_mult": "МНОЖИТЕЛЬ СИНХРО-УДАРА",
        "ghost_dmg": "УРОН КОПИЙ", "resonance": "БОНУС СКОРОСТРЕЛЬНОСТИ",
    }
    var label: String = labels.get(stat, stat.to_upper())
    if stat == "armor":
        return "%s: %.0f → %.0f" % [label, current, next_value]
    if stat == "sync_window":
        return "%s: %.2f → %.2f с" % [label, 0.30 + current, 0.30 + next_value]
    if stat == "sync_mult":
        return "%s: ×%.2f → ×%.2f" % [label, 2.0 + current, 2.0 + next_value]
    return "%s: +%.0f%% → +%.0f%%" % [label, current * 100.0, next_value * 100.0]


## Три (или меньше) карточки. Детерминированно по ключу: откат (REWIND) не даёт накрутить выбор заново.
## force_weapon: гарантировать оружие в тройке (страховка после нескольких выборов подряд без оружия).
static func roll(loadout, key: String, count: int = 3, force_weapon: bool = false, has_ghosts: bool = false,
        endless_mode: bool = false) -> Array:
    var rng := RandomNumberGenerator.new()
    rng.seed = hash(key)
    var owned_w: int = loadout.count_kind("weapon")
    var owned_f: int = loadout.count_kind("film")
    var pool: Array = []
    var weights: Array = []
    for id in CATALOG:
        var def: Dictionary = CATALOG[id]
        if def["kind"] == "special" and not def.get("endless", false):
            continue
        if def.get("endless", false):
            continue
        if def.get("echo", false) and not has_ghosts:
            continue   # эхо-плёнки бессмысленны без копий
        var lvl: int = loadout.level(id)
        if lvl >= def["max"]:
            continue
        if def.has("parts") and lvl == 0:
            continue   # Монтаж предлагается отдельно, золотой карточкой
        if lvl == 0:
            if def["kind"] == "weapon" and owned_w >= MAX_WEAPON_SLOTS:
                continue
            if def["kind"] == "film" and owned_f >= MAX_FILM_SLOTS:
                continue
        pool.append(id)
        weights.append(1.5 if lvl > 0 else 1.0)   # развитие имеющегося вероятнее нового
    if endless_mode and pool.is_empty():
        for id in CATALOG:
            if not CATALOG[id].get("endless", false):
                continue
            var lvl: int = loadout.level(id)
            if lvl < CATALOG[id]["max"]:
                pool.append(id)
                weights.append(1.5 if lvl > 0 else 1.0)
    var all_pool: Array = pool.duplicate()
    var result: Array = _pick_weighted(rng, pool, weights, count)

    if force_weapon and result.size() > 0:
        var has_weapon := false
        for id in result:
            if CATALOG[id]["kind"] == "weapon":
                has_weapon = true
        if not has_weapon:
            var cands: Array = []
            for id in all_pool:
                if CATALOG[id]["kind"] == "weapon":
                    cands.append(id)
            if cands.size() > 0:
                result[result.size() - 1] = cands[rng.randi() % cands.size()]

    # Монтаж: если пара готова, золотая карточка всегда в тройке
    var mont: Array = montage_available(loadout)
    if mont.size() > 0:
        var mid: String = mont[rng.randi() % mont.size()]
        if result.is_empty():
            result.append(mid)
        elif not result.has(mid):
            result[result.size() - 1] = mid
    return result


static func _pick_weighted(rng: RandomNumberGenerator, pool: Array, weights: Array, count: int) -> Array:
    var result: Array = []
    while result.size() < count and pool.size() > 0:
        var total := 0.0
        for w in weights:
            total += w
        var r := rng.randf() * total
        var i := 0
        while i < pool.size() - 1 and r > weights[i]:
            r -= weights[i]
            i += 1
        result.append(pool[i])
        pool.remove_at(i)
        weights.remove_at(i)
    return result
