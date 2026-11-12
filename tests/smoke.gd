extends Node
## Дымовой прогон для CI: играет за каждого героя несколько дублей на ускоренном времени,
## собирает все четыре «Монтажа», проверяет смерть, REWIND с жетонами, выход в меню, финал кампании и бесконечный режим.
## Запуск: godot --headless --fixed-fps 60 --path . res://tests/smoke.tscn
## Ошибки скрипта Godot только печатает, поэтому CI дополнительно ищет их в логе.

const MainScene := preload("res://main.tscn")
const UpgradesScript := preload("res://upgrades.gd")
const LoadoutScript := preload("res://loadout.gd")
const BoomerangScript := preload("res://boomerang.gd")
const EnemyScript := preload("res://enemy.gd")
const HeroDeathFxScript := preload("res://hero_death_fx.gd")

const HEROES := ["clerk", "courier", "guard", "projectionist", "popcorn", "critic"]
const TAKES_PER_HERO := 4
const MONTAGES := 4
const STEP := 1.0 / 60.0
const MAX_FRAMES := 250000
const PROGRESS_PATH := "user://smoke_progress.cfg"

var main
var frames := 0
var picks := 0
var failed := false


func _ready() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESS_PATH))
	main = MainScene.instantiate()
	main.progress_path = PROGRESS_PATH
	add_child(main)
	_run.call_deferred()


func _run() -> void:
	for hero in HEROES:
		main.run_menu.campaign_requested.emit(hero)
		_expect(main.state == main.State.PLAY, "%s: забег не начался" % hero)
		_expect(main.rewind_tokens == 1, "%s: на старте %d жетонов вместо одного" % [hero, main.rewind_tokens])
		await _play_takes(TAKES_PER_HERO)
		_expect(Recorder.ghosts.size() == TAKES_PER_HERO, "%s: записалось копий %d" % [hero, Recorder.ghosts.size()])
	await _check_montages()
	await _check_hit_fx()
	await _check_death()
	await _check_death_fx()
	await _check_rewind()
	await _check_rewind_early()
	await _check_rewind_push()
	await _check_rewind_record()
	await _check_rewind_boss()
	await _check_rewind_twice()
	await _check_tokens()
	await _check_panel()
	await _check_panel_taps()
	await _check_eject_menu_tap()
	await _check_victory()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESS_PATH))
	if failed:
		get_tree().quit(1)
		return
	print("SMOKE OK: кадров %d, выборов %d" % [frames, picks])
	get_tree().quit(0)


## Один кадр физики. Открытый выбор плёнки закрывается сразу, игрок в бою неуязвим.
func _step() -> void:
	await get_tree().physics_frame
	frames += 1
	if frames > MAX_FRAMES:
		_expect(false, "прогон не уложился в %d кадров" % MAX_FRAMES)
		get_tree().quit(1)
	if main.state == main.State.PICK:
		_pick()
	elif main.state == main.State.PLAY:
		main.invuln = maxf(main.invuln, 1.0)


func _frames(n: int) -> void:
	for i in n:
		await _step()


## Монтаж — всегда, если он есть в тройке; иначе карточки по кругу. Каждый пятый выбор — после переброса.
func _pick() -> void:
	picks += 1
	if picks % 5 == 0:
		main.picker.reroll_requested.emit()
	var choices: Array = main.choices
	var id: String = choices[picks % choices.size()]
	for c in choices:
		if UpgradesScript.CATALOG.has(c) and UpgradesScript.CATALOG[c].has("parts"):
			id = c
	main.picker.picked.emit(id)


## Играет n дублей. Опыт подкидывается раз в 4 секунды, чтобы сборка росла быстрее,
## а если Цензор не пал за 15 секунд сверх времени дубля, дубль закрывается вручную.
func _play_takes(n: int) -> void:
	var target: int = main.take + n
	var xp_timer := 0.0
	while main.take < target and not failed:
		await _step()
		if main.state != main.State.PLAY:
			continue
		xp_timer += STEP
		if xp_timer >= 4.0:
			xp_timer = 0.0
			main.add_xp(main.xp_need(main.level))
		if main.take_time > main.ROUND_TIME + 15.0:
			main.finish_take()


## Отладочная клавиша M по очереди готовит каждую пару, выбор забирает золотую карточку, Монтаж стреляет.
func _check_montages() -> void:
	main.run_menu.campaign_requested.emit("clerk")
	await _frames(5)
	for i in MONTAGES:
		await _press(KEY_M)
		await _frames(300)
		var has_montage := false
		for id in main.loadout.levels:
			has_montage = has_montage or UpgradesScript.CATALOG[id].has("parts")
		_expect(has_montage, "Монтаж %d не собрался: %s" % [i + 1, main.loadout.levels])


