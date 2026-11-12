extends CanvasLayer
## Учебный рекламный ролик для отладочной сборки: полноценный экран в стиле игры.
## Досмотрел до конца — награда, закрыл раньше — нет. Так поток рекламы проверяется без SDK и без сети.
## Работает на паузе (process_mode = ALWAYS), время считает по delta, а не по часам.

const Art := preload("res://art.gd")

# Правила телефона: кнопки ≥ 88 px, текст ≥ 18 px.
const MIN_BTN := 88
const MIN_FONT := 18
const PROGRESS_H := 24  # высота полосы прогресса
const PROGRESS_W := 600  # максимальная ширина полосы (от x=60 до x=660)
const PROGRESS_X := 60  # отступ полосы от левого края

var root: Control
var countdown_label: Label
var no_reward_lbl: Label  # «без награды» — исчезает когда ролик досмотрен
var progress_fill: ColorRect  # заполнение полосы прогресса
var _left := 0.0
var _total := 0.0  # общее время ролика — нужно для расчёта прогресса
var _on_done: Callable


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 30  # поверх меню (20): реклама перекрывает всё
	root = Control.new()
	root.size = Vector2(720, 1280)
	root.visible = false
	add_child(root)

	# Затемнение фона: съедает тапы по игре под роликом
	var dim := ColorRect.new()
	dim.color = Color("07030f")  # непрозрачно: настоящий ролик тоже закрывает игру целиком
	dim.size = Vector2(720, 1280)
	root.add_child(dim)

	# ── верхняя панель ──────────────────────────────────────────────────────────
	var top_bg := ColorRect.new()
	top_bg.color = Color(0.05, 0.02, 0.10, 0.95)
	top_bg.size = Vector2(720, 100)
	root.add_child(top_bg)

	# Плашка «РЕКЛАМА» — OSD шрифт, жёлтая, как надпись плеера
	var ad_lbl := Label.new()
	ad_lbl.text = "РЕКЛАМА"
	ad_lbl.position = Vector2(28, 22)
	ad_lbl.size = Vector2(200, 56)
	ad_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ad_lbl.add_theme_font_override("font", Art.OSD_FONT)
	ad_lbl.add_theme_font_size_override("font_size", 22)
	ad_lbl.add_theme_color_override("font_color", Art.YELLOW)
	root.add_child(ad_lbl)

	# Индикатор-точка слева от «РЕКЛАМА» — имитация REC-индикатора плеера
	var rec_dot := ColorRect.new()
	rec_dot.color = Art.YELLOW
	rec_dot.position = Vector2(16, 42)
	rec_dot.size = Vector2(8, 8)
	root.add_child(rec_dot)

	# Надпись «без награды» рядом с кнопкой закрытия — видна пока ролик не досмотрен
	no_reward_lbl = Label.new()
	no_reward_lbl.text = "без награды"
	no_reward_lbl.position = Vector2(720 - MIN_BTN - 16 - 130, 30)
	no_reward_lbl.size = Vector2(120, 40)
	no_reward_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	no_reward_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	no_reward_lbl.add_theme_font_size_override("font_size", MIN_FONT)
	no_reward_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	root.add_child(no_reward_lbl)

	# Кнопка X — не меньше 88×88 (правило телефона); закрывает без награды
	var close_sb := StyleBoxFlat.new()
	close_sb.bg_color = Color("1f0f3a")
	close_sb.border_color = Art.PINK
	close_sb.set_border_width_all(2)
	close_sb.set_corner_radius_all(10)
	var close_btn := Button.new()
	close_btn.text = "X"  # у Press Start 2P нет глифа ✕
	close_btn.position = Vector2(720 - MIN_BTN - 16, 6)
	close_btn.size = Vector2(MIN_BTN, MIN_BTN)
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.add_theme_font_override("font", Art.OSD_FONT)
	close_btn.add_theme_font_size_override("font_size", 32)
	close_btn.add_theme_color_override("font_color", Art.WHITE)
	close_btn.add_theme_stylebox_override("normal", close_sb)
	close_btn.add_theme_stylebox_override("hover", close_sb)
	close_btn.add_theme_stylebox_override("pressed", close_sb)
	close_btn.pressed.connect(func() -> void: _close(false))
	root.add_child(close_btn)

	# Разделительная линия под шапкой — жёлтый акцент, как на VHS-экране
	var top_line := ColorRect.new()
	top_line.color = Color(Art.YELLOW.r, Art.YELLOW.g, Art.YELLOW.b, 0.4)
	top_line.position = Vector2(0, 100)
	top_line.size = Vector2(720, 2)
	root.add_child(top_line)

	# ── центральная «рекламная» секция ──────────────────────────────────────────
	var center_bg := ColorRect.new()
	center_bg.color = Color("0d0520")
	center_bg.position = Vector2(0, 220)
	center_bg.size = Vector2(720, 580)
	root.add_child(center_bg)

	# Рамка вокруг центральной секции — голубой акцент
	var frame_sb := StyleBoxFlat.new()
	frame_sb.bg_color = Color(0, 0, 0, 0)  # прозрачный фон
	frame_sb.border_color = Art.CYAN
	frame_sb.set_border_width_all(3)
	frame_sb.set_corner_radius_all(0)
	var frame_panel := Panel.new()
	frame_panel.position = Vector2(40, 230)
	frame_panel.size = Vector2(640, 560)
	frame_panel.add_theme_stylebox_override("panel", frame_sb)
	root.add_child(frame_panel)

	# Крупный заголовок видеопроката
	var title_lbl := Label.new()
	title_lbl.text = "ВИДЕОПРОКАТ «ЭХО»"
	title_lbl.position = Vector2(0, 290)
	title_lbl.size = Vector2(720, 70)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_override("font", Art.BOLD_FONT)
	title_lbl.add_theme_font_size_override("font_size", 44)
	title_lbl.add_theme_color_override("font_color", Art.CYAN)
	root.add_child(title_lbl)

	# Рекламные слоганы — придуманы специально, без реальных брендов
	var slogans := ["КАССЕТЫ, КОТОРЫЕ ПОМНЯТ ВАС", "ПЕРЕМОТКА — БЕСПЛАТНО", "МЫ ХРАНИМ КАЖДЫЙ ДУБЛЬ"]
	for i in slogans.size():
		var sl := Label.new()
		sl.text = slogans[i]
		sl.position = Vector2(0, 390 + i * 56)
		sl.size = Vector2(720, 50)
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		sl.add_theme_font_size_override("font_size", 24)
		sl.add_theme_color_override("font_color", Art.WHITE)
		root.add_child(sl)

	# Декоративная разделительная линия
	var sep := ColorRect.new()
	sep.color = Color(Art.CYAN.r, Art.CYAN.g, Art.CYAN.b, 0.5)
	sep.position = Vector2(160, 572)
	sep.size = Vector2(400, 2)
	root.add_child(sep)

	# Дополнительная строка — жёлтая, мелкая
	var extra := Label.new()
	extra.text = "ОТКРЫТО 24 ЧАСА  ·  ЖАНРЫ ДЛЯ ВСЕЙ СЕМЬИ"
	extra.position = Vector2(0, 584)
	extra.size = Vector2(720, 40)
	extra.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	extra.add_theme_font_size_override("font_size", 20)
	extra.add_theme_color_override("font_color", Art.YELLOW)
	root.add_child(extra)

	# Иконка кассеты (процедурная): прямоугольник с двумя катушками
	var cassette_ctrl := _CassetteIcon.new()
	cassette_ctrl.position = Vector2(320, 638)
	cassette_ctrl.size = Vector2(80, 50)
	root.add_child(cassette_ctrl)

	# ── нижняя секция ───────────────────────────────────────────────────────────
	countdown_label = Label.new()
	countdown_label.position = Vector2(0, 920)
	countdown_label.size = Vector2(720, 60)
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	countdown_label.add_theme_font_override("font", Art.OSD_FONT)
	countdown_label.add_theme_font_size_override("font_size", 32)
	countdown_label.add_theme_color_override("font_color", Art.YELLOW)
	root.add_child(countdown_label)

	# Фон полосы прогресса
	var prog_bg := ColorRect.new()
	prog_bg.color = Color("2a1450")
	prog_bg.position = Vector2(PROGRESS_X, 1010)
	prog_bg.size = Vector2(PROGRESS_W, PROGRESS_H)
	root.add_child(prog_bg)

	# Заполнение полосы прогресса (обновляется в _update_ui)
	progress_fill = ColorRect.new()
	progress_fill.color = Art.CYAN
	progress_fill.position = Vector2(PROGRESS_X, 1010)
	progress_fill.size = Vector2(0, PROGRESS_H)
	root.add_child(progress_fill)

	# Мелкий текст-подсказка под полосой
	var hint := Label.new()
	hint.text = "ЗАКРОЙ СЕЙЧАС — И НИЧЕГО НЕ ПОЛУЧИШЬ"
	hint.position = Vector2(0, 1050)
	hint.size = Vector2(720, 36)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", MIN_FONT)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	root.add_child(hint)


