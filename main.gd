extends Node2D
## Главная сцена: цикл дублей, спавн врагов, опыт и выбор плёнок, HUD в стиле VHS.

const PlayerScript := preload("res://player.gd")
const GhostScript := preload("res://ghost.gd")
const EnemyScript := preload("res://enemy.gd")
const BoomerangScript := preload("res://boomerang.gd")
const SwingScript := preload("res://swing_fx.gd")
const PulseScript := preload("res://pulse_fx.gd")
const BeamScript := preload("res://beam.gd")
const FlashFxScript := preload("res://flash_fx.gd")
const PopKernelScript := preload("res://popkernel.gd")
const TagShotScript := preload("res://tagshot.gd")
const WeaponsScript := preload("res://weapons.gd")
const BurstScript := preload("res://glitch_burst.gd")
const PickupScript := preload("res://pickup.gd")
const LoadoutScript := preload("res://loadout.gd")
const UpgradesScript := preload("res://upgrades.gd")
const LevelUpScript := preload("res://levelup_ui.gd")
const RunMenuScript := preload("res://run_menu.gd")
const UpgradeIconAtlas := preload("res://assets/upgrade_icons.svg")

const ROUND_TIME := 30.0          # для финальной версии: 90.0
const ARENA := Vector2(720, 1280)
const GHOST_DMG := 0.6            # урон копии относительно игрока
const CAMPAIGN_TAKES := 12
const BOSS_EVERY := 3
const MAX_ACTIVE_GHOSTS := 5
const MAX_LOADOUT_ICONS := 11

# Кассеты-жанры: какие враги идут в каком жанре (kind см. enemy.gd). Пока выбирается случайно на старте забега.
const GENRES := [
    {"name": "УЖАСЫ", "kinds": [0, 0, 0, 1, 1]},
    {"name": "БОЕВИК", "kinds": [2, 2, 4, 4]},
    {"name": "ВЕСТЕРН", "kinds": [3]},
    {"name": "КИБЕРПАНК", "kinds": [5, 5, 2]},
]
const ACT_RULES := [
    {"name": "ЧИСТЫЙ КАДР", "spawn": 1.0, "speed": 1.0, "health": 1.0},
    {"name": "ПЛОТНАЯ НАРЕЗКА · ВРАГОВ НА 14% ЧАЩЕ", "spawn": 0.88, "speed": 1.0, "health": 1.0},
    {"name": "ГОРЯЩАЯ ПЛЁНКА · ВРАГИ НА 15% БЫСТРЕЕ", "spawn": 1.0, "speed": 1.15, "health": 1.0},
    {"name": "СРЫВ СИГНАЛА · ВРАГИ КРЕПЧЕ И ЧАЩЕ", "spawn": 0.85, "speed": 1.0, "health": 1.15},
]

enum State { MENU, PLAY, REWIND, DEAD, PICK, BANKING, VICTORY }

var state := State.MENU
var take := 1
var take_time := 0.0
var spawn_timer := 0.0
var rewind_timer := 0.0
var bank_timer := 0.0
var dead_time := 0.0
var kills := 0

# опыт и плёнки
var loadout
var xp := 0
var level := 1
var pending: Array = []          # очередь выборов: {"key", "title"}
var cur_pick := {}
var choices: Array = []
var run_seed := 0
var reroll_idx := 0
var rerolls_left := 1
var armor_charges := 0
var invuln := 0.0
var picks_no_weapon := 0
var debug_montage_i := 0
var bonus_rerolls := 0
var run_mode := "campaign"
var run_genre := 0
var endless_unlocked := false
var act_index := 0

var player: CharacterBody2D
var picker
var run_menu
var hud_rec: Label
var hud_msg: Label
var hud_genre: Label
var hud_level: Label
var hud_loadout: HBoxContainer
var rec_dot: ColorRect
var xp_fill: ColorRect
var genre := 0
var forced_genre := -1
var boss_spawned := false
var boss_defeated := false
var loadout_hud_signature := ""


func _ready() -> void:
    randomize()
    RenderingServer.set_default_clear_color(Color("1a0b2e"))
    _build_hud()
    picker = LevelUpScript.new()
    add_child(picker)
    picker.picked.connect(_on_picked)
    picker.reroll_requested.connect(_on_reroll)
    run_menu = RunMenuScript.new()
    add_child(run_menu)
    run_menu.campaign_requested.connect(_on_campaign_requested)
    run_menu.endless_requested.connect(_on_endless_requested)
    run_menu.endless_continue_requested.connect(_on_endless_continue_requested)
    run_menu.menu_requested.connect(_on_menu_requested)
    var progress := ConfigFile.new()
    if progress.load("user://echo.cfg") == OK:
        endless_unlocked = bool(progress.get_value("progress", "endless_unlocked", false))
    run_menu.show_menu(Recorder.hero, endless_unlocked)


