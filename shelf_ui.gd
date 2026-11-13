extends CanvasLayer
## Экран «ПОЛКА ВИДЕОПРОКАТА»: коллекция кассет игрока, выбор активной кассеты для забега,
## статистика дублей, побед над Цензором и финалов кампании.
## Открывается из главного меню поверх него (слой 25, меню 20, реклама 30).

signal closed

const Art := preload("res://art.gd")
const CassettesScript := preload("res://cassettes.gd")

const BG_COLOR := Color(0.05, 0.02, 0.10)
const CARD_SIZE := Vector2(310, 320)
const BUTTON_SIZE := Vector2(500, 88)

var cassettes  # объект cassettes.gd, передаётся из run_menu до вызова add_child
var root: Control
var count_label: Label
var details_panel: Panel
var details_title: Label
var details_tagline: Label
var details_stats: Label
var details_note: Label
var cover_buttons: Array = []  # кнопки обложек для тестов и взаимодействия
var random_button: Button
var back_button: Button
var _card_views: Array = []  # кэш ссылок на дочерние элементы обложек, чтобы refresh() не пересоздавал дерево


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 25

	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.visible = false
	add_child(root)

	# Непрозрачный фон перекрывает меню под полкой и съедает случайные касания
	var dim := ColorRect.new()
	dim.color = BG_COLOR
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)

	var title_lbl := _label("ПОЛКА ВИДЕОПРОКАТА", Vector2(0, 70), Vector2(720, 56), 46, Art.PINK)
	title_lbl.add_theme_font_override("font", Art.BOLD_FONT)
	root.add_child(title_lbl)

	count_label = _label("", Vector2(0, 130), Vector2(720, 36), 24, Art.CYAN)
	root.add_child(count_label)

	_build_details()
	_build_covers()
	_build_buttons()


## Открыть полку кассет и актуализировать состояние всех карточек.
func open() -> void:
	root.visible = true
	refresh()


## Закрыть полку и уведомить главное меню для обновления подписи на кнопке.
func close() -> void:
	if not root.visible:
		return
	root.visible = false
	closed.emit()


func is_open() -> bool:
	return root != null and root.visible


## Полное обновление содержимого карточек без пересоздания узлов.
func refresh() -> void:
	if cassettes == null:
		return
	var seen_cnt: int = cassettes.seen_count()
	var total_cnt: int = cassettes.count()
	count_label.text = "НА ПОЛКЕ: %d / %d" % [seen_cnt, total_cnt]
	_refresh_details()

	for i in total_cnt:
		if i >= _card_views.size():
			break
		var view: Dictionary = _card_views[i]
		var btn: Button = view["button"]
		var is_open_cover: bool = cassettes.is_seen(i)
		var cover_data: Dictionary = cassettes.COVERS[i]
		var st: Dictionary = cassettes.stats(i)
		var is_chosen: bool = cassettes.selected == i

		btn.disabled = not is_open_cover

		if is_open_cover:
			view["banner"].visible = true
			var banner_color: Color = cover_data["color"]
			var banner_sb := StyleBoxFlat.new()
			banner_sb.bg_color = banner_color
			banner_sb.corner_radius_top_left = 14
			banner_sb.corner_radius_top_right = 14
			view["banner"].add_theme_stylebox_override("panel", banner_sb)
			view["title_label"].text = cover_data["name"]

			view["qmark_label"].visible = false

			var spr_path: String = cover_data["sprite"]
			view["sprite_rect"].texture = load(spr_path)
			view["sprite_rect"].modulate = Color.WHITE

			view["unseen_label"].visible = false

			var finals_cnt: int = int(st["finals"])
			view["final_badge"].visible = finals_cnt > 0
			if finals_cnt > 0:
				view["final_badge"].get_meta("label").text = "ФИНАЛ ×%d" % finals_cnt

			view["player_badge"].visible = is_chosen

			var border_col: Color = Art.YELLOW if is_chosen else Color("6b4fa8")
			var border_w: int = 5 if is_chosen else 2
			_apply_card_styles(btn, Color("1f0f3a"), border_col, border_w)
		else:
			view["banner"].visible = false
			view["qmark_label"].visible = true

			var base_path: String = cover_data["sprite"]
			var sil_path: String = base_path.replace(".png", "_silhouette.png")
			var tex_path: String = sil_path if ResourceLoader.exists(sil_path) else base_path
			view["sprite_rect"].texture = load(tex_path)
			view["sprite_rect"].modulate = Color(0.25, 0.2, 0.35)

			view["unseen_label"].visible = true
			view["final_badge"].visible = false
			view["player_badge"].visible = false

			btn.add_theme_stylebox_override("disabled", _style(Color("140a26"), Color("3a2a5c"), 2))

	var is_rand_active: bool = cassettes.selected == cassettes.RANDOM
	var rand_border: Color = Art.YELLOW if is_rand_active else Color("b69cff")
	_apply_button_styles(random_button, Color("1f0f3a"), rand_border, 3)


