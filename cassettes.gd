extends RefCounted
## Полка кассет: какие кассеты игрок уже видел, сколько на каждой снято и какую он выбрал для следующего забега.
## Индекс кассеты совпадает с индексом жанра в main.GENRES. Кассета появляется на полке, когда на ней начался дубль:
## забег листает жанры по актам, поэтому полку открывает сама кампания.
## Лежит в общем файле прогресса: читать и писать его только целиком, иначе потеряется открытый бесконечный режим.

const SECTION := "cassettes"
const RANDOM := -1  # на полке выбрана «случайная кассета»
const EMPTY_STATS := {"seen": false, "takes": 0, "censors": 0, "kills": 0, "finals": 0}
# Обложки: порядок и названия как в main.GENRES (дымовой прогон сверяет).
# note — только то, что правда работает в игре (beam.gd, enemy.gd).
const COVERS := [
	{
		"name": "УЖАСЫ",
		"tagline": "НОЧЬ, КОТОРУЮ СТЁРЛИ",
		"color": Color("ff2e88"),
		"sprite": "res://assets/enemy_maniac.png",
		"note": "БОИТСЯ СВЕТА: ФОНАРЬ БЬЁТ НА 50% СИЛЬНЕЕ",
	},
	{
		"name": "БОЕВИК",
		"tagline": "ПАТРОНЫ НЕ КОНЧАЮТСЯ",
		"color": Color("ff8a00"),
		"sprite": "res://assets/enemy_mercenary.png",
		"note": "",
	},
	{
		"name": "ВЕСТЕРН",
		"tagline": "ПОЛДЕНЬ БЕЗ ПЕРЕМОТКИ",
		"color": Color("d9904a"),
		"sprite": "res://assets/enemy_bandit.png",
		"note": "ЗАМИРАЕТ ОТ ПАУЗЫ: ПУЛЬТ ДЕРЖИТ ДОЛЬШЕ",
	},
	{
		"name": "КИБЕРПАНК",
		"tagline": "ГОРОД НА ЧУЖОЙ ПЛЁНКЕ",
		"color": Color("8cff4a"),
		"sprite": "res://assets/enemy_robot.png",
		"note": "",
	},
]

var selected := RANDOM
var _path := ""
var _stats: Array = []
var _synced_kills := 0  # сколько убийств этого забега уже разнесено по кассетам


func _init(path: String) -> void:
	_path = path
	var file := ConfigFile.new()
	var ok := file.load(_path) == OK
	for i in COVERS.size():
		var row: Dictionary = EMPTY_STATS.duplicate()
		if ok:
			var saved: Variant = file.get_value(SECTION, "c%d" % i, {})
			if saved is Dictionary:
				row.merge(saved, true)
		_stats.append(row)
	if ok:
		selected = int(file.get_value(SECTION, "selected", RANDOM))
	if selected != RANDOM and not is_seen(selected):
		selected = RANDOM  # файл правили руками или кассет стало меньше: на случайную полагаться безопасно


func count() -> int:
	return _stats.size()


func is_seen(i: int) -> bool:
	return i >= 0 and i < _stats.size() and bool(_stats[i]["seen"])


func seen_count() -> int:
	var n := 0
	for i in _stats.size():
		if is_seen(i):
			n += 1
	return n


## Копия строки статистики: seen, takes, censors, kills, finals. Экран только читает.
func stats(i: int) -> Dictionary:
	return _stats[i].duplicate()


## Выбрать кассету для следующего забега. Невиданную выбрать нельзя: она ещё закрыта.
func select(i: int) -> void:
	if i != RANDOM and not is_seen(i):
		return
	selected = i
	_save()


## Кассета следующего забега: выбранная на полке, иначе случайная.
func pick_genre() -> int:
	return selected if selected != RANDOM else randi() % _stats.size()


func new_run() -> void:
	_synced_kills = 0


## Начался дубль на этой кассете. Файл пишем, только если она открылась впервые.
func on_take_started(i: int) -> void:
	if not is_seen(i):
		_stats[i]["seen"] = true
		_save()


func add_take(i: int) -> void:
	_stats[i]["takes"] += 1
	_save()


func add_censor(i: int) -> void:
	_stats[i]["censors"] += 1
	_save()


## Финал кампании засчитывается кассете, с которой забег начался: её и выбирают на полке.
func add_final(i: int) -> void:
	_stats[i]["finals"] += 1
	_save()


## Разнести убийства забега по кассетам: зовётся на смене кассеты и в конце забега, а не на каждого врага.
func sync_kills(i: int, run_kills: int) -> void:
	var fresh := run_kills - _synced_kills
	if fresh <= 0:
		return
	_stats[i]["kills"] += fresh
	_synced_kills = run_kills
	_save()


func _save() -> void:
	var file := ConfigFile.new()
	file.load(_path)  # файла может ещё не быть: тогда просто создаём новый
	for i in _stats.size():
		file.set_value(SECTION, "c%d" % i, _stats[i])
	file.set_value(SECTION, "selected", selected)
	file.save(_path)
