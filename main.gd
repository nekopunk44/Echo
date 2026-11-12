extends Node2D
## Главная сцена: цикл дублей, спавн врагов, опыт и выбор плёнок, HUD в стиле VHS.

# LAST_CHANCE — экран выбора после смерти с жетоном (REWIND или EJECT); REWIND — пауза между дублями
enum State { MENU, PLAY, REWIND, DEAD, PICK, BANKING, VICTORY, LAST_CHANCE }

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
const HitFxScript := preload("res://hit_fx.gd")
const PickupScript := preload("res://pickup.gd")
const LoadoutScript := preload("res://loadout.gd")
const UpgradesScript := preload("res://upgrades.gd")
const LevelUpScript := preload("res://levelup_ui.gd")
const RunMenuScript := preload("res://run_menu.gd")
const HudScript := preload("res://hud.gd")
const VhsScript := preload("res://vhs.gd")
const JuiceScript := preload("res://juice.gd")
const BackdropScript := preload("res://backdrop.gd")
const DebugKeysScript := preload("res://debug_keys.gd")
const RewindScript := preload("res://rewind.gd")
const RewindUiScript := preload("res://rewind_ui.gd")
const HeroDeathScript := preload("res://hero_death_fx.gd")

const ROUND_TIME := 30.0  # для финальной версии: 90.0
const ARENA := Vector2(720, 1280)
const GHOST_DMG := 0.6  # урон копии относительно игрока
const CAMPAIGN_TAKES := 12
const BOSS_EVERY := 3
const MAX_ACTIVE_GHOSTS := 5

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
var pending: Array = []  # очередь выборов: {"key", "title"}
var cur_pick := {}
var choices: Array = []
var run_seed := 0
var reroll_idx := 0
var rerolls_left := 1
var armor_charges := 0
var invuln := 0.0
var rewind_tokens := 0  # жетоны перемотки на руках (правила — в rewind.gd)
var rewinds_used := 0  # откатов за забег, для баланса: показывается на экране EJECT
var picks_no_weapon := 0
var bonus_rerolls := 0
var run_mode := "campaign"
var run_genre := 0
var endless_unlocked := false
var act_index := 0
var progress_path := "user://echo.cfg"  # дымовой тест подменяет, чтобы не трогать прогресс игрока

var player: CharacterBody2D
var picker
var run_menu
var rewind  # rewind.gd: жетоны и откат
var rewind_ui  # rewind_ui.gd: экран выбора после смерти
var hud
var vhs
var cam
var backdrop
var hit_fx
var genre := 0
var forced_genre := -1
var boss_spawned := false
var boss_defeated := false