## Показать ролик на seconds секунд. on_done(rewarded) вызывается ровно один раз.
func open(seconds: float, on_done: Callable) -> void:
	_left = seconds
	_total = seconds
	_on_done = on_done
	_update_ui()
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
	_update_ui()


func _update_ui() -> void:
	countdown_label.text = "НАГРАДА ЧЕРЕЗ %d" % ceili(maxf(_left, 0.0))
	# Прогресс: 0 в начале, 1 в конце ролика
	var progress := 1.0 - clampf(_left / maxf(_total, 0.001), 0.0, 1.0)
	progress_fill.size.x = roundi(PROGRESS_W * progress)
	# Надпись «без награды» исчезает когда ролик досмотрен
	no_reward_lbl.visible = _left > 0.0


func _close(rewarded: bool) -> void:
	root.visible = false
	var cb := _on_done
	_on_done = Callable()
	if cb.is_valid():
		cb.call(rewarded)


# Вложенный узел для рисования иконки кассеты — чтобы не усложнять _draw() родителя.
class _CassetteIcon:
	extends Control

	func _draw() -> void:
		# Корпус кассеты
		draw_rect(Rect2(0, 0, 80, 50), Art.DARK)
		draw_rect(Rect2(0, 0, 80, 50), Art.CYAN, false, 2.0)
		# Два катушечных отверстия
		draw_circle(Vector2(22, 25), 10, Art.DARK)
		draw_arc(Vector2(22, 25), 10, 0.0, TAU, 20, Art.CYAN, 1.5)
		draw_circle(Vector2(58, 25), 10, Art.DARK)
		draw_arc(Vector2(58, 25), 10, 0.0, TAU, 20, Art.CYAN, 1.5)
		# Лента между катушками
		draw_line(Vector2(12, 42), Vector2(68, 42), Art.CYAN, 1.5)