func is_playing() -> bool:
    return state == State.PLAY


func is_banking() -> bool:
    return state == State.BANKING


func xp_need(l: int) -> int:
    return roundi(8.0 + 6.0 * l + 0.35 * l * l)


## Урон копии относительно игрока: базовые 60% плюс «Эхо-усилитель» из плёнок игрока.
func _dmg_scale(source: String) -> float:
    return 1.0 if source == "player" else GHOST_DMG * loadout.mult("ghost_dmg")


## Синхро-удар: окно (сек) и множитель урона, растут от «Синхро-режима».
func sync_window() -> float:
    return 0.3 + loadout.bonus("sync_window")


func sync_mult() -> float:
    return 2.0 + loadout.bonus("sync_mult")


## «Резонанс»: пока игрок и копия ближе 200 px, оба стреляют быстрее.
func _resonance_factor(actor: Node2D, source: String) -> float:
    var r: float = loadout.bonus("resonance")
    if r <= 0.0:
        return 1.0
    if source == "player":
        for g in get_tree().get_nodes_in_group("ghosts"):
            if actor.position.distance_to(g.position) < 200.0:
                return 1.0 + r
        return 1.0
    return 1.0 + r if actor.position.distance_to(player.position) < 200.0 else 1.0


func _armor_max() -> int:
    return int(round(loadout.bonus("armor")))


func magnet_radius() -> float:
    return 90.0 * loadout.mult("magnet")


# ---------- цикл забега ----------

func _start_run(mode: String = "campaign") -> void:
    get_tree().paused = false
    run_menu.hide_panel()
    picker.close()
    Recorder.reset()
    run_mode = mode
    loadout = LoadoutScript.new()
    loadout.set_hero(Recorder.hero)
    loadout.add(UpgradesScript.start_weapon(Recorder.hero))   # стартовое оружие героя
    picks_no_weapon = 0
    bonus_rerolls = int(loadout.trait_bonus.get("reroll", 0))
    xp = 0
    level = 1
    pending.clear()
    run_seed = randi()
    take = 1
    kills = 0
    run_genre = forced_genre if forced_genre >= 0 else randi() % GENRES.size()
    genre = run_genre
    loadout_hud_signature = ""
    _start_take()


func _start_take() -> void:
    _clear_world()
    if is_instance_valid(player):
        player.queue_free()
    player = PlayerScript.new()
    player.position = ARENA / 2.0
    add_child(player)
    var first_ghost := maxi(0, Recorder.ghosts.size() - MAX_ACTIVE_GHOSTS)
    for i in range(first_ghost, Recorder.ghosts.size()):
        var d: Dictionary = Recorder.ghosts[i]
        var g := GhostScript.new()
        g.path = d["path"]
        g.start_levels = d["levels"]
        g.events = d["events"]
        g.age = Recorder.ghosts.size() - 1 - i   # 0 = самый свежий дубль
        add_child(g)
    move_child(player, -1)   # игрок рисуется поверх копий
    Recorder.start_take(loadout.levels)
    take_time = 0.0
    spawn_timer = 1.0
    boss_spawned = false
    boss_defeated = false
    act_index = int((take - 1) / BOSS_EVERY) % ACT_RULES.size()
    genre = (run_genre + int((take - 1) / BOSS_EVERY)) % GENRES.size()
    var act := act_index + 1
    var boss_tag := "  ·  БОСС" if _is_boss_take() else ""
    hud_genre.text = "КАССЕТА: %s  ·  ЭТАП %d/4%s\n%s" % [GENRES[genre]["name"], act, boss_tag, ACT_RULES[act_index]["name"]]
    state = State.PLAY
    hud_msg.text = ""
    armor_charges = _armor_max()
    invuln = 0.0
    rerolls_left = 1
    if take >= 2:   # бесплатная плёнка в начале каждого нового дубля
        pending.append({"key": "%d_t%d" % [run_seed, take], "title": "СВЕЖАЯ ПЛЁНКА"})


func _clear_world() -> void:
    for group in ["enemies", "bullets", "ghosts", "fx", "pickups"]:
        for n in get_tree().get_nodes_in_group(group):
            n.queue_free()


func _finish_take() -> void:
    state = State.BANKING
    bank_timer = 3.0
    player.active = false
    hud_msg.text = "ПЕРЕМОТКА\n\nОСКОЛКИ ВОЗВРАЩАЮТСЯ К ТЕБЕ"
    for p in get_tree().get_nodes_in_group("pickups"):
        p.target = player
        p.attracted = true