## Отклик на попадание: появление цифр урона, лимит буфера при частых ударах и очистка при смене дубля.
func _check_hit_fx() -> void:
	main.run_menu.campaign_requested.emit("clerk")
	await _frames(5)
	main._clear_world()
	_expect(main.hit_fx.alive_numbers() == 0, "после очистки мира остались цифры: %d" % main.hit_fx.alive_numbers())
	var e = _enemy_at(0, Vector2(360, 640))
	e.hit(1.0, "player")
	_expect(main.hit_fx.alive_numbers() > 0, "удар по врагу не создал цифру урона")
	for row in 10:
		for col in 10:
			_enemy_at(0, Vector2(100.0 + col * 40.0, 200.0 + row * 40.0)).hit(1.0, "player")
	var max_num: int = main.hit_fx.MAX_NUMBERS
	_expect(
		main.hit_fx.alive_numbers() <= max_num,
		"100 ударов переполнили буфер: %d > %d" % [main.hit_fx.alive_numbers(), max_num]
	)
	main._clear_world()
	_expect(
		main.hit_fx.alive_numbers() == 0, "после _clear_world() цифры не сбросились: %d" % main.hit_fx.alive_numbers()
	)


## Смерть без жетонов идёт по-старому: сразу EJECT, тап или клавиша через 0.4 с — заново, Esc — в меню.
func _check_death() -> void:
	main.run_menu.campaign_requested.emit("guard")
	await _frames(30)
	main.rewind_tokens = 0
	_kill_player()
	_expect(main.state == main.State.DEAD, "игрок не погиб")
	_expect(_eject_shown(), "без жетонов нет экрана EJECT")
	_check_eject_layout()
	await _frames(60)  # хитстоп смерти + 0.4 с защиты от случайного тапа
	await _press(KEY_SPACE)
	_expect(main.state == main.State.PLAY and main.take == 1, "после смерти забег не начался заново")
	_expect(not main.hud.eject_root.visible, "экран EJECT остался после нового забега")
	_expect(main.rewind_tokens == 1, "новый забег начался с %d жетонами вместо одного" % main.rewind_tokens)
	await _frames(30)
	main.rewind_tokens = 0
	_kill_player()
	await _press(KEY_ESCAPE)
	_expect(main.state == main.State.MENU, "Esc после смерти не вернул в меню")


## Анимация смерти «плёнку зажевало»: в группе fx появляется узел с HeroDeathFxScript,
## через 0.7 с он исчезает, герой при этом невидим.
func _check_death_fx() -> void:
	main.run_menu.campaign_requested.emit("clerk")
	await _frames(30)
	main.rewind_tokens = 0
	_kill_player()
	_expect(main.state == main.State.DEAD, "death_fx: игрок не погиб")
	# Узел эффекта должен появиться в группе fx сразу после смерти
	var fx_nodes := get_tree().get_nodes_in_group("fx")
	var has_dfx := false
	for n in fx_nodes:
		if n.get_script() == HeroDeathFxScript:
			has_dfx = true
			break
	_expect(has_dfx, "death_fx: узел hero_death_fx не появился в группе fx")
	_expect(not main.player.visible, "death_fx: герой виден сразу после смерти")
	# Ждём 0.7 с игрового времени (42 кадра при 60 fps): DEATH_BEAT=0.5, запас для queue_free()
	await _frames(42)
	var still_alive := false
	for n in get_tree().get_nodes_in_group("fx"):
		if n.get_script() == HeroDeathFxScript:
			still_alive = true
			break
	_expect(not still_alive, "death_fx: узел hero_death_fx не удалился через 0.7 с")
	_expect(not main.player.visible, "death_fx: герой стал видимым раньше отката")
	# Возвращаемся в меню, как делает _check_death() — не ломаем следующие проверки
	await _press(KEY_ESCAPE)
	_expect(main.state == main.State.MENU, "death_fx: Esc не вернул в меню после проверки")


