extends CanvasLayer
## Учебный рекламный ролик для отладочной сборки: обратный отсчёт и кнопка «Закрыть».
## Досмотрел до конца — награда, закрыл раньше — нет. Так поток рекламы проверяется без SDK и без сети.
## Работает на паузе (process_mode = ALWAYS), время считает по delta, а не по часам.

const Art := preload("res://art.gd")

var root: Control
var countdown_label: Label
var close_button: Button
var _left := 0.0
var _on_done: Callable


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 30  # поверх меню (20): реклама перекрывает всё
	root = Control.new()
	root.size = Vector2(720, 1280)
	root.visible = false
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.92)
	dim.size = Vector2(720, 1280)
	root.add_child(dim)  # заодно съедает тапы по игре под роликом
	countdown_label = Label.new()
	countdown_label.position = Vector2(0, 600)
	countdown_label.size = Vector2(720, 80)
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_label.add_theme_font_size_override("font_size", 36)
	root.add_child(countdown_label)
	close_button = Button.new()
	close_button.text = "ЗАКРЫТЬ"
	close_button.position = Vector2(500, 60)
	close_button.size = Vector2(180, 88)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(func() -> void: _close(false))
	root.add_child(close_button)


## Показать ролик на seconds секунд. on_done(rewarded) вызывается ровно один раз.
func open(seconds: float, on_done: Callable) -> void:
	_left = seconds
	_on_done = on_done
	_update_text()
	root.visible = true


func is_open() -> bool:
	return root.visible


## Закрыть раньше конца, как крестиком: награды нет. Нужна тестам и снимкам.
func skip() -> void:
	if root.visible:
		_close(false)


func _process(delta: float) -> void:
	if not root.visible:
		return
	_left -= delta
	if _left <= 0.0:
		_close(true)
		return
	_update_text()


func _update_text() -> void:
	countdown_label.text = "РЕКЛАМА · НАГРАДА ЧЕРЕЗ %d" % ceili(maxf(_left, 0.0))


func _close(rewarded: bool) -> void:
	root.visible = false
	var cb := _on_done
	_on_done = Callable()
	if cb.is_valid():
		cb.call(rewarded)
