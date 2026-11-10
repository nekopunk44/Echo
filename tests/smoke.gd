extends Node
## Дымовой прогон для CI: играет за каждого героя несколько дублей на ускоренном времени,
## собирает все четыре «Монтажа», проверяет смерть, выход в меню, финал кампании и бесконечный режим.
## Запуск: godot --headless --fixed-fps 60 --path . res://tests/smoke.tscn
## Ошибки скрипта Godot только печатает, поэтому CI дополнительно ищет их в логе.

const MainScene := preload("res://main.tscn")
const UpgradesScript := preload("res://upgrades.gd")

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
		await _play_takes(TAKES_PER_HERO)
		_expect(Recorder.ghosts.size() == TAKES_PER_HERO, "%s: записалось копий %d" % [hero, Recorder.ghosts.size()])
	await _check_montages()
	await _check_death()
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


func _check_death() -> void:
	main.run_menu.campaign_requested.emit("guard")
	await _frames(30)
	_kill_player()
	_expect(main.state == main.State.DEAD, "игрок не погиб")
	await _frames(40)
	await _press(KEY_SPACE)
	_expect(main.state == main.State.PLAY, "после смерти забег не начался заново")
	await _frames(30)
	_kill_player()
	await _press(KEY_ESCAPE)
	_expect(main.state == main.State.MENU, "Esc после смерти не вернул в меню")


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
	boss.hit(1e9, "player")
	await _frames(5)
	_expect(main.state == main.State.VICTORY, "после финального Цензора нет победы")
	_expect(main.endless_unlocked, "бесконечный режим не открылся")
	main.run_menu.endless_continue_requested.emit()
	_expect(main.run_mode == "endless" and main.take == main.CAMPAIGN_TAKES + 1, "бесконечный режим не продолжился")
	await _play_takes(3)


func _find_boss():
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.kind == 6 and not e.dead:
			return e
	return null


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