func _ready() -> void:
	randomize()
	RenderingServer.set_default_clear_color(Color("1a0b2e"))
	backdrop = BackdropScript.new()
	add_child(backdrop)
	cam = JuiceScript.new()
	add_child(cam)
	hit_fx = HitFxScript.new()
	add_child(hit_fx)
	vhs = VhsScript.new()
	add_child(vhs)
	hud = HudScript.new()
	add_child(hud)
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
	rewind_ui = RewindUiScript.new()
	add_child(rewind_ui)
	rewind = RewindScript.new()
	rewind.main = self
	rewind.ui = rewind_ui
	rewind_ui.rewind_requested.connect(rewind.request_rewind)
	rewind_ui.eject_requested.connect(rewind.request_eject)
	hud.menu_requested.connect(_on_menu_requested)
	var progress := ConfigFile.new()
	if progress.load(progress_path) == OK:
		endless_unlocked = bool(progress.get_value("progress", "endless_unlocked", false))
	run_menu.show_menu(Recorder.hero, endless_unlocked)
	if OS.is_debug_build():
		var keys := DebugKeysScript.new()
		keys.main = self
		add_child(keys)


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
	rewind.reset()
	rewind_tokens = RewindScript.REWIND_TOKENS_START  # только здесь: «Продолжить» после победы жетоны сохраняет
	rewinds_used = 0
	Recorder.reset()
	run_mode = mode
	loadout = LoadoutScript.new()
	loadout.set_hero(Recorder.hero)
	loadout.add(UpgradesScript.start_weapon(Recorder.hero))  # стартовое оружие героя
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
	hud.reset_loadout()
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
		g.age = Recorder.ghosts.size() - 1 - i  # 0 = самый свежий дубль
		add_child(g)
	move_child(player, -1)  # игрок рисуется поверх копий
	Recorder.start_take(loadout.levels)
	take_time = 0.0
	spawn_timer = 1.0
	boss_spawned = false
	boss_defeated = false
	act_index = int((take - 1) / BOSS_EVERY) % ACT_RULES.size()
	genre = (run_genre + int((take - 1) / BOSS_EVERY)) % GENRES.size()
	backdrop.set_genre(genre)
	var act := act_index + 1
	var boss_tag := "  ·  БОСС" if _is_boss_take() else ""
	hud.genre_label.text = (
		"КАССЕТА: %s  ·  ЭТАП %d/4%s\n%s" % [GENRES[genre]["name"], act, boss_tag, ACT_RULES[act_index]["name"]]
	)
	state = State.PLAY
	hud.msg.text = ""
	hud.hide_eject()
	armor_charges = _armor_max()
	invuln = 0.0
	rerolls_left = 1
	cam.reset()
	if take >= 2:  # бесплатная плёнка в начале каждого нового дубля
		pending.append({"key": "%d_t%d" % [run_seed, take], "title": "СВЕЖАЯ ПЛЁНКА"})


func _clear_world() -> void:
	for group in ["enemies", "bullets", "ghosts", "fx", "pickups"]:
		for n in get_tree().get_nodes_in_group(group):
			n.queue_free()
	if hit_fx:
		hit_fx.clear()


func finish_take() -> void:
	state = State.BANKING
	bank_timer = 3.0
	player.active = false
	vhs.pulse(0.4)
	hud.msg.text = "ПЕРЕМОТКА\n\nОСКОЛКИ ВОЗВРАЩАЮТСЯ К ТЕБЕ"
	for p in get_tree().get_nodes_in_group("pickups"):
		p.target = player
		p.attracted = true


func _complete_take() -> void:
	# Страховка на случай, если осколок или жетон не успел долететь за время перемотки.
	for p in get_tree().get_nodes_in_group("pickups"):
		p.collect()
	Recorder.finish_take()
	take += 1
	state = State.REWIND
	rewind_timer = 0.8
	player.active = false
	_clear_world()
	hud.msg.text = "REWIND"


func _is_boss_take() -> bool:
	return take % BOSS_EVERY == 0


func boss_died() -> void:
	boss_defeated = true
	vhs.pulse(0.8)
	cam.shake(1.0)
	cam.hitstop(0.18)
	if run_mode == "campaign" and take == CAMPAIGN_TAKES:
		for p in get_tree().get_nodes_in_group("pickups"):
			p.collect()  # победная ветка гасит все осколки, жетон за Цензора засчитывается здесь, иначе он пропадёт
		state = State.VICTORY
		player.active = false
		endless_unlocked = true
		var progress := ConfigFile.new()
		progress.set_value("progress", "endless_unlocked", true)
		progress.save(progress_path)
		run_menu.show_victory(kills, level)
	elif state == State.PLAY:
		hud.msg.text = ""


func restart_run() -> void:
	_start_run(run_mode)


func spawn_boss() -> void:
	_spawn_enemy(6)


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
	rewind.reset()  # такт смерти мог начаться до победы: флаг не должен пережить её
	_start_take()


func _on_menu_requested() -> void:
	get_tree().paused = false
	rewind.reset()
	hud.hide_eject()
	_clear_world()
	if is_instance_valid(player):
		player.queue_free()
	Recorder.reset()
	cam.reset()
	state = State.MENU
	run_menu.show_menu(Recorder.hero, endless_unlocked)