func _complete_take() -> void:
    # Страховка на случай, если осколок не успел долететь за время перемотки.
    for p in get_tree().get_nodes_in_group("pickups"):
        add_xp(p.value)
        p.queue_free()
    Recorder.finish_take()
    take += 1
    state = State.REWIND
    rewind_timer = 0.8
    player.active = false
    _clear_world()
    hud_msg.text = "REWIND"


func _is_boss_take() -> bool:
    return take % BOSS_EVERY == 0


func boss_died() -> void:
    boss_defeated = true
    if run_mode == "campaign" and take == CAMPAIGN_TAKES:
        for p in get_tree().get_nodes_in_group("pickups"):
            add_xp(p.value)
            p.queue_free()
        state = State.VICTORY
        player.active = false
        endless_unlocked = true
        var progress := ConfigFile.new()
        progress.set_value("progress", "endless_unlocked", true)
        progress.save("user://echo.cfg")
        run_menu.show_victory(kills, level)
    elif state == State.PLAY:
        hud_msg.text = ""


func _on_campaign_requested(hero: String) -> void:
    Recorder.hero = hero
    _start_run("campaign")


func _on_endless_requested(hero: String) -> void:
    Recorder.hero = hero
    _start_run("endless")


func _on_endless_continue_requested() -> void:
    run_mode = "endless"
    take = 13
    run_menu.hide_panel()
    _start_take()


func _on_menu_requested() -> void:
    get_tree().paused = false
    _clear_world()
    if is_instance_valid(player):
        player.queue_free()
    Recorder.reset()
    state = State.MENU
    run_menu.show_menu(Recorder.hero, endless_unlocked)


func player_died() -> void:
    if state != State.PLAY or invuln > 0.0:
        return
    if armor_charges > 0:   # бронежилет: отбрасываем врагов и даём секунду-другую неуязвимости
        armor_charges -= 1
        invuln = 1.5
        _shockwave(player.position, 240.0)
        spawn_burst(player.position, Color("00f0ff"))
        return
    state = State.DEAD
    dead_time = 0.0
    player.active = false
    spawn_burst(player.position, Color("f4f0ff"))
    player.visible = false
    hud_msg.text = "EJECT\n\nкассета: %s\nубито: %d  |  уровень: %d  |  дубль: %d\n\nтап/клавиша — начать заново\nEsc — главное меню" % [GENRES[genre]["name"], kills, level, take]


func _shockwave(center: Vector2, radius: float) -> void:
    for e in get_tree().get_nodes_in_group("enemies"):
        var d: Vector2 = e.position - center
        if d.length() < radius:
            var k := 0.4 if e.kind == 6 else 1.0
            e.position += d.normalized() * 180.0 * k


# ---------- опыт и выбор плёнки ----------

func add_xp(v: int) -> void:
    xp += v
    while xp >= xp_need(level):
        xp -= xp_need(level)
        level += 1
        pending.append({"key": "%d_lv%d" % [run_seed, level], "title": "УРОВЕНЬ %d" % level})


func _open_picker() -> void:
    cur_pick = pending.pop_front()
    reroll_idx = 0
    state = State.PICK
    player.reset_input()
    get_tree().paused = true
    _roll_choices()
    picker.open(cur_pick["title"], choices, loadout, rerolls_left + bonus_rerolls)


func _roll_choices() -> void:
    var key: String = cur_pick["key"]
    if reroll_idx > 0:
        key += "_r%d" % reroll_idx
    choices = UpgradesScript.roll(loadout, key, 3, picks_no_weapon >= 3,
        Recorder.ghosts.size() > 0, run_mode == "endless")
    if choices.is_empty():
        choices = ["intermission"]


func _on_picked(id: String) -> void:
    _apply_pick(id)
    picker.close()
    get_tree().paused = false
    player.reset_input()
    state = State.PLAY


func _on_reroll() -> void:
    if rerolls_left > 0:
        rerolls_left -= 1       # один переброс доступен в каждом дубле
    elif bonus_rerolls > 0:
        bonus_rerolls -= 1      # черта клерка: один бесплатный пересброс за забег
    else:
        return
    reroll_idx += 1
    _roll_choices()
    picker.set_choices(choices, loadout)
    picker.set_reroll_count(rerolls_left + bonus_rerolls)


func _apply_pick(id: String) -> void:
    if id == "intermission":
        armor_charges = _armor_max()
        return
    loadout.add(id)
    Recorder.record_event(id)   # копии повторят этот выбор в тот же момент
    if UpgradesScript.CATALOG[id]["kind"] == "weapon":
        picks_no_weapon = 0
    else:
        picks_no_weapon += 1
    if id == "armor":
        armor_charges += 1


# ---------- игровой цикл ----------

