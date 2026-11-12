extends Node
## Автозагрузка Ads: реклама за награду. Единственная точка входа для игры — show_rewarded(место, колбэк).
## Колбэк получает true, только если ролик досмотрен; закрыл раньше, не загрузилось, реклама выключена — false.
## Сейчас бэкенд один — учебный ролик (fake_ad.gd) в отладочной сборке. Настоящий AdMob встанет вторым бэкендом
## внутри этого файла: вызывающий код (rewind.gd, выбор плёнки) при этом не меняется.

signal ad_started(placement: String)
signal ad_finished(placement: String, rewarded: bool)

const FakeAdScript := preload("res://fake_ad.gd")
const PLACEMENT_REWIND := "rewind"  # REWIND без жетона на экране «ОБРЫВ ПЛЁНКИ»
const PLACEMENT_REROLL := "reroll"  # переброс карточек, когда бесплатные кончились
const FAKE_SECONDS := 3.0  # учебный ролик короче настоящего (15–30 с): им проверяют поток, а не терпение

var enabled := OS.is_debug_build()  # без SDK реклама есть только в отладочной сборке; тесты включают её сами
var fake_seconds := FAKE_SECONDS  # 0 — награда сразу, без экрана (для дымового прогона)
var _busy := false
var _fake  # fake_ad.gd, создаётся при первом показе


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # ролик идёт поверх паузы: на экране выбора и выборе плёнки дерево стоит


## Можно ли предложить игроку рекламу. Пока идёт один ролик, второй не предлагаем.
func is_available(_placement: String) -> bool:
	return enabled and not _busy


func is_showing() -> bool:
	return _busy


func show_rewarded(placement: String, on_done: Callable) -> void:
	if not is_available(placement):
		on_done.call(false)
		return
	_busy = true
	ad_started.emit(placement)
	if fake_seconds <= 0.0:
		_finish(placement, on_done, true)
		return
	if _fake == null:
		_fake = FakeAdScript.new()
		add_child(_fake)
	_fake.open(fake_seconds, func(rewarded: bool) -> void: _finish(placement, on_done, rewarded))


func _finish(placement: String, on_done: Callable, rewarded: bool) -> void:
	_busy = false
	ad_finished.emit(placement, rewarded)
	on_done.call(rewarded)
