extends Node
## Снимки экрана для проверки внешнего вида. Нужен настоящий рендер, поэтому без --headless:
## godot --path . --resolution 720x1280 res://tests/shots.tscn -- <папка для PNG>
## Снимает меню, бой, всплеск VHS, перемотку между дублями и выбор плёнки.

const MainScene := preload("res://main.tscn")

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
	await _wait(0.3)
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
	get_tree().quit(0)


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
