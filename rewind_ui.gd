extends CanvasLayer
## Экран «ОБРЫВ ПЛЁНКИ» после смерти с жетоном: REWIND (потратить жетон) или EJECT (закончить забег).
## Каждый узел — поле, внешний вид правится, не трогая логику.
## Работает при get_tree().paused = true (process_mode = ALWAYS). Все таймеры идут по delta, а не по часам:
## дымовой прогон на --fixed-fps быстрее настенного времени.
## Ввод: REWIND — тап по кнопке или Space/Enter/R, EJECT — тап по кнопке или Esc. Остальное панель не закрывает.

signal rewind_requested
signal eject_requested

const Art := preload("res://art.gd")
const TokenTexture := preload("res://assets/pickup_rewind_token.png")

const PANEL_LOCK := 0.7  # блокировка кнопок: палец, жавший на стик в момент смерти, не выберет за игрока
const LOCKED_ALPHA := 0.45  # погашенный вид кнопок на время блокировки; рамка цветная, чтобы не казалось «сломано»
const LOCK_BAR_Y := 566.0  # полоска «плёнка заряжается» над кнопкой REWIND: наполняется, пока идёт блокировка
const DIM_COLOR := Color(0.05, 0.02, 0.10, 0.85)  # затемнение как у выбора плёнки
const TOKEN_ICON_SIZE := 72.0
const TOKEN_ICON_GAP := 16.0
const TOKEN_EMPTY := Color(1, 1, 1, 0.2)

var root: Control
var dim: ColorRect
var title_label: Label
var summary_label: Label
var caption_label: Label
var token_row: Control
var token_icons: Array = []
var rewind_button: Button
var rewind_icon: Control  # два треугольника ◀◀: у Exo 2 нет такого глифа
var rewind_title: Label
var rewind_hint: Label
var eject_button: Button
var eject_title: Label
var eject_hint: Label
var keys_label: Label
var lock_bg: ColorRect  # подложка полоски блокировки
var lock_bar: ColorRect
var phone := Art.is_phone()  # на телефоне клавиш нет: подсказка про ПК скрыта (снимки подменяют значение)
var _lock_left := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10  # как у выбора плёнки, ниже меню (20)
	root = Control.new()
	root.size = Vector2(720, 1280)
	root.visible = false
	add_child(root)

	dim = ColorRect.new()
	dim.color = DIM_COLOR
	dim.size = Vector2(720, 1280)
	root.add_child(dim)  # заодно съедает тапы мимо кнопок

	title_label = _label("ОБРЫВ ПЛЁНКИ", Vector2(0, 190), Vector2(720, 90), 64, Art.PINK)
	title_label.add_theme_font_override("font", Art.BOLD_FONT)
	root.add_child(title_label)
	summary_label = _label("", Vector2(0, 290), Vector2(720, 40), 24, Art.WHITE)
	root.add_child(summary_label)

	caption_label = _label("ЖЕТОНЫ ПЕРЕМОТКИ", Vector2(0, 385), Vector2(720, 36), 22, Art.CYAN)
	root.add_child(caption_label)
	token_row = Control.new()
	token_row.position = Vector2(0, 430)
	token_row.size = Vector2(720, TOKEN_ICON_SIZE)
	token_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(token_row)

	lock_bg = ColorRect.new()
	lock_bg.color = Color(1, 1, 1, 0.12)
	lock_bg.position = Vector2(80, LOCK_BAR_Y)
	lock_bg.size = Vector2(560, 8)
	lock_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(lock_bg)
	lock_bar = ColorRect.new()
	lock_bar.color = Art.CYAN
	lock_bar.position = lock_bg.position
	lock_bar.size = Vector2(0, 8)
	lock_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(lock_bar)
	_build_rewind_button()
	_build_eject_button()
	keys_label = _label("ПК: SPACE — REWIND  ·  ESC — EJECT", Vector2(0, 1130), Vector2(720, 30), 18, Color("b69cff"))
	root.add_child(keys_label)