## REWIND на третьем дубле с двумя копиями: экран выбора, защита от случайного нажатия, откат записи, героя,
## копий, снарядов и неуязвимость, выбор плёнки в очереди, двойной ввод.
func _check_rewind() -> void:
	main.run_menu.campaign_requested.emit("guard")
	# Герой «ходит» по уникальным точкам: иначе проверки позиций копий ничего не докажут.
	await _walk_until(120)  # дубль 1: короткая запись, короче точки отката
	await _next_take()
	await _walk_until(100)
	main.loadout.add("magnet")  # выборы плёнок внутри дубля: одно до точки отката, другое после неё
	Recorder.record_event("magnet")
	await _walk_until(380)
	main.loadout.add("armor")
	Recorder.record_event("armor")
	await _walk_until(396)
	await _next_take()
	await _walk_until(500)
	main.loadout.add("magnet")  # выбор в стёртых секундах: после отката он переедет на тик отката, а не пропадёт
	Recorder.record_event("magnet")
	await _walk_until(640)
	_expect(Recorder.ghosts.size() == 2 and get_tree().get_nodes_in_group("ghosts").size() == 2, "нет двух копий")
	main.rewind_tokens = 2
	main.pending.append({"key": "smoke_pending", "title": "ТЕСТ"})  # выбор, набранный перед смертью
	_kill_player()
	_expect(main.state == main.State.DEAD, "с жетоном смерть не открыла такт")
	_expect(not main.hud.eject_root.visible, "в такте смерти уже есть экран EJECT")
	await _press(KEY_ESCAPE)  # в такте ввод игнорируется целиком: Esc не должен вести в меню
	_expect(main.state == main.State.DEAD, "ввод в такте смерти сработал, state=%d" % main.state)
	await _frames(60)
	_expect(main.state == main.State.LAST_CHANCE and get_tree().paused, "после такта нет экрана выбора")
	_expect(Engine.time_scale == 1.0 and main.rewind_tokens == 2, "экран выбора: темп или жетоны")
	_expect(main.pending.size() == 1 and main.state != main.State.PICK, "выбор плёнки открылся поверх экрана")
	var ghost_idx := _ghost_idx()

	# Защита от случайного нажатия: пока идёт блокировка, ничего не срабатывает.
	_expect(main.rewind_ui.is_locked(), "панель не заблокирована сразу после открытия")
	main.rewind_ui.rewind_requested.emit()
	main.rewind_ui.eject_requested.emit()
	await _press(KEY_SPACE)
	await _press(KEY_ESCAPE)
	_expect(main.state == main.State.LAST_CHANCE and main.rewind_tokens == 2, "блокировка пропустила нажатие")
	_expect(main.rewinds_used == 0, "блокировка пропустила откат")
	await _frames(60)  # блокировка снята; копии на паузе стоят
	_expect(not main.rewind_ui.is_locked(), "блокировка не снялась")
	_expect(_ghost_idx() == ghost_idx, "копии двигались, пока висит экран выбора")

	# Откат: снимок мира до, проверки сразу после выбора, до следующего кадра.
	main.spawn_shards(Vector2(60, 1200), 0)  # осколок далеко от героя
	var boomerang := BoomerangScript.new()
	boomerang.owner_node = main.player
	boomerang.position = Vector2(300, 400)
	main.add_child(boomerang)
	var snap := _world_snapshot()
	var n: int = Recorder.current.size()
	var t0: float = main.take_time
	main.rewind_ui.rewind_requested.emit()
	main.rewind_ui.rewind_requested.emit()  # двойной тап
	var cut: int = main.rewind.cut_ticks()
	_expect(cut == 300, "откат %d тиков вместо 300" % cut)
	_expect(main.state == main.State.PLAY and not get_tree().paused, "после REWIND нет игры")
	_expect(main.rewind_tokens == 1 and main.rewinds_used == 1, "двойной ввод: жетонов %d" % main.rewind_tokens)
	_expect(
		Recorder.current.size() == n - 300 and Recorder.recording, "запись %d после отката" % Recorder.current.size()
	)
	_expect(main.player.position == Recorder.current[-1], "герой не в точке отката")
	_expect(main.player.visible and main.player.active, "герой скрыт или не слушается после отката")
	_expect(absf(main.take_time - (t0 - 5.0)) < 0.02, "время дубля %f вместо %f" % [main.take_time, t0 - 5.0])
	_expect(not main.hud.eject_root.visible, "после отката остался экран EJECT")
	_expect(main.invuln >= main.rewind.REWIND_INVULN - 0.05, "после отката нет неуязвимости")
	main.player_died()
	_expect(main.state == main.State.PLAY, "неуязвимый герой погиб")
	_expect(get_tree().get_nodes_in_group("bullets").is_empty(), "снаряды стёртых секунд остались")
	var after := _world_snapshot()
	for key in ["xp", "level", "kills", "levels", "pickups"]:
		_expect(after[key] == snap[key], "откат изменил %s: %s -> %s" % [key, snap[key], after[key]])
	_check_ghosts_after_rewind(Recorder.current.size())
	var moved := Recorder.current_events.filter(func(ev): return ev[1] == "magnet" and ev[0] == n - 300)
	_expect(moved.size() == 1, "выбор из стёртых секунд не переехал на тик отката")

	# Выбор плёнки из очереди открывается первым же кадром, неуязвимость он не съедает.
	await get_tree().physics_frame
	await get_tree().physics_frame
	_expect(main.state == main.State.PICK, "выбор из очереди не открылся после отката")
	var pick: String = main.choices[0]
	main.picker.picked.emit(pick)
	_expect(main.state == main.State.PLAY, "после выбора плёнки нет игры")
	_expect(main.invuln >= main.rewind.REWIND_INVULN - 0.05, "выбор плёнки съел неуязвимость")
	for ev in Recorder.current_events:
		_expect(ev[0] <= Recorder.current.size(), "событие на тике %d позже конца записи" % ev[0])
	if pick != "intermission":
		_expect(Recorder.current_events.back()[0] == Recorder.current.size(), "выбор записан не на тик отката")

	# Неуязвимость длится REWIND_INVULN: свой цикл без _step(), он бы её продлевал.
	var ticks := 0
	for guard in 1200:
		if main.invuln <= 0.0:
			break
		await get_tree().physics_frame
		if main.state == main.State.PICK:
			_pick()
		elif main.state == main.State.PLAY:
			ticks += 1
	_expect(main.invuln == 0.0, "неуязвимость не кончилась")
	var expected_ticks := roundi(main.rewind.REWIND_INVULN * 60.0)
	_expect(absi(ticks - expected_ticks) <= 3, "неуязвимость шла %d тиков вместо %d" % [ticks, expected_ticks])
	if main.state == main.State.PLAY:
		_kill_player()  # броню плёнок тест снимает сам: она бы отбила касание
		_expect(main.state != main.State.PLAY, "без неуязвимости герой не погиб")


