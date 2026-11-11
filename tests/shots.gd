extends Node
## Снимки экрана для проверки внешнего вида. Нужен настоящий рендер, поэтому без --headless:
## godot --path . --resolution 720x1280 res://tests/shots.tscn -- <папка для PNG>
## Снимает меню, бой, выбор плёнки, всплеск VHS, перемотку между дублями, арену каждого жанра,
## экран REWIND после смерти (до и после конца блокировки), кадр после отката, экран EJECT и жетон на земле.
## Те же экраны есть в варианте для телефона (без подсказок про клавиши): подсказки зависят от Art.is_phone().

const MainScene := preload("res://main.tscn")
const Art := preload("res://art.gd")

var main
var out_dir := ""


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else OS.get_user_data_dir().path_join("shots")
	DirAccess.make_dir_recursive_absolute(out_dir)
	main = MainScene.instantiate()
	main.progress_path = "user://shots_progress.cfg"
	add_child(main)
	_run.call_deferred()


func _run() -> void:
	await _wait(0.5)
	await _shot("01_menu")
	main.run_menu.campaign_requested.emit("clerk")
	await _play(6.0)
	await _shot("02_play")
	main.add_xp(main.xp_need(main.level))
	await _wait(1.3)  # карточки выезжают по очереди
	await _shot("03_pick")
	await _play(2.0)
	main.spawn_boss()
	await _wait(1.2)
	main.vhs.pulse(0.8)
	await _wait(0.05)
	await _shot("04_glitch")
	main.finish_take()
	while main.state != main.State.REWIND:
		await get_tree().process_frame
	await _wait(0.3)
	await _shot("05_rewind")
	for g in main.GENRES.size():
		main.forced_genre = g
		main.restart_run()
		await _play(4.0)
		await _shot("06_genre_%d" % g)
	await _last_chance_shots()
	get_tree().quit(0)


## Смерть с жетоном: экран выбора (кнопки погашены, затем включены), REWIND, затем EJECT и жетон за Цензора.
func _last_chance_shots() -> void:
	main.forced_genre = 0
	main.restart_run()
	await _play(9.0)  # герой набирает запись и толпу врагов вокруг
	main.invuln = 0.0
	main.armor_charges = 0
	main.player_died()
	while main.state != main.State.LAST_CHANCE:
		await get_tree().process_frame
	await _wait(0.3)
	await _shot("07a_last_chance_locked")
	while main.rewind_ui.is_locked():  # блокировка идёт по игровому времени, а оно отстаёт от настенного на снимках
		await get_tree().process_frame
	await _wait(0.3)
	await _shot("07_last_chance")
	main.rewind_ui.rewind_requested.emit()
	await _wait(0.15)
	await _shot("08_after_rewind")
	await _wait(0.5)  # вспышка и кольцо погасли, герой мигает неуязвимостью
	while fmod(main.invuln, 0.2) >= 0.1:  # фаза мигания с голубым оттенком
		await get_tree().process_frame
	await _shot("08b_after_rewind_blink")
	while fmod(main.invuln, 0.2) < 0.1:  # фаза мигания без оттенка: ободок под ногами виден в обеих
		await get_tree().process_frame
	await _shot("08c_after_rewind_plain")
	await _wait(0.6)
	main.invuln = 0.0
	main.player_died()  # жетонов больше нет: сразу EJECT с числом перемоток
	await _wait(0.6)
	await _shot("09_eject")
	await _phone_shots()
	main.restart_run()
	await _play(2.0)
	main.spawn_boss()
	await _wait(0.3)
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.kind == 6:
			main.rewind_tokens = 0
			e.position = main.player.position + Vector2(0, -260)  # в кадре, а не за краем арены
			e.hit(1e9, "player")
	await _wait(0.8)
	await _shot("10_token_drop")
	main.rewind_tokens = 2  # оба слота жетонов в HUD полные
	await _wait(0.2)
	await _shot("10b_tokens_full")


## Экраны смерти в варианте для телефона: нет подсказок про клавиши панели и про Esc на экране EJECT.
func _phone_shots() -> void:
	main.hud.phone = true
	main.rewind_ui.phone = true
	main.restart_run()
	await _play(4.0)
	main.invuln = 0.0
	main.player_died()
	while not main.rewind_ui.is_open():
		await get_tree().process_frame
	while main.rewind_ui.is_locked():
		await get_tree().process_frame
	await _wait(0.3)
	await _shot("07b_last_chance_phone")
	main.rewind_ui.eject_requested.emit()
	await _wait(0.3)
	await _shot("09b_eject_phone")
	main.hud.phone = Art.is_phone()
	main.rewind_ui.phone = Art.is_phone()


## Играет seconds секунд: выбор плёнки закрывается сразу, игрок неуязвим.
func _play(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		await get_tree().process_frame
		left -= get_process_delta_time()
		if main.state == main.State.PICK:
			main.picker.picked.emit(main.choices[0])
		elif main.state == main.State.PLAY:
			main.invuln = maxf(main.invuln, 1.0)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := out_dir.path_join(shot_name + ".png")
	get_viewport().get_texture().get_image().save_png(path)
	print("снимок: ", path)