func _physics_process(delta: float) -> void:
    match state:
        State.MENU, State.VICTORY:
            pass
        State.PLAY:
            if pending.size() > 0:
                _open_picker()
                return
            take_time += delta
            invuln = maxf(0.0, invuln - delta)
            Recorder.record(player.position)
            spawn_timer -= delta
            if spawn_timer <= 0.0:
                var base_interval := maxf(0.2, 1.1 - 0.015 * take_time - 0.1 * (take - 1))
                spawn_timer = maxf(0.08, base_interval * float(ACT_RULES[act_index]["spawn"]) / (1.0 + 0.02 * (take - 1)))
                _spawn_enemy()
            if take_time >= ROUND_TIME:
                if not _is_boss_take() or boss_defeated:
                    _finish_take()
                elif hud_msg.text.is_empty():
                    hud_msg.text = "ЦЕНЗОР НЕ ПОВЕРЖЕН\nЗАВЕРШИ ЭТОТ ДУБЛЬ, ЧТОБЫ ПЕРЕМАТАТЬ ПЛЁНКУ"
        State.REWIND:
            rewind_timer -= delta
            if rewind_timer <= 0.0:
                _start_take()
        State.BANKING:
            bank_timer -= delta
            if bank_timer <= 0.0 or get_tree().get_nodes_in_group("pickups").is_empty():
                _complete_take()
        State.DEAD:
            dead_time += delta
        State.PICK:
            pass


func _spawn_enemy(force_kind: int = -1) -> void:
    var e := EnemyScript.new()
    var p := Vector2.ZERO
    match randi() % 4:
        0: p = Vector2(randf_range(0, ARENA.x), -60)
        1: p = Vector2(randf_range(0, ARENA.x), ARENA.y + 60)
        2: p = Vector2(-60, randf_range(0, ARENA.y))
        _: p = Vector2(ARENA.x + 60, randf_range(0, ARENA.y))
    var kinds: Array = GENRES[genre]["kinds"]
    if force_kind >= 0:
        e.kind = force_kind
    elif _is_boss_take() and not boss_spawned:
        e.kind = 6
        boss_spawned = true
    else:
        e.kind = kinds[randi() % kinds.size()]
    if e.kind == 6:
        boss_spawned = true
    e.position = p
    var difficulty_mult := (1.0 + 0.06 * (take - 1)) * float(ACT_RULES[act_index]["health"])
    e.hp = (2.0 + (take - 1)) * difficulty_mult
    e.speed = (randf_range(90.0, 140.0) + take * 8.0) * float(ACT_RULES[act_index]["speed"])
    match e.kind:
        1:  # призрак: медленнее, но крепче
            e.speed *= 0.8
            e.hp += 1.0
        2:  # дрон: быстрый и хрупкий
            e.speed *= 1.3
            e.hp = maxf(1.0, e.hp - 1.0)
        4:  # наёмник: крепкий
            e.speed *= 0.9
            e.hp += 2.0
        5:  # робот: медленный танк
            e.speed *= 0.75
            e.hp += 3.0
        6:  # Цензор, босс
            e.speed = 55.0
            e.hp = (50.0 + 15.0 * (take - 1)) * difficulty_mult
    e.target = player
    e.main = self
    add_child(e)


# ---------- оружие ----------

## Общий цикл оружия для игрока и копий. cds — перезарядки владельца (id -> секунды).
## Возвращает направление последней атаки (ZERO, если никто не атаковал).
func tick_weapons(actor: Node2D, source: String, lo, cds: Dictionary, delta: float) -> Vector2:
    var aim := Vector2.ZERO
    var dmg_scale := _dmg_scale(source)
    for id in lo.levels:
        if UpgradesScript.CATALOG[id]["kind"] != "weapon":
            continue
        cds[id] = float(cds.get(id, 0.0)) - delta
        if cds[id] > 0.0:
            continue
        var prm: Dictionary = WeaponsScript.params(id, lo.level(id))
        var dmg: float = float(prm["dmg"]) * lo.mult("damage") * dmg_scale
        var size: float = lo.mult("size")
        var dir := Vector2.ZERO
        match id:
            "cassette": dir = _fire_cassette(prm, actor, source, dmg, size)
            "bat": dir = _fire_bat(prm, actor, source, dmg, size)
            "remote": dir = _fire_remote(prm, actor, source, dmg, size)
            "flash": dir = _fire_flash(prm, actor, source, dmg, size)
            "rewind": dir = _fire_cassette(prm, actor, source, dmg, size)
            "homerun": dir = _fire_bat(prm, actor, source, dmg, size)
            "stopframe": dir = _fire_stopframe(prm, actor, source, dmg, size)
            "clearance": dir = _fire_pricetags(prm, actor, source, dmg, size, lo)
            "flashlight": dir = _fire_flashlight(prm, actor, source, dmg, size)
            "popgun": dir = _fire_popgun(prm, actor, source, dmg, size)
            "pricetags": dir = _fire_pricetags(prm, actor, source, dmg, size, lo)
        if dir != Vector2.ZERO:
            var cd: float = float(prm["cd"]) / (lo.mult("fire_rate") * _resonance_factor(actor, source))
            if id == "flashlight":
                cd = maxf(cd, float(prm["dur"]) + 0.15)   # луч не накладывается сам на себя
            cds[id] = cd
            aim = dir
        else:
            cds[id] = 0.1   # целей нет — проверим чуть позже
    return aim