## Смерть в первые 5 секунд: откат до нуля, герой в центре; два отката подряд, второй с клавиатуры.
func _check_rewind_early() -> void:
	main.run_menu.campaign_requested.emit("guard")
	main.rewind_tokens = 2
	await _frames(120)
	await _to_panel()
	main.rewind_ui.rewind_requested.emit()
	_expect(main.state == main.State.PLAY, "ранний REWIND не вернул в игру")
	_expect(Recorder.current.size() == 0, "запись %d вместо пустой" % Recorder.current.size())
	_expect(main.take_time == 0.0, "время дубля %f вместо нуля" % main.take_time)
	_expect(main.player.position == main.ARENA / 2.0, "герой не в центре арены")
	await _frames(60)
	_expect(Recorder.current.size() >= 50, "запись не растёт после раннего отката: %d" % Recorder.current.size())
	await _to_panel()
	await _press(KEY_R)
	_expect(main.state == main.State.PLAY and main.rewinds_used == 2, "REWIND с клавиатуры не сработал")
	_expect(main.rewind_tokens == 0, "жетонов %d после двух откатов" % main.rewind_tokens)


## Отталкивание: враги в радиусе отлетают от нового места героя, Цензор слабее остальных, дальние стоят.
## Урона и потерь нет. Проверки идут сразу после выбора REWIND, до следующего кадра: потом враги пойдут сами.
func _check_rewind_push() -> void:
	main.run_menu.campaign_requested.emit("guard")
	await _walk_until(420)
	await _to_panel()
	var n: int = Recorder.current.size()
	var center: Vector2 = Recorder.current[n - 301]  # точка отката: срез ровно 300 тиков
	var radius: float = main.rewind.REWIND_PUSH_RADIUS
	var dist: float = main.rewind.REWIND_PUSH_DIST
	var boss_dist: float = dist * main.rewind.BOSS_PUSH_FACTOR
	var on_hero = _enemy_at(0, center)  # ровно в точке героя: normalized() даёт нуль, направление случайное
	var near = _enemy_at(0, center + Vector2(30.0, 0.0))
	var mid = _enemy_at(0, center + Vector2(0.0, 150.0))
	var boss = _enemy_at(6, center + Vector2(-100.0, 0.0))
	var far = _enemy_at(0, center + Vector2(radius + 80.0, 0.0))  # за радиусом: стоит на месте
	var count: int = get_tree().get_nodes_in_group("enemies").size()
	var hp_before := _enemy_hp()
	var boss_from: Vector2 = boss.position
	var far_from: Vector2 = far.position
	main.rewind_ui.rewind_requested.emit()
	_expect(main.state == main.State.PLAY, "отталкивание: после REWIND нет игры")
	_expect(main.player.position == center, "отталкивание: герой не в точке отката")
	for pair in [["на герое", on_hero], ["в 30 px", near], ["в 150 px", mid]]:
		var gap: float = pair[1].position.distance_to(center)
		_expect(gap >= dist - 5.0, "враг %s отброшен на %d px вместо %d" % [pair[0], gap, dist])
	var boss_shift: float = boss.position.distance_to(boss_from)
	_expect(absf(boss_shift - boss_dist) <= 5.0, "Цензор сдвинут на %d px вместо %d" % [boss_shift, boss_dist])
	_expect(far.position == far_from, "враг за радиусом отката сдвинут")
	_expect(get_tree().get_nodes_in_group("enemies").size() == count, "откат изменил число врагов")
	_expect(_enemy_hp() == hp_before, "откат изменил здоровье врагов: отталкивание не должно бить и лечить")


## Запись после отката: выбор из стёртых секунд переезжает на тик отката, выбор до него остаётся на месте,
## а пути к смерти в записи нет. Герой на один тик встаёт в (5, 5): сам игрок туда не попадает (player.gd клампит).
func _check_rewind_record() -> void:
	main.run_menu.campaign_requested.emit("guard")
	await _walk_until(250)
	Recorder.record_event("magnet")  # до точки отката: тик не меняется
	await _walk_until(500)
	main.player.position = Vector2(5.0, 5.0)
	await _step()
	await _walk_until(620)
	Recorder.record_event("armor")  # в стёртых секундах: переедет на тик отката
	var n: int = Recorder.current.size()
	var new_n := n - 300
	_expect(Recorder.current.has(Vector2(5.0, 5.0)), "в записи до смерти нет точки (5, 5): проверка ничего не докажет")
	await _to_panel()
	main.rewind_ui.rewind_requested.emit()
	_expect(Recorder.current.size() == new_n, "запись %d вместо %d" % [Recorder.current.size(), new_n])
	_expect(not Recorder.current.has(Vector2(5.0, 5.0)), "срезанный кусок остался в записи")
	var ticks := {}
	for ev in Recorder.current_events:
		ticks[ev[1]] = ev[0]
		_expect(ev[0] <= Recorder.current.size(), "событие %s на тике %d позже конца записи" % [ev[1], ev[0]])
	_expect(ticks.get("magnet", -1) == 250, "выбор до точки отката сдвинут: %s" % ticks.get("magnet"))
	_expect(
		ticks.get("armor", -1) == new_n, "выбор из стёртых секунд на тике %s вместо %d" % [ticks.get("armor"), new_n]
	)
	await _next_take()  # дубль доигран: запись превращается в копию
	_expect(not Recorder.ghosts.is_empty(), "дубль после отката не закончился: копии нет")
	if Recorder.ghosts.is_empty():
		return
	var saved: Dictionary = Recorder.ghosts.back()
	_expect(not saved["path"].has(Vector2(5.0, 5.0)), "в копии есть путь к смерти")
	_expect(saved["path"].size() >= new_n, "путь копии %d короче точки отката %d" % [saved["path"].size(), new_n])
	for ev in saved["events"]:
		_expect(ev[0] <= saved["path"].size(), "в копии событие на тике %d позже конца пути" % ev[0])


