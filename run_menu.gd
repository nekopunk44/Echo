extends CanvasLayer
## Главное меню и экран победы: заголовок с VHS-сдвигом цветов, выбор героя карточками, режимы.

signal campaign_requested(hero: String)
signal endless_requested(hero: String)
signal endless_continue_requested
signal menu_requested

const Upgrades := preload("res://upgrades.gd")
const Art := preload("res://art.gd")

const CARD_SIZE := Vector2(200, 196)
const CARD_GAP := 20.0
const GRID_TOP := 420.0

var root: Control
var title_labels: Array = []  # голубой и розовый сдвиг под основным текстом
var detail_label: Label
var hero_grid: Control
var hero_cards: Array = []
var trait_label: Label
var controls_label: Label
var campaign_button: Button
var endless_button: Button
var menu_button: Button
var selected_hero := "clerk"
var victory_visible := false
var _card_styles: Array = []  # [обычная, выбранная]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.02, 0.10)  # непрозрачный: HUD забега под меню не просвечивает
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	root.add_child(_osd_corner("PLAY ▶", Vector2(40, 48), Art.WHITE))

	for layer_def in [[Vector2(-6, 0), Art.CYAN], [Vector2(6, 0), Art.PINK], [Vector2.ZERO, Art.WHITE]]:
		var l := _label("ECHO", Vector2(0, 150) + layer_def[0], Vector2(720, 130), 112, layer_def[1])
		l.add_theme_font_override("font", Art.OSD_FONT)
		root.add_child(l)
		title_labels.append(l)
	detail_label = _label("", Vector2(60, 290), Vector2(600, 110), 24, Art.CYAN)
	root.add_child(detail_label)

	_card_styles = [_style(Color("1f0f3a"), Color("6b4fa8"), 2), _style(Color("3d1d75"), Art.YELLOW, 4)]
	hero_grid = Control.new()
	hero_grid.position = Vector2(50, GRID_TOP)
	root.add_child(hero_grid)
	for i in Upgrades.HEROES.size():
		var card := _hero_card(Upgrades.HEROES[i])
		card.position = Vector2((i % 3) * (CARD_SIZE.x + CARD_GAP), int(i / 3) * (CARD_SIZE.y + CARD_GAP))
		hero_grid.add_child(card)
		hero_cards.append(card)

	trait_label = _label("", Vector2(50, 845), Vector2(620, 80), 21, Art.YELLOW)
	root.add_child(trait_label)

	campaign_button = _button("КАМПАНИЯ  ·  12 ДУБЛЕЙ", Vector2(110, 945), Vector2(500, 84), Art.CYAN)
	campaign_button.pressed.connect(func(): campaign_requested.emit(selected_hero))
	root.add_child(campaign_button)

	endless_button = _button("БЕСКОНЕЧНЫЙ РЕЖИМ", Vector2(110, 1045), Vector2(500, 76), Color("b69cff"))
	endless_button.pressed.connect(_on_endless_pressed)
	root.add_child(endless_button)

	menu_button = _button("В ГЛАВНОЕ МЕНЮ", Vector2(140, 1145), Vector2(440, 72), Art.PINK)
	menu_button.pressed.connect(func(): menu_requested.emit())
	root.add_child(menu_button)

	controls_label = _label(
		"СТИК / WASD — ДВИЖЕНИЕ  ·  АТАКИ АВТОМАТИЧЕСКИЕ", Vector2(40, 1150), Vector2(640, 60), 18, Color("b69cff")
	)
	root.add_child(controls_label)
	show_menu("clerk")


func show_menu(hero: String = "clerk", endless_available: bool = false) -> void:
	root.visible = true
	victory_visible = false
	_select_hero(hero if Upgrades.HERO_INFO.has(hero) else "clerk")
	_set_title("ECHO", 112)
	detail_label.text = "12 ДУБЛЕЙ · 4 АКТА\nЦЕНЗОР КАЖДЫЙ ТРЕТИЙ ДУБЛЬ\nПЯТЬ ПОСЛЕДНИХ ДУБЛЕЙ СТАНУТ ЭХОМ"
	hero_grid.visible = true
	trait_label.visible = true
	campaign_button.visible = true
	endless_button.visible = true
	endless_button.disabled = not endless_available
	endless_button.text = "БЕСКОНЕЧНЫЙ РЕЖИМ" if endless_available else "БЕСКОНЕЧНЫЙ — ПОСЛЕ КАМПАНИИ"
	menu_button.visible = false
	controls_label.visible = true