## Ближайшие живые враги: [[расстояние, враг], ...] по возрастанию.
func _nearest_enemies(pos: Vector2, max_dist: float, count: int) -> Array:
    var arr: Array = []
    for e in get_tree().get_nodes_in_group("enemies"):
        if e.dead:
            continue
        var d: float = pos.distance_to(e.position)
        if d <= max_dist:
            arr.append([d, e])
    arr.sort_custom(func(a, b): return a[0] < b[0])
    return arr.slice(0, count)


func _fire_cassette(prm: Dictionary, actor: Node2D, source: String, dmg: float, size: float) -> Vector2:
    var n := int(prm["count"])
    var near := _nearest_enemies(actor.position, 600.0, n)
    if near.is_empty():
        return Vector2.ZERO
    var dir1: Vector2 = (near[0][1].position - actor.position).normalized()
    var dirs: Array = []
    for i in n:
        if i < near.size():
            dirs.append((near[i][1].position - actor.position).normalized())
        else:   # врагов меньше, чем кассет: лишние летят веером
            dirs.append(dir1.rotated(0.45 * float(i - near.size() + 1) * (1.0 if i % 2 == 1 else -1.0)))
    for d in dirs:
        var b := BoomerangScript.new()
        b.position = actor.position
        b.owner_node = actor
        b.source = source
        b.dir = d
        b.damage = dmg
        b.size_mult = size
        b.pierce = int(prm["pierce"])
        b.ret_mult = float(prm["ret"])
        b.pull_r = float(prm.get("pull_r", 0.0)) * size
        b.pull = float(prm.get("pull", 0.0))
        add_child(b)
    return dir1


func _fire_bat(prm: Dictionary, actor: Node2D, source: String, dmg: float, size: float) -> Vector2:
    var radius: float = float(prm["radius"]) * size
    var near := _nearest_enemies(actor.position, radius * 1.4, 1)
    if near.is_empty():
        return Vector2.ZERO
    var dir: Vector2 = (near[0][1].position - actor.position).normalized()
    var arc: float = prm["arc"]
    for e in get_tree().get_nodes_in_group("enemies"):
        if e.dead:
            continue
        var v: Vector2 = e.position - actor.position
        if v.length() > radius + e.hit_r * 0.5:
            continue
        if arc < 359.0 and absf(angle_difference(dir.angle(), v.angle())) > deg_to_rad(arc) / 2.0:
            continue
        e.hit(dmg, source)
        if not e.dead and e.kind != 6:
            e.position += v.normalized() * 36.0   # отбрасывание
    var col := Color("fff44f") if source == "player" else Color("00f0ff")
    var fx := SwingScript.new()
    fx.position = actor.position
    fx.dir_angle = dir.angle()
    fx.radius = radius
    fx.arc_deg = arc
    fx.color = col
    add_child(fx)
    if prm.has("boom_r"):   # Монтаж «Хоум-ран»: ослепляющий взрыв в точке удара
        var c: Vector2 = actor.position + dir * radius * 0.7
        var boom_r: float = float(prm["boom_r"]) * size
        var k: float = dmg / float(prm["dmg"])
        for e in get_tree().get_nodes_in_group("enemies"):
            if not e.dead and c.distance_to(e.position) <= boom_r + e.hit_r * 0.5:
                e.blind(float(prm["blind"]), float(prm["hit"]) * k, source)
        var bfx := PulseScript.new()
        bfx.position = c
        bfx.radius = boom_r
        bfx.color = Color("ffffff")
        bfx.bars = false
        bfx.life = 0.4
        add_child(bfx)
    return dir


func _fire_remote(prm: Dictionary, actor: Node2D, source: String, dmg: float, size: float) -> Vector2:
    var radius: float = float(prm["radius"]) * size
    var near := _nearest_enemies(actor.position, radius * 1.1, 1)
    if near.is_empty():
        return Vector2.ZERO
    var dir: Vector2 = (near[0][1].position - actor.position).normalized()
    for e in get_tree().get_nodes_in_group("enemies"):
        if e.dead:
            continue
        if actor.position.distance_to(e.position) > radius + e.hit_r * 0.3:
            continue
        e.hit(dmg, source)
        e.freeze(float(prm["freeze"]))
    var fx := PulseScript.new()
    fx.position = actor.position
    fx.radius = radius
    fx.color = Color("fff44f") if source == "player" else Color("00f0ff")
    add_child(fx)
    return dir