## REWIND на босс-дубле, когда дубль перерос 30 секунд: Цензор тот же, один, не вылеченный и не вызванный заново,
## победа не засчитана, а «ЦЕНЗОР НЕ ПОВЕРЖЕН» откат стирает и она возвращается, когда время дойдёт до 30.
func _check_rewind_boss() -> void:
	main.run_menu.campaign_requested.emit("guard")
	await _frames(5)
	main.take = main.BOSS_EVERY - 1
	await _next_take()
	_expect(main.take == main.BOSS_EVERY, "не дошли до босс-дубля")
	var boss = null
	while boss == null and not failed:
		await _step()
		boss = _find_boss()
	if boss == null:
		return
	boss.hp = 5000.0  # герой его не убьёт: победа в этой проверке не нужна
	await _walk_until(420)
	main.take_time = main.ROUND_TIME + 2.0  # дубль в «сверхурочных»: Цензор жив, время вышло, откат вернёт до 30
	await _frames(2)
	_expect("ЦЕНЗОР" in main.hud.msg.text, "в сверхурочных нет «ЦЕНЗОР НЕ ПОВЕРЖЕН»: проверка ничего не докажет")
	await _to_panel()
	var hp_before: float = boss.hp
	var t0: float = main.take_time
	main.rewind_ui.rewind_requested.emit()
	_expect(main.state == main.State.PLAY, "босс-дубль: после REWIND нет игры")
	_expect(_boss_count() == 1 and _find_boss() == boss, "после отката Цензоров %d, а не тот же один" % _boss_count())
	_expect(main.boss_spawned and not main.boss_defeated, "откат изменил состояние босса")
	_expect(boss.hp <= hp_before and not boss.dead, "Цензор вылечен или убит откатом: %f -> %f" % [hp_before, boss.hp])
	_expect(main.hud.msg.text.is_empty(), "после отката осталась надпись «%s»" % main.hud.msg.text)
	_expect(main.take_time < main.ROUND_TIME and absf(main.take_time - (t0 - 5.0)) < 0.02, "время дубля после отката")
	await _frames(150)  # время дубля ещё меньше 30, но Цензор не должен появиться второй раз
	_expect(_boss_count() == 1, "за секунды после отката Цензоров %d" % _boss_count())
	await _walk_until(Recorder.current.size() + 330)
	_expect("ЦЕНЗОР" in main.hud.msg.text, "время дошло до 30, а надписи «ЦЕНЗОР НЕ ПОВЕРЖЕН» нет")
	_expect(_boss_count() == 1, "к концу дубля Цензоров %d" % _boss_count())


## Две перемотки подряд: второй откат идёт от укороченной и дописанной записи, а не от исходной.
func _check_rewind_twice() -> void:
	main.run_menu.campaign_requested.emit("guard")
	await _walk_until(100)
	await _next_take()  # одна копия: сверяем и её
	await _walk_until(600)
	main.rewind_tokens = 2
	await _to_panel()
	main.rewind_ui.rewind_requested.emit()
	_expect(main.state == main.State.PLAY and main.rewinds_used == 1, "первый откат не сработал")
	await _frames(200)
	var n2: int = Recorder.current.size()
	_expect(n2 >= 300 + 150, "запись не растёт между откатами: %d" % n2)  # было 600 - 300, плюс игровые кадры
	var t2: float = main.take_time
	await _to_panel()
	main.rewind_ui.rewind_requested.emit()
	_expect(main.state == main.State.PLAY and not get_tree().paused, "второй откат не вернул в игру")
	_expect(
		main.rewinds_used == 2 and main.rewind_tokens == 0,
		"перемоток %d, жетонов %d" % [main.rewinds_used, main.rewind_tokens]
	)
	var new_n: int = Recorder.current.size()
	_expect(new_n == maxi(0, n2 - 300), "запись %d после второго отката вместо %d" % [new_n, maxi(0, n2 - 300)])
	_expect(new_n == 0 or main.player.position == Recorder.current[new_n - 1], "герой не в точке второго отката")
	_expect(absf(main.take_time - (t2 - 5.0)) < 0.02, "время дубля после второго отката")
	_check_ghosts_after_rewind(new_n, 1)
	await _frames(30)
	# Не ровно 30: кадр, в котором открылся выбор плёнки за уровень, в запись не попадает.
	var grown: int = Recorder.current.size() - new_n
	_expect(grown >= 20 and grown <= 30, "после второго отката запись выросла на %d за 30 кадров" % grown)