func show_victory(kills: int, level: int) -> void:
	root.visible = true
	victory_visible = true
	_set_title("THE END", 64)
	detail_label.text = "ФИНАЛЬНЫЙ КАДР · ЦЕНЗОР ПОВЕРЖЕН\nУБИЙСТВ: %d   ·   УРОВЕНЬ: %d" % [kills, level]
	hero_grid.visible = false
	trait_label.visible = false
	campaign_button.visible = false
	endless_button.visible = true
	endless_button.disabled = false
	endless_button.text = "ПРОДОЛЖИТЬ В БЕСКОНЕЧНОМ РЕЖИМЕ"
	menu_button.visible = true
	controls_label.visible = false


func restore_menu_buttons() -> void:
	victory_visible = false
	endless_button.text = "БЕСКОНЕЧНЫЙ РЕЖИМ"


func hide_panel() -> void:
	root.visible = false
	restore_menu_buttons()


func _set_title(text: String, font_size: int) -> void:
	for l in title_labels:
		l.text = text
		l.add_theme_font_size_override("font_size", font_size)


func _select_hero(hero: String) -> void:
	selected_hero = hero
	for i in hero_cards.size():
		var chosen: bool = Upgrades.HEROES[i] == hero
		var style: StyleBoxFlat = _card_styles[1 if chosen else 0]
		for state_name in ["normal", "hover", "pressed"]:
			hero_cards[i].add_theme_stylebox_override(state_name, style)
		hero_cards[i].get_meta("name_label").add_theme_color_override("font_color", Art.YELLOW if chosen else Art.WHITE)
	var weapon_id: String = Upgrades.HERO_INFO[hero]["start_weapon"]
	var weapon_name: String = Upgrades.CATALOG[weapon_id]["name"]
	trait_label.text = "СТАРТОВОЕ ОРУЖИЕ: %s\n%s" % [weapon_name, Upgrades.HERO_INFO[hero]["trait"]]


func _hero_card(hero: String) -> Button:
	var card := Button.new()
	card.size = CARD_SIZE
	card.focus_mode = Control.FOCUS_NONE
	card.pressed.connect(_select_hero.bind(hero))
	# Режим растяжения — до размера: иначе размер упрётся в исходник спрайта и портрет вылезет из карточки.
	var portrait := TextureRect.new()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.position = Vector2(20, 12)
	portrait.size = Vector2(CARD_SIZE.x - 40, 120)
	var path := "res://assets/hero_%s.png" % hero
	portrait.texture = load(path if ResourceLoader.exists(path) else "res://assets/player.png")
	card.add_child(portrait)
	# Высота — на две строки: «Продавец попкорна» переносится.
	var name_label := _label(
		Upgrades.HERO_INFO[hero]["name"], Vector2(6, 134), Vector2(CARD_SIZE.x - 12, 56), 20, Art.WHITE
	)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(name_label)
	card.set_meta("name_label", name_label)
	return card


func _on_endless_pressed() -> void:
	if victory_visible:
		endless_continue_requested.emit()
	else:
		endless_requested.emit(selected_hero)


## Надпись экранного меню видеоплеера в углу: моноширинный пиксельный шрифт.
func _osd_corner(text: String, pos: Vector2, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_override("font", Art.OSD_FONT)
	l.add_theme_font_size_override("font_size", 24)
	l.add_theme_color_override("font_color", color)
	return l


func _label(text: String, pos: Vector2, size: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.size = size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _style(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(14)
	return sb


func _button(text: String, pos: Vector2, size: Vector2, border: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.position = pos
	button.size = size
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", Art.BOLD_FONT)
	button.add_theme_font_size_override("font_size", 26)
	button.add_theme_color_override("font_disabled_color", Color("6b5a8e"))
	var normal := _style(Color("1f0f3a"), border, 3)
	var hover := _style(Color("3d1d75"), border, 3)
	var disabled := _style(Color("140a26"), Color("3a2a5c"), 2)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("disabled", disabled)
	return button