func _fire_flash(prm: Dictionary, actor: Node2D, source: String, dmg: float, size: float) -> Vector2:
    var radius: float = float(prm["radius"]) * size
    var near := _nearest_enemies(actor.position, radius, 1)
    if near.is_empty():
        return Vector2.ZERO
    var dir: Vector2 = (near[0][1].position - actor.position).normalized()
    var arc: float = prm["arc"]
    var k: float = dmg / float(prm["dmg"])
    for e in get_tree().get_nodes_in_group("enemies"):
        if e.dead:
            continue
        var v: Vector2 = e.position - actor.position
        if v.length() > radius + e.hit_r * 0.5:
            continue
        if arc < 359.0 and absf(angle_difference(dir.angle(), v.angle())) > deg_to_rad(arc) / 2.0:
            continue
        e.hit(dmg, source)
        e.blind(float(prm["blind"]), float(prm["hit"]) * k, source)
    var fx := FlashFxScript.new()
    fx.position = actor.position
    fx.dir_angle = dir.angle()
    fx.radius = radius
    fx.arc_deg = arc
    fx.color = Color("fff44f") if source == "player" else Color("00f0ff")
    add_child(fx)
    return dir


## Монтаж «Стоп-кадр»: волна паузы пульта, затем луч сжигает замороженных.
func _fire_stopframe(prm: Dictionary, actor: Node2D, source: String, dmg: float, size: float) -> Vector2:
    var dir := _fire_remote(prm, actor, source, dmg, size)
    if dir == Vector2.ZERO:
        return Vector2.ZERO
    var k: float = dmg / float(prm["dmg"])
    var b := BeamScript.new()
    b.owner_node = actor
    b.main = self
    b.source = source
    b.dir = dir
    b.damage = float(prm["bdmg"]) * k
    b.length = float(prm["len"]) * size
    b.width = float(prm["w"]) * size
    b.duration = float(prm["dur"])
    b.ramp = float(prm["ramp"])
    b.position = actor.position
    add_child(b)
    return dir


func _fire_flashlight(prm: Dictionary, actor: Node2D, source: String, dmg: float, size: float) -> Vector2:
    var length: float = float(prm["len"]) * size
    var near := _nearest_enemies(actor.position, length, 1)
    if near.is_empty():
        return Vector2.ZERO
    var b := BeamScript.new()
    b.owner_node = actor
    b.main = self
    b.source = source
    b.dir = (near[0][1].position - actor.position).normalized()
    b.damage = dmg
    b.length = length
    b.width = float(prm["w"]) * size
    b.duration = float(prm["dur"])
    b.ramp = float(prm["ramp"])
    b.position = actor.position
    add_child(b)
    return b.dir


func _fire_popgun(prm: Dictionary, actor: Node2D, source: String, dmg: float, size: float) -> Vector2:
    var near := _nearest_enemies(actor.position, 520.0, 1)
    if near.is_empty():
        return Vector2.ZERO
    var dir1: Vector2 = (near[0][1].position - actor.position).normalized()
    var n := int(prm["count"])
    for i in n:
        var spread := (float(i) - (n - 1) / 2.0) * 0.16   # веером; при чётном числе зёрен ни одно не улетает мимо
        var k := PopKernelScript.new()
        k.position = actor.position
        k.main = self
        k.source = source
        k.vel = dir1.rotated(spread) * 520.0
        k.damage = dmg
        k.radius = float(prm["radius"]) * size
        add_child(k)
    return dir1


func _fire_pricetags(prm: Dictionary, actor: Node2D, source: String, dmg: float, size: float, lo) -> Vector2:
    var near := _nearest_enemies(actor.position, 520.0, int(prm["count"]))
    if near.is_empty():
        return Vector2.ZERO
    for item in near:
        var t := TagShotScript.new()
        t.position = actor.position
        t.main = self
        t.target = item[1]
        t.source = source
        t.damage = dmg
        t.mark_dur = float(prm["dur"]) * lo.mult("mark_time")
        t.mark_mult = float(prm["mult"])
        t.boom_r = float(prm["boom_r"]) * size
        t.boom_dmg = float(prm["boom_dmg"]) * lo.mult("damage") * _dmg_scale(source)
        t.pop_r = float(prm.get("pop_r", 0.0)) * size
        t.pop_dmg = float(prm.get("pop_dmg", 0.0)) * lo.mult("damage") * _dmg_scale(source)
        add_child(t)
    return (near[0][1].position - actor.position).normalized()