## Жетон за Цензора: падает на землю, подбирается, не выше запаса; жетон с земли спасает от смерти.
func _check_tokens() -> void:
	main.run_menu.campaign_requested.emit("clerk")
	await _frames(5)
	main.rewind_tokens = 0
	await _kill_boss()
	var tokens := _ground_tokens()
	_expect(tokens.size() == 1, "Цензор уронил %d жетонов вместо одного" % tokens.size())
	if tokens.size() == 1:  # Цензор падает за краем арены: подвинем жетон в радиус магнита героя
		tokens[0].position = main.player.position + Vector2(60, 0)
	await _frames(40)  # хитстоп смерти босса: первые ~11 кадров мир почти стоит
	_expect(main.rewind_tokens == 1, "жетон не подобрался: %d" % main.rewind_tokens)
	main.rewind_tokens = 2
	await _kill_boss()
	_expect(_ground_tokens().is_empty(), "при полном запасе Цензор уронил жетон")
	main.rewind_tokens = 1
	await _kill_boss()
	await _kill_boss()  # на руках 1 и на земле 1: запас заполнен, второй жетон не падает
	_expect(_ground_tokens().size() == 1, "жетонов на земле %d вместо одного" % _ground_tokens().size())
	main.rewind_tokens = 0
	for i in 3:
		main.rewind.grant_token()
	_expect(main.rewind_tokens == main.rewind.REWIND_TOKENS_MAX, "запас жетонов вышел за максимум")
	for p in get_tree().get_nodes_in_group("pickups"):  # убираем лишнее: ниже ровно один жетон на земле
		p.queue_free()
	await _frames(2)
	main.rewind_tokens = 0
	await _kill_boss()
	_expect(_ground_tokens().size() == 1, "жетона для проверки смерти нет на земле")
	_kill_player()
	_expect(main.rewind_tokens == 1, "жетон с земли не засчитан в момент смерти")
	await _frames(60)
	_expect(main.state == main.State.LAST_CHANCE, "жетон с земли не открыл экран выбора")


## Выходы с экрана выбора: EJECT, меню и перезапуск забега. Заодно — бесконечный режим даёт один жетон.
func _check_panel() -> void:
	main.run_menu.endless_requested.emit("critic")
	_expect(main.rewind_tokens == 1, "бесконечный режим начался с %d жетонами" % main.rewind_tokens)
	await _frames(10)
	_kill_player()
	_expect(main.state == main.State.DEAD, "нет такта смерти")
	await _frames(60)
	_expect(main.state == main.State.LAST_CHANCE, "нет экрана выбора")
	_expect(main.rewind_ui.keys_label.visible, "на ПК нет подсказки про клавиши панели")
	await _frames(50)
	await _press(KEY_ESCAPE)  # EJECT с клавиатуры; тот же Esc не должен сразу вести в меню
	_expect(main.state == main.State.DEAD and not get_tree().paused, "EJECT не закончил забег")
	_expect(_eject_shown(), "на экране EJECT нет строк")
	_expect(main.rewind_tokens == 1, "EJECT потратил жетон")
	await _frames(60)
	await _press(KEY_SPACE)
	_expect(main.state == main.State.PLAY and main.rewind_tokens == 1, "после EJECT забег не начался заново")
	await _to_panel()
	main._on_menu_requested()
	_expect(main.state == main.State.MENU and not get_tree().paused, "выход в меню не снял паузу")
	_expect(not main.rewind_ui.is_open(), "панель осталась после выхода в меню")
	main.run_menu.campaign_requested.emit("critic")
	await _frames(5)
	await _to_panel()
	main.restart_run()
	_expect(main.state == main.State.PLAY and not get_tree().paused, "перезапуск не снял паузу")
	_expect(not main.rewind_ui.is_open(), "панель осталась после перезапуска")


## Касания по настоящим кнопкам панели, как на телефоне (остальные проверки шлют сигналы в обход кнопок):
## кнопки крупные, в такте смерти и во время блокировки тап ничего не делает, мимо кнопок — тоже,
## а тап по EJECT не перезапускает забег сам.
func _check_panel_taps() -> void:
	main.run_menu.campaign_requested.emit("guard")
	await _walk_until(400)
	var n: int = Recorder.current.size()
	_kill_player()
	while main.dead_time < 0.42 and main.state == main.State.DEAD:  # конец такта: защита по времени (0.4 с) уже снята
		await _step()
	await _tap(Vector2(360.0, 1000.0))  # в такте тап не перезапускает забег
	var in_beat: bool = main.state == main.State.DEAD or main.state == main.State.LAST_CHANCE
	_expect(in_beat and Recorder.current.size() == n, "тап в такте смерти: state=%d" % main.state)
	var guard := 0
	while main.state != main.State.LAST_CHANCE and guard < 90:
		await _step()
		guard += 1
	_expect(main.state == main.State.LAST_CHANCE, "экран выбора не открылся")
	var rewind_button: Button = main.rewind_ui.rewind_button
	var eject_button: Button = main.rewind_ui.eject_button
	_expect(rewind_button.size.y >= 88.0 and eject_button.size.y >= 88.0, "кнопка панели ниже 88 px")
	await _tap(rewind_button.get_global_rect().get_center())  # блокировка ещё идёт
	await _tap(eject_button.get_global_rect().get_center())
	_expect(main.state == main.State.LAST_CHANCE, "тап по кнопке во время блокировки сработал")
	await _frames(50)
	await _tap(Vector2(360.0, 1000.0))  # мимо кнопок
	await _tap(Vector2(60.0, 300.0))
	_expect(main.state == main.State.LAST_CHANCE and main.rewind_tokens == 1, "тап мимо кнопок что-то сделал")
	await _tap(eject_button.get_global_rect().get_center())
	_expect(main.state == main.State.DEAD and not get_tree().paused, "тап по EJECT не закончил забег")
	_expect(main.hud.eject_root.visible and main.rewind_tokens == 1, "после тапа по EJECT нет итогов или нет жетона")
	await _frames(40)  # тап по EJECT сам забег не перезапускает
	_expect(main.state == main.State.DEAD, "забег перезапустился сам после тапа по EJECT")
	await _tap(Vector2(360.0, 1000.0))
	_expect(main.state == main.State.PLAY and main.take == 1, "тап на экране EJECT не начал забег заново")
	await _walk_until(400)
	main.rewind_tokens = 1
	await _to_panel()
	n = Recorder.current.size()
	await _tap(rewind_button.get_global_rect().get_center())
	_expect(main.state == main.State.PLAY and not get_tree().paused, "тап по REWIND не вернул в игру")
	_expect(main.rewind_tokens == 0 and main.rewinds_used == 1, "тап по REWIND: жетонов %d" % main.rewind_tokens)
	var tail := Recorder.current.size() - (n - 300)  # после отпускания пальца _tap() прокрутил пару кадров
	_expect(tail >= 0 and tail <= 4, "тап по REWIND: запись %d вместо %d" % [Recorder.current.size(), n - 300])
	_expect(not main.player.touching, "после тапа по REWIND виртуальный стик остался зажатым")