func _build_covers() -> void:
	var total_cards: int = cassettes.count() if cassettes != null else CassettesScript.COVERS.size()
	for i in total_cards:
		var col_idx: int = i % 2
		var row_idx: int = int(i / 2)
		var card_x: float = 40.0 if col_idx == 0 else 370.0
		var card_y: float = 180.0 if row_idx == 0 else 515.0

		var btn := Button.new()
		btn.position = Vector2(card_x, card_y)
		btn.size = CARD_SIZE
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(_on_cover_pressed.bind(i))
		root.add_child(btn)
		cover_buttons.append(btn)

		# Цветная полоса названия для открытых кассет
		var banner := Panel.new()
		banner.position = Vector2.ZERO
		banner.size = Vector2(CARD_SIZE.x, 56)
		banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(banner)

		var title_lbl := _label("", Vector2.ZERO, Vector2(CARD_SIZE.x, 48), 26, Art.DARK)
		title_lbl.add_theme_font_override("font", Art.BOLD_FONT)
		banner.add_child(title_lbl)

		# Вопросительные знаки шрифтом экранного меню плеера для закрытых кассет
		var qmark_lbl := _label("???", Vector2(0, 12), Vector2(CARD_SIZE.x, 50), 40, Color("6b5a8e"))
		qmark_lbl.add_theme_font_override("font", Art.OSD_FONT)
		btn.add_child(qmark_lbl)

		# Спрайт врага: expand_mode и stretch_mode задаются строго ДО size и texture
		var sprite_rect := TextureRect.new()
		sprite_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sprite_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sprite_rect.size = Vector2(170, 160)
		sprite_rect.position = Vector2(70, 55)
		sprite_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(sprite_rect)

		var unseen_lbl := _label(
			"ЕЩЁ НЕ СМОТРЕЛИ", Vector2(10, 228), Vector2(CARD_SIZE.x - 20, 40), 18, Color("6b5a8e")
		)
		btn.add_child(unseen_lbl)

		var final_badge := _badge(Vector2(CARD_SIZE.x - 118, CARD_SIZE.y - 42), Vector2(110, 32), "")
		btn.add_child(final_badge)

		var player_badge := _badge(Vector2(8, CARD_SIZE.y - 42), Vector2(116, 32), "В ПЛЕЕРЕ")
		btn.add_child(player_badge)

		(
			_card_views
			. append(
				{
					"button": btn,
					"banner": banner,
					"title_label": title_lbl,
					"qmark_label": qmark_lbl,
					"sprite_rect": sprite_rect,
					"unseen_label": unseen_lbl,
					"final_badge": final_badge,
					"player_badge": player_badge,
				}
			)
		)


func _build_buttons() -> void:
	random_button = _button("СЛУЧАЙНАЯ КАССЕТА", Vector2(110, 1000), BUTTON_SIZE, Color("b69cff"))
	random_button.pressed.connect(_on_random_pressed)
	root.add_child(random_button)

	back_button = _button("НАЗАД", Vector2(110, 1110), BUTTON_SIZE, Art.PINK)
	back_button.pressed.connect(close)
	root.add_child(back_button)


func _on_cover_pressed(idx: int) -> void:
	if cassettes == null:
		return
	cassettes.select(idx)
	refresh()


func _on_random_pressed() -> void:
	if cassettes == null:
		return
	cassettes.select(cassettes.RANDOM)
	refresh()