## Взрыв по области: урон всем живым врагам в радиусе + круг-эффект.
func explode_at(pos: Vector2, radius: float, dmg: float, source: String, col: Color) -> void:
    for e in get_tree().get_nodes_in_group("enemies"):
        if e.dead:
            continue
        if pos.distance_to(e.position) <= radius + e.hit_r * 0.5:
            e.hit(dmg, source)
    var fx := PulseScript.new()
    fx.position = pos
    fx.radius = radius
    fx.color = col
    fx.bars = false
    fx.life = 0.35
    add_child(fx)


func spawn_burst(pos: Vector2, col: Color) -> void:
    var b := BurstScript.new()
    b.position = pos
    b.col = col
    add_child(b)


## Осколки опыта за убитого врага: малый 1, средний 5, крупный 25 (с босса).
func spawn_shards(pos: Vector2, kind: int) -> void:
    match kind:
        4, 5:
            _drop(pos, 5)
        6:
            for i in 4:
                _drop(pos + Vector2(randf_range(-50, 50), randf_range(-70, 70)), 25)
        _:
            _drop(pos, 1)


func _drop(pos: Vector2, value: int) -> void:
    var p := PickupScript.new()
    p.position = pos
    p.value = value
    p.main = self
    p.target = player
    add_child(p)


# ---------- HUD ----------

func _build_hud() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)

    rec_dot = ColorRect.new()
    rec_dot.color = Color("ff2e2e")
    rec_dot.position = Vector2(30, 40)
    rec_dot.size = Vector2(20, 20)
    layer.add_child(rec_dot)

    hud_rec = Label.new()
    hud_rec.position = Vector2(62, 24)
    hud_rec.size = Vector2(620, 46)
    hud_rec.add_theme_font_size_override("font_size", 36)
    layer.add_child(hud_rec)

    hud_genre = Label.new()
    hud_genre.position = Vector2(30, 76)
    hud_genre.size = Vector2(520, 64)
    hud_genre.add_theme_font_size_override("font_size", 20)
    hud_genre.add_theme_color_override("font_color", Color("ff2e88"))
    layer.add_child(hud_genre)

    hud_level = Label.new()
    hud_level.position = Vector2(560, 76)
    hud_level.size = Vector2(130, 40)
    hud_level.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    hud_level.add_theme_font_size_override("font_size", 28)
    hud_level.add_theme_color_override("font_color", Color("00f0ff"))
    layer.add_child(hud_level)

    var xp_bg := ColorRect.new()
    xp_bg.color = Color(1, 1, 1, 0.15)
    xp_bg.position = Vector2(30, 142)
    xp_bg.size = Vector2(660, 14)
    layer.add_child(xp_bg)
    xp_fill = ColorRect.new()
    xp_fill.color = Color("00f0ff")
    xp_fill.position = Vector2(30, 142)
    xp_fill.size = Vector2(0, 14)
    layer.add_child(xp_fill)

    hud_loadout = HBoxContainer.new()
    hud_loadout.position = Vector2(30, 1170)
    hud_loadout.size = Vector2(660, 82)
    hud_loadout.add_theme_constant_override("separation", 3)
    hud_loadout.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(hud_loadout)

    hud_msg = Label.new()
    hud_msg.position = Vector2(0, 460)
    hud_msg.size = Vector2(720, 400)
    hud_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hud_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    hud_msg.add_theme_font_size_override("font_size", 52)
    hud_msg.add_theme_color_override("font_color", Color("00f0ff"))
    layer.add_child(hud_msg)


func _refresh_loadout_hud() -> void:
    if loadout == null:
        return
    var ids: Array = loadout.levels.keys()
    ids.sort()
    var signature := "%d|" % armor_charges
    for id in ids:
        signature += "%s:%d;" % [id, loadout.levels[id]]
    if signature == loadout_hud_signature:
        return
    loadout_hud_signature = signature
    for child in hud_loadout.get_children():
        child.queue_free()
    for i in mini(ids.size(), MAX_LOADOUT_ICONS):
        var id: String = ids[i]
        var def: Dictionary = UpgradesScript.CATALOG[id]
        var icon_index := int(def.get("icon", 21))
        var card := Control.new()
        card.custom_minimum_size = Vector2(56, 68)
        card.size = Vector2(56, 68)
        var back := ColorRect.new()
        back.position = Vector2(2, 2)
        back.size = Vector2(52, 58)
        back.color = Color(0.08, 0.04, 0.16, 0.82)
        card.add_child(back)
        var icon := TextureRect.new()
        var atlas_tex := AtlasTexture.new()
        atlas_tex.atlas = UpgradeIconAtlas
        atlas_tex.region = Rect2((icon_index % 6) * 128, int(icon_index / 6) * 128, 128, 128)
        icon.texture = atlas_tex
        icon.position = Vector2(5, 5)
        icon.size = Vector2(44, 44)
        icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        icon.tooltip_text = "%s · ур. %d" % [def["name"], loadout.level(id)]
        card.add_child(icon)
        var level_badge := Label.new()
        level_badge.text = str(loadout.level(id))
        level_badge.position = Vector2(36, 42)
        level_badge.size = Vector2(16, 20)
        level_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        level_badge.add_theme_font_size_override("font_size", 18)
        level_badge.add_theme_color_override("font_color", Color("fff44f"))
        card.add_child(level_badge)
        hud_loadout.add_child(card)