## Последний дубль кампании: Цензор повержен — победа, затем продолжение в бесконечном режиме.
func _check_victory() -> void:
	main.run_menu.campaign_requested.emit("critic")
	await _frames(10)
	main.take = main.CAMPAIGN_TAKES - 1
	main.finish_take()
	while main.take < main.CAMPAIGN_TAKES or main.state != main.State.PLAY:
		await _step()
	var boss = null
	while boss == null and not failed:
		await _step()
		boss = _find_boss()
	if boss == null:
		return
	var tokens_before: int = main.rewind_tokens
	boss.hit(1e9, "player")
	await _frames(5)
	_expect(main.state == main.State.VICTORY, "после финального Цензора нет победы")
	_expect(main.endless_unlocked, "бесконечный режим не открылся")
	var tokens_after: int = main.rewind_tokens
	_expect(tokens_after == mini(main.rewind.REWIND_TOKENS_MAX, tokens_before + 1), "жетон за финал: %d" % tokens_after)
	main.run_menu.endless_continue_requested.emit()
	_expect(main.rewind_tokens == tokens_after, "«Продолжить» изменило жетоны")
	_expect(main.run_mode == "endless" and main.take == main.CAMPAIGN_TAKES + 1, "бесконечный режим не продолжился")
	await _play_takes(3)


func _find_boss():
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.kind == 6 and not e.dead:
			return e
	return null


## Герой «ходит» по точкам, которые не повторяются: иначе проверки позиций копий ничего не докажут.
func _walk_point(k: int) -> Vector2:
	return Vector2(40.0 + float(k % 640), 300.0 + float(floori(k / 640.0)) * 40.0)


## Играет, пока в записи не станет size тиков; выбор плёнки и неуязвимость — как в _step().
func _walk_until(size: int) -> void:
	while Recorder.current.size() < size and not failed:
		await _step()
		if main.state == main.State.PLAY:
			main.player.position = _walk_point(Recorder.current.size())


## Закрывает дубль и ждёт начала следующего: копия записанного дубля появляется на старте.
func _next_take() -> void:
	var target: int = main.take + 1
	main.finish_take()
	while (main.take < target or main.state != main.State.PLAY) and not failed:
		await _step()


## Смерть героя и ожидание экрана выбора вместе с концом блокировки кнопок.
func _to_panel() -> void:
	_kill_player()
	var guard := 0
	while main.state != main.State.LAST_CHANCE and guard < 90:
		await _step()
		guard += 1
	_expect(main.state == main.State.LAST_CHANCE, "экран выбора не открылся за 90 кадров")
	await _frames(50)  # блокировка кнопок 0.7 с = 42 тика
	_expect(not main.rewind_ui.is_locked(), "блокировка кнопок не снялась")


## Появляется Цензор и сразу погибает: на земле остаются его осколки и, если есть место, жетон.
func _kill_boss() -> void:
	main.player.position = main.ARENA / 2.0  # подальше от края: жетон не подберётся сам
	main.spawn_boss()
	await _step()
	var boss = _find_boss()
	_expect(boss != null, "Цензор не появился")
	if boss != null:
		boss.hit(1e9, "player")
	await _step()


## Враг заданного вида в точке: здоровье с запасом, чтобы случайный выстрел героя его не убил.
func _enemy_at(kind: int, pos: Vector2):
	var e = EnemyScript.new()
	e.kind = kind
	e.hp = 500.0
	e.position = pos
	e.target = main.player
	e.main = main
	main.add_child(e)
	return e


func _enemy_hp() -> Dictionary:
	var hp := {}
	for e in get_tree().get_nodes_in_group("enemies"):
		hp[e.get_instance_id()] = e.hp
	return hp