func player_died() -> void:
	if state != State.PLAY or invuln > 0.0:
		return
	if armor_charges > 0:  # бронежилет: отбрасываем врагов и даём секунду-другую неуязвимости
		armor_charges -= 1
		invuln = 1.5
		_shockwave(player.position, 240.0)
		spawn_burst(player.position, Color("00f0ff"))
		vhs.pulse(0.7)
		cam.shake(0.5)
		cam.hitstop(0.06)
		return
	state = State.DEAD
	dead_time = 0.0
	player.active = false
	spawn_burst(player.position, Color("f4f0ff"))
	player.visible = false
	player.reset_input()  # стик пропадает с экрана: по этому видно, что управление потеряно
	# Анимация «плёнку зажевало»: узел живёт ровно такт смерти, потом queue_free() сам
	var dfd: Dictionary = player.death_frame_data()
	var dfx := HeroDeathScript.new()
	dfx.position = player.position
	dfx.hero_tex = dfd["tex"]
	dfx.hero_frames = dfd["frames"]
	dfx.hero_frame = dfd["frame"]
	dfx.hero_flip = dfd["flip"]
	dfx.hero_h = dfd["h"]
	add_child(dfx)
	vhs.pulse(1.0)
	cam.shake(0.8)
	cam.hitstop(0.12)
	rewind.on_death()  # есть жетон: такт смерти и экран выбора; нет — сразу EJECT


## Итоговый экран конца забега: тап или клавиша через 0.4 с — заново, Esc — в меню.
func show_eject() -> void:
	hud.show_eject(GENRES[genre]["name"], kills, level, take, rewinds_used)


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
	cam.reset()  # на паузе время идёт обычным ходом, тряска не застывает
	player.reset_input()
	get_tree().paused = true
	_roll_choices()
	picker.open(cur_pick["title"], choices, loadout, rerolls_left + bonus_rerolls)


func _roll_choices() -> void:
	var key: String = cur_pick["key"]
	if reroll_idx > 0:
		key += "_r%d" % reroll_idx
	choices = UpgradesScript.roll(
		loadout, key, 3, picks_no_weapon >= 3, Recorder.ghosts.size() > 0, run_mode == "endless"
	)
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
		rerolls_left -= 1  # один переброс доступен в каждом дубле
	elif bonus_rerolls > 0:
		bonus_rerolls -= 1  # черта клерка: один бесплатный пересброс за забег
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
	Recorder.record_event(id)  # копии повторят этот выбор в тот же момент
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
				spawn_timer = maxf(
					0.08, base_interval * float(ACT_RULES[act_index]["spawn"]) / (1.0 + 0.02 * (take - 1))
				)
				_spawn_enemy()
			if take_time >= ROUND_TIME:
				if not _is_boss_take() or boss_defeated:
					finish_take()
				elif hud.msg.text.is_empty():
					hud.msg.text = "ЦЕНЗОР НЕ ПОВЕРЖЕН\nЗАВЕРШИ ЭТОТ ДУБЛЬ, ЧТОБЫ ПЕРЕМАТАТЬ ПЛЁНКУ"
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
			if rewind.beat and dead_time >= rewind.DEATH_BEAT:
				rewind.open_panel()
		State.PICK, State.LAST_CHANCE:
			pass


