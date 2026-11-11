extends Node
## Отладочные клавиши — только в отладочной сборке на ПК:
## 1–6 — забег за героя, G — следующий жанр кассеты, B — вызвать Цензора,
## X — сразу получить уровень, M — пара оружия для «Монтажа», T — сразу закончить дубль (появится копия),
## K — погибнуть (без брони, чтобы увидеть экран REWIND), L — +1 жетон перемотки.

const HEROES := ["clerk", "courier", "guard", "projectionist", "popcorn", "critic"]
const MONTAGE_PAIRS := [["cassette", "magnet"], ["bat", "flash"], ["remote", "flashlight"], ["pricetags", "popgun"]]
const IN_RUN_KEYS := [KEY_B, KEY_T, KEY_M, KEY_X, KEY_K, KEY_L]

var main
var _montage_i := 0


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if _handle(key.keycode):
		get_viewport().set_input_as_handled()


func _handle(keycode: Key) -> bool:
	if keycode >= KEY_1 and keycode <= KEY_6:
		Recorder.hero = HEROES[keycode - KEY_1]
		main.restart_run()
		return true
	if keycode == KEY_G:
		main.forced_genre = (main.genre + 1) % main.GENRES.size()
		main.restart_run()
		return true
	if keycode not in IN_RUN_KEYS:
		return false
	if main.is_playing():
		_cheat(keycode)
	return true


func _cheat(keycode: Key) -> void:
	match keycode:
		KEY_B:
			main.spawn_boss()
		KEY_T:
			main.finish_take()
		KEY_M:
			_montage()
		KEY_X:
			main.add_xp(main.xp_need(main.level))
		KEY_K:
			main.invuln = 0.0
			main.armor_charges = 0
			main.player_died()
		KEY_L:
			main.rewind.grant_token()


## Оставляет в сборке два оружия третьего уровня и сразу открывает выбор — в нём будет «Монтаж».
func _montage() -> void:
	var pair: Array = MONTAGE_PAIRS[_montage_i % MONTAGE_PAIRS.size()]
	_montage_i += 1
	main.loadout.levels.clear()
	for id in pair:
		main.loadout.levels[id] = 3
	main.pending.append({"key": "%d_dbg%d" % [main.run_seed, _montage_i], "title": "ТЕСТ МОНТАЖА"})