func _boss_count() -> int:
	var count := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.kind == 6 and not e.dead:
			count += 1
	return count


## Касание пальцем в точке экрана: как на Android, пара «касание + мышь» в координатах окна игры.
func _tap(pos: Vector2) -> void:
	for pressed in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		touch.position = pos
		touch.pressed = pressed
		get_viewport().push_input(touch, true)
		var mouse := InputEventMouseButton.new()
		mouse.button_index = MOUSE_BUTTON_LEFT
		mouse.position = pos
		mouse.global_position = pos
		mouse.pressed = pressed
		mouse.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		get_viewport().push_input(mouse, true)
		await _frames(2)


func _ground_tokens() -> Array:
	var tokens: Array = []
	for p in get_tree().get_nodes_in_group("pickups"):
		if p.is_token and not p.collected:
			tokens.append(p)
	return tokens


func _ghost_idx() -> Array:
	var idx: Array = []
	for g in get_tree().get_nodes_in_group("ghosts"):
		idx.append(g.idx)
	return idx


## То, что REWIND откатывать не должен: опыт, уровень, убийства, сборка героя, осколки на земле.
func _world_snapshot() -> Dictionary:
	return {
		"xp": main.xp,
		"level": main.level,
		"kills": main.kills,
		"levels": main.loadout.levels.duplicate(),
		"pickups": get_tree().get_nodes_in_group("pickups").size(),
	}


## Копии после отката: тик, позиция и сборка. Сборку тест пересобирает сам: начало дубля плюс события до тика.
func _check_ghosts_after_rewind(new_n: int, count: int = 2) -> void:
	var ghosts := get_tree().get_nodes_in_group("ghosts")
	_expect(ghosts.size() == count, "после отката %d копий вместо %d" % [ghosts.size(), count])
	for g in ghosts:
		_expect(g.idx == new_n, "копия на тике %d вместо %d" % [g.idx, new_n])
		var last := mini(g.idx, g.path.size())
		if last > 0:
			_expect(g.position == g.path[last - 1], "копия не на записанной точке пути")
		var lo = LoadoutScript.new()
		lo.levels = g.start_levels.duplicate()
		for ev in g.events:
			if ev[0] <= g.idx:
				lo.add(ev[1])
		_expect(g.lo.levels == lo.levels, "сборка копии %s вместо %s" % [g.lo.levels, lo.levels])
		_expect(g.cds.is_empty(), "перезарядки копии не сброшены")


## Экран EJECT виден: слово EJECT и строка «перемоток» (раньше их искали в hud.msg.text).
func _eject_shown() -> bool:
	var hud = main.hud
	return hud.eject_root.visible and "EJECT" in hud.eject_title.text and "перемоток" in hud.eject_rewinds.text


## Каждая строка итогов влезает в экран целиком, даже на длинных числах; кнопка меню есть везде, Esc — только на ПК.
func _check_eject_layout() -> void:
	var hud = main.hud
	hud.show_eject("КИБЕРПАНК", 99999, 99, 36, 99)
	for l in [
		hud.eject_title, hud.eject_tape, hud.eject_stats, hud.eject_rewinds, hud.eject_hint, hud.eject_menu_button
	]:
		var font: Font = l.get_theme_font("font")
		var font_px: int = l.get_theme_font_size("font_size")
		var width := font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px).x
		_expect(width <= 640.0, "строка EJECT «%s» шире экрана: %d px" % [l.text, width])
	_expect("ESC" in hud.eject_menu_button.text, "на ПК кнопка меню не подсказывает Esc")
	hud.phone = true
	main.show_eject()
	_expect(hud.eject_menu_button.visible, "на телефоне нет кнопки меню на экране EJECT")
	_expect(not "ESC" in hud.eject_menu_button.text, "на телефоне кнопка меню подсказывает Esc")
	hud.phone = false
	main.show_eject()


## Телефон: с экрана EJECT в меню ведёт кнопка. Тап по ней не перезапускает забег, тап мимо — перезапускает.
func _check_eject_menu_tap() -> void:
	main.run_menu.campaign_requested.emit("clerk")
	await _frames(30)
	main.rewind_tokens = 0
	_kill_player()
	await _frames(60)
	var button: Button = main.hud.eject_menu_button
	await _tap(button.get_global_rect().get_center())
	_expect(main.state == main.State.MENU, "тап по кнопке меню на EJECT не вернул в меню: %s" % main.state)
	_expect(not main.hud.eject_root.visible, "экран EJECT остался в меню")
	main.run_menu.campaign_requested.emit("clerk")
	await _frames(30)
	main.rewind_tokens = 0
	_kill_player()
	await _frames(60)
	await _tap(Vector2(360, 300))
	_expect(main.state == main.State.PLAY, "тап мимо кнопки меню не начал забег заново")


func _kill_player() -> void:
	main.invuln = 0.0
	main.armor_charges = 0
	main.player_died()


func _press(keycode: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.pressed = true
	Input.parse_input_event(ev)
	await _step()
	var up := InputEventKey.new()
	up.keycode = keycode
	Input.parse_input_event(up)
	await _step()


func _expect(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error("SMOKE FAIL: " + message)