func _spawn_enemy(force_kind: int = -1) -> void:
	var e := EnemyScript.new()
	var p := Vector2.ZERO
	match randi() % 4:
		0:
			p = Vector2(randf_range(0, ARENA.x), -60)
		1:
			p = Vector2(randf_range(0, ARENA.x), ARENA.y + 60)
		2:
			p = Vector2(-60, randf_range(0, ARENA.y))
		_:
			p = Vector2(ARENA.x + 60, randf_range(0, ARENA.y))
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
		vhs.pulse(0.6)
		cam.shake(0.35)
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
			"cassette":
				dir = _fire_cassette(prm, actor, source, dmg, size)
			"bat":
				dir = _fire_bat(prm, actor, source, dmg, size)
			"remote":
				dir = _fire_remote(prm, actor, source, dmg, size)
			"flash":
				dir = _fire_flash(prm, actor, source, dmg, size)
			"rewind":
				dir = _fire_cassette(prm, actor, source, dmg, size)
			"homerun":
				dir = _fire_bat(prm, actor, source, dmg, size)
			"stopframe":
				dir = _fire_stopframe(prm, actor, source, dmg, size)
			"clearance":
				dir = _fire_pricetags(prm, actor, source, dmg, size, lo)
			"flashlight":
				dir = _fire_flashlight(prm, actor, source, dmg, size)
			"popgun":
				dir = _fire_popgun(prm, actor, source, dmg, size)
			"pricetags":
				dir = _fire_pricetags(prm, actor, source, dmg, size, lo)
		if dir != Vector2.ZERO:
			var cd: float = float(prm["cd"]) / (lo.mult("fire_rate") * _resonance_factor(actor, source))
			if id == "flashlight":
				cd = maxf(cd, float(prm["dur"]) + 0.15)  # луч не накладывается сам на себя
			cds[id] = cd
			aim = dir
		else:
			cds[id] = 0.1  # целей нет — проверим чуть позже
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
		else:  # врагов меньше, чем кассет: лишние летят веером
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
			e.position += v.normalized() * 36.0  # отбрасывание
	var col := Color("fff44f") if source == "player" else Color("00f0ff")
	var fx := SwingScript.new()
	fx.position = actor.position
	fx.dir_angle = dir.angle()
	fx.radius = radius
	fx.arc_deg = arc
	fx.color = col
	add_child(fx)
	if prm.has("boom_r"):  # Монтаж «Хоум-ран»: ослепляющий взрыв в точке удара
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
		var spread := (float(i) - (n - 1) / 2.0) * 0.16  # веером; при чётном числе зёрен ни одно не улетает мимо
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
			rewind.drop_token(pos)
		_:
			_drop(pos, 1)


func _drop(pos: Vector2, value: int) -> void:
	var p := PickupScript.new()
	p.position = pos
	p.value = value
	p.main = self
	p.target = player
	add_child(p)


# ---------- кадр ----------


func _process(_delta: float) -> void:
	hud.show_take(take, take_time, CAMPAIGN_TAKES, run_mode == "endless", state == State.PLAY)
	hud.show_level(level, xp, xp_need(level))
	hud.show_tokens(rewind_tokens)
	hud.refresh_loadout(loadout, armor_charges)
	vhs.rewind_hold = state == State.REWIND
	if is_instance_valid(player):
		var blink := invuln > 0.0 and fmod(invuln, 0.2) < 0.1
		player.modulate = PlayerScript.INVULN_TINT if blink else Color.WHITE  # не прозрачность: героя видно всегда
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


# ---------- ввод ----------


## После смерти: тап или любая клавиша — заново, Esc или кнопка «В МЕНЮ» — в главное меню.
## Пока идёт такт смерти с жетоном, ввод игнорируется целиком: иначе тап перезапустил бы забег в обход экрана выбора.
func _input(event: InputEvent) -> void:
	if state != State.DEAD or rewind.beat or not event.is_pressed() or event.is_echo():
		return
	if (event is InputEventScreenTouch or event is InputEventMouseButton) and hud.eject_menu_hit(event.position):
		return  # кнопку меню нажмёт интерфейс
	if event is InputEventKey and event.keycode == KEY_ESCAPE:
		_on_menu_requested()
	elif (
		dead_time >= 0.4
		and (event is InputEventKey or event is InputEventMouseButton or event is InputEventScreenTouch)
	):
		_start_run(run_mode)