func _build_rewind_button() -> void:
	rewind_button = _button(Vector2(80, 600), Vector2(560, 120), Art.CYAN)
	rewind_button.pressed.connect(_on_rewind_pressed)
	root.add_child(rewind_button)
	rewind_icon = Control.new()
	rewind_icon.position = Vector2(124, 20)
	rewind_icon.size = Vector2(64, 44)
	rewind_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rewind_icon.draw.connect(_draw_rewind_icon)
	rewind_button.add_child(rewind_icon)
	rewind_title = _label("REWIND", Vector2(204, 8), Vector2(260, 68), 52, Art.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	rewind_title.add_theme_font_override("font", Art.BOLD_FONT)
	rewind_button.add_child(rewind_title)
	rewind_hint = _label("", Vector2(0, 80), Vector2(560, 30), 20, Art.CYAN)
	rewind_button.add_child(rewind_hint)


## EJECT меньше и ниже REWIND: отказ от отката не должен случайно подвернуться под палец.
func _build_eject_button() -> void:
	eject_button = _button(Vector2(140, 800), Vector2(440, 92), Art.PINK)
	eject_button.pressed.connect(_on_eject_pressed)
	root.add_child(eject_button)
	eject_title = _label("EJECT", Vector2(0, 6), Vector2(440, 46), 34, Art.WHITE)
	eject_title.add_theme_font_override("font", Art.BOLD_FONT)
	eject_button.add_child(eject_title)
	eject_hint = _label("забег закончится", Vector2(0, 54), Vector2(440, 28), 20, Art.PINK)
	eject_button.add_child(eject_hint)


func _label(
	text: String,
	pos: Vector2,
	sz: Vector2,
	font_size: int,
	color: Color,
	align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER
) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = sz
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(pos: Vector2, sz: Vector2, border: Color) -> Button:
	var b := Button.new()
	b.position = pos
	b.size = sz
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", _style(Color("1f0f3a"), border))
	b.add_theme_stylebox_override("hover", _style(Color("3d1d75"), border))
	b.add_theme_stylebox_override("pressed", _style(Color("3d1d75"), Art.YELLOW))
	b.add_theme_stylebox_override("disabled", _style(Color("140a26"), border))  # та же рамка: погашена, а не мертва
	return b


func _style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(18)
	return sb


func _draw_rewind_icon() -> void:
	var half := rewind_icon.size.x / 2.0
	var h := rewind_icon.size.y
	for k in 2:
		var x := k * half
		rewind_icon.draw_colored_polygon(
			PackedVector2Array([Vector2(x + half, 0.0), Vector2(x + half, h), Vector2(x, h / 2.0)]), Art.CYAN
		)


## Показать панель. tokens — жетонов на руках, token_max — места под них, cut_seconds — на сколько отмотает откат.
func open(
	take_no: int, kills: int, level: int, tokens: int, token_max: int, cut_seconds: float, invuln_seconds: float
) -> void:
	summary_label.text = "ДУБЛЬ %02d · УБИТО %d · УР. %d" % [take_no, kills, level]
	var seconds := [_seconds_text(cut_seconds), _seconds_text(invuln_seconds)]
	rewind_hint.text = "−%s С · %s С НЕУЯЗВИМОСТИ · ВРАГИ ОТБРОШЕНЫ" % seconds
	keys_label.visible = not phone
	_set_token_slots(token_max)
	for i in token_icons.size():
		token_icons[i].modulate = Color.WHITE if i < tokens else TOKEN_EMPTY
	_lock_left = PANEL_LOCK
	_apply_lock()
	root.visible = true


func close() -> void:
	root.visible = false
	_lock_left = 0.0


func is_open() -> bool:
	return root.visible


## Пока идёт блокировка, панель ничего не принимает, кнопки выглядят погашенными.
func is_locked() -> bool:
	return root.visible and _lock_left > 0.0


func _set_token_slots(count: int) -> void:
	if token_icons.size() == count:
		return
	for icon in token_icons:
		icon.queue_free()
	token_icons.clear()
	var total := count * TOKEN_ICON_SIZE + (count - 1) * TOKEN_ICON_GAP
	for i in count:
		var icon := TextureRect.new()
		# Режим растяжения — до размера и текстуры, иначе размер упрётся в исходник (126x128).
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size = Vector2(TOKEN_ICON_SIZE, TOKEN_ICON_SIZE)
		icon.texture = TokenTexture
		icon.position = Vector2((720.0 - total) / 2.0 + i * (TOKEN_ICON_SIZE + TOKEN_ICON_GAP), 0.0)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		token_row.add_child(icon)
		token_icons.append(icon)


## «5», а не «5.0»; дробные секунды (смерть на 2.4-й секунде) показываем с десятыми.
func _seconds_text(seconds: float) -> String:
	var s := snappedf(seconds, 0.1)
	return "%d" % roundi(s) if is_equal_approx(s, roundf(s)) else "%.1f" % s


func _apply_lock() -> void:
	var locked := _lock_left > 0.0
	for b in [rewind_button, eject_button]:
		b.disabled = locked
		b.modulate.a = LOCKED_ALPHA if locked else 1.0
	lock_bg.visible = locked
	lock_bar.visible = locked
	lock_bar.size.x = 560.0 * (1.0 - _lock_left / PANEL_LOCK)


func _physics_process(delta: float) -> void:
	if _lock_left > 0.0:
		_lock_left = maxf(0.0, _lock_left - delta)
		_apply_lock()


func _on_rewind_pressed() -> void:
	if not is_locked():
		rewind_requested.emit()


func _on_eject_pressed() -> void:
	if not is_locked():
		eject_requested.emit()


func _input(event: InputEvent) -> void:
	if not root.visible:
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_R:
			_on_rewind_pressed()
		KEY_ESCAPE:
			_on_eject_pressed()
		_:
			return  # клавиши движения и «любая клавиша» панель не трогают
	# Без этого Esc после EJECT дошёл бы до main._input и сразу увёл бы в меню.
	get_viewport().set_input_as_handled()