func _process(_delta: float) -> void:
    var t := int(take_time)
    var take_text := "ДУБЛЬ %02d/%d" % [take, CAMPAIGN_TAKES] if run_mode == "campaign" else "ДУБЛЬ %02d ∞" % take
    hud_rec.text = "REC  %02d:%02d   %s" % [t / 60, t % 60, take_text]
    rec_dot.visible = state == State.PLAY and fmod(Time.get_ticks_msec() / 1000.0, 1.0) < 0.5
    hud_level.text = "УР. %d" % level
    xp_fill.size.x = 660.0 * clampf(float(xp) / float(xp_need(level)), 0.0, 1.0)
    _refresh_loadout_hud()
    if is_instance_valid(player):
        var blink := invuln > 0.0 and fmod(invuln, 0.2) < 0.1
        player.modulate.a = 0.4 if blink else 1.0
    queue_redraw()


func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, ARENA), Color("ff2e88"), false, 4.0)
    if is_instance_valid(player) and player.touching:
        draw_arc(player.stick_origin, 100.0, 0.0, TAU, 40, Color(1, 1, 1, 0.25), 3.0)
        var knob: Vector2 = player.stick_origin + (player.stick_pos - player.stick_origin).limit_length(100.0)
        draw_circle(knob, 34.0, Color(1, 1, 1, 0.35))
    # «Резонанс»: связь между игроком и копией, пока они рядом
    if is_instance_valid(player) and loadout != null and state == State.PLAY and loadout.bonus("resonance") > 0.0:
        for g in get_tree().get_nodes_in_group("ghosts"):
            if player.position.distance_to(g.position) < 200.0:
                draw_line(player.position, g.position, Color(0.0, 0.94, 1.0, 0.35), 3.0)


# ---------- ввод: рестарт после смерти + отладочные клавиши (только ПК) ----------
# 1-6: герой   G: следующий жанр   B: вызвать Цензора   X: сразу получить уровень   M: подготовить пару для Монтажа   T: сразу закончить дубль (появится копия)

func _debug_montage() -> void:
    var pairs := [["cassette", "magnet"], ["bat", "flash"], ["remote", "flashlight"], ["pricetags", "popgun"]]
    var pair: Array = pairs[debug_montage_i % pairs.size()]
    debug_montage_i += 1
    loadout.levels.clear()
    for id in pair:
        loadout.levels[id] = 3
    pending.append({"key": "%d_dbg%d" % [run_seed, debug_montage_i], "title": "ТЕСТ МОНТАЖА"})


func _set_hero(hero_name: String) -> void:
    Recorder.hero = hero_name
    _start_run(run_mode)


func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_ESCAPE and state == State.DEAD:
            _on_menu_requested()
            return
        match event.keycode:
            KEY_1:
                _set_hero("clerk")
                return
            KEY_2:
                _set_hero("courier")
                return
            KEY_3:
                _set_hero("guard")
                return
            KEY_4:
                _set_hero("projectionist")
                return
            KEY_5:
                _set_hero("popcorn")
                return
            KEY_6:
                _set_hero("critic")
                return
            KEY_G:
                forced_genre = (genre + 1) % GENRES.size()
                _start_run(run_mode)
                return
            KEY_B:
                if state == State.PLAY:
                    _spawn_enemy(6)
                return
            KEY_T:
                if state == State.PLAY:
                    _finish_take()
                return
            KEY_M:
                if state == State.PLAY:
                    _debug_montage()
                return
            KEY_X:
                if state == State.PLAY:
                    add_xp(xp_need(level))
                return

    if state != State.DEAD or dead_time < 0.4:
        return
    var pressed := false
    if event is InputEventScreenTouch and event.pressed:
        pressed = true
    elif event is InputEventMouseButton and event.pressed:
        pressed = true
    elif event is InputEventKey and event.pressed:
        pressed = true
    if pressed:
        _start_run(run_mode)