func _build_details() -> void:
	details_panel = Panel.new()
	details_panel.position = Vector2(40, 850)
	details_panel.size = Vector2(640, 140)
	details_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel_style := _style(Color("140a26"), Color("6b4fa8"), 2)
	details_panel.add_theme_stylebox_override("panel", panel_style)
	root.add_child(details_panel)

	details_title = _label("", Vector2(12, 4), Vector2(616, 28), 20, Art.YELLOW)
	details_title.add_theme_font_override("font", Art.BOLD_FONT)
	details_panel.add_child(details_title)
	details_tagline = _label("", Vector2(12, 32), Vector2(616, 26), 18, Art.WHITE)
	details_panel.add_child(details_tagline)
	details_stats = _label("", Vector2(12, 58), Vector2(616, 36), 18, Art.CYAN)
	details_panel.add_child(details_stats)
	details_note = _label("", Vector2(12, 94), Vector2(616, 40), 18, Art.YELLOW)
	details_panel.add_child(details_note)


func _refresh_details() -> void:
	if cassettes.selected == cassettes.RANDOM:
		details_title.text = "СЛУЧАЙНАЯ КАССЕТА"
		details_title.add_theme_color_override("font_color", Art.YELLOW)
		details_tagline.text = "Жанр выбирается игрой перед каждым дублем."
		details_stats.text = ""
		details_note.text = ""
		return

	var idx: int = cassettes.selected
	if idx < 0 or idx >= cassettes.COVERS.size() or not cassettes.is_seen(idx):
		details_title.text = ""
		details_tagline.text = ""
		details_stats.text = ""
		details_note.text = ""
		return

	var cover: Dictionary = cassettes.COVERS[idx]
	var stat: Dictionary = cassettes.stats(idx)
	details_title.text = str(cover["name"])
	details_title.add_theme_color_override("font_color", cover["color"])
	details_tagline.text = str(cover["tagline"])
	details_stats.text = "ДУБЛЕЙ %d, ЦЕНЗОРОВ %d\nУБИТО %d" % [stat["takes"], stat["censors"], stat["kills"]]
	details_note.text = str(cover["note"])


func _input(event: InputEvent) -> void:
	if not root.visible:
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func _badge(pos: Vector2, badge_sz: Vector2, text_val: String) -> Panel:
	var panel := Panel.new()
	panel.position = pos
	panel.size = badge_sz
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Art.YELLOW
	sb.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", sb)
	var lbl := _label(text_val, Vector2.ZERO, badge_sz, 18, Art.DARK)
	lbl.add_theme_font_override("font", Art.BOLD_FONT)
	panel.add_child(lbl)
	panel.set_meta("label", lbl)
	return panel


func _label(
	text_val: String,
	pos: Vector2,
	sz: Vector2,
	font_sz: int,
	col: Color,
	align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER
) -> Label:
	var lbl := Label.new()
	lbl.text = text_val
	lbl.position = pos
	lbl.size = sz
	lbl.horizontal_alignment = align
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", font_sz)
	lbl.add_theme_color_override("font_color", col)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl


func _button(text_val: String, pos: Vector2, sz: Vector2, border: Color) -> Button:
	var btn := Button.new()
	btn.text = text_val
	btn.position = pos
	btn.size = sz
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_override("font", Art.BOLD_FONT)
	btn.add_theme_font_size_override("font_size", 26)
	btn.add_theme_color_override("font_disabled_color", Color("6b5a8e"))
	var normal := _style(Color("1f0f3a"), border, 3)
	var hover := _style(Color("3d1d75"), border, 3)
	var disabled := _style(Color("140a26"), Color("3a2a5c"), 2)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_stylebox_override("disabled", disabled)
	return btn


func _style(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(14)
	return sb


func _apply_card_styles(btn: Button, bg: Color, border: Color, width: int) -> void:
	var sb_normal := _style(bg, border, width)
	var sb_hover := _style(Color("3d1d75"), border, width)
	btn.add_theme_stylebox_override("normal", sb_normal)
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_stylebox_override("pressed", sb_hover)


func _apply_button_styles(btn: Button, bg: Color, border: Color, width: int) -> void:
	var sb_normal := _style(bg, border, width)
	var sb_hover := _style(Color("3d1d75"), border, width)
	btn.add_theme_stylebox_override("normal", sb_normal)
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_stylebox_override("pressed", sb_hover)
