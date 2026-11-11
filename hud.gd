extends CanvasLayer
## HUD записи: REC-таймер с номером дубля, кассета и этап, уровень с полоской опыта,
## жетоны перемотки, сборка внизу экрана, крупные сообщения по центру и итоговый экран EJECT.

signal menu_requested  # кнопка «В МЕНЮ» на экране EJECT

const UpgradesScript := preload("res://upgrades.gd")
const Art := preload("res://art.gd")
const UpgradeIconAtlas := preload("res://assets/upgrade_icons.svg")
const TokenTexture := preload("res://assets/pickup_rewind_token.png")

const MAX_LOADOUT_ICONS := 11
const XP_WIDTH := 660.0
const TOKEN_SLOTS := preload("res://rewind.gd").REWIND_TOKENS_MAX  # слотов столько, сколько жетонов на руках
const TOKEN_SLOT_SIZE := 44.0
const TOKEN_FULL := Color(1, 1, 1, 1)
const TOKEN_EMPTY := Color(1, 1, 1, 0.22)
const FLASH_Y := 216.0  # «◀◀ REWIND» под строкой жетонов: на герое надпись закрывала бы его в самый нужный момент
const EJECT_DIM := Color(0.05, 0.02, 0.10, 0.72)  # затемнение под итогами, чтобы текст читался на любой арене
const EJECT_TITLE_Y := 430.0

var rec_dot: ColorRect
var rec_label: Label
var genre_label: Label
var level_label: Label
var xp_fill: ColorRect
var loadout_row: HBoxContainer
var msg: Label
var token_slots: Array = []  # иконки жетонов перемотки под полоской опыта
var rewind_flash: Label  # «◀◀ REWIND» после отката; в шрифте OSD, потому что у Exo 2 нет стрелок ◀
var eject_root: Control  # итоговый экран EJECT: заголовок и строки итогов, ниже — подсказки
var eject_title: Label
var eject_tape: Label
var eject_stats: Label
var eject_rewinds: Label
var eject_hint: Label
var eject_menu_button: Button  # выход в меню: на телефоне другого пути нет (Esc только на ПК)
var phone := Art.is_phone()  # на телефоне нет клавиш: подсказки про них скрыты (снимки подменяют значение)
var _loadout_signature := ""
var _flash_tween: Tween
var _slot_tween: Tween
var _hint_tween: Tween


func _ready() -> void:
	layer = 2  # над VHS-слоем: надписи плеера остаются чёткими
	rec_dot = ColorRect.new()
	rec_dot.color = Color("ff2e2e")
	rec_dot.position = Vector2(30, 40)
	rec_dot.size = Vector2(20, 20)
	add_child(rec_dot)

	rec_label = Label.new()
	rec_label.position = Vector2(62, 24)
	rec_label.size = Vector2(640, 46)
	rec_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rec_label.add_theme_font_override("font", Art.OSD_FONT)
	rec_label.add_theme_font_size_override("font_size", 24)
	add_child(rec_label)

	genre_label = Label.new()
	genre_label.position = Vector2(30, 76)
	genre_label.size = Vector2(520, 64)
	genre_label.add_theme_font_size_override("font_size", 20)
	genre_label.add_theme_color_override("font_color", Color("ff2e88"))
	add_child(genre_label)

	level_label = Label.new()
	level_label.position = Vector2(560, 76)
	level_label.size = Vector2(130, 40)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	level_label.add_theme_font_override("font", Art.OSD_FONT)
	level_label.add_theme_font_size_override("font_size", 24)
	level_label.add_theme_color_override("font_color", Color("00f0ff"))
	add_child(level_label)

	var xp_bg := ColorRect.new()
	xp_bg.color = Color(1, 1, 1, 0.15)
	xp_bg.position = Vector2(30, 142)
	xp_bg.size = Vector2(XP_WIDTH, 14)
	add_child(xp_bg)
	xp_fill = ColorRect.new()
	xp_fill.color = Color("00f0ff")
	xp_fill.position = Vector2(30, 142)
	xp_fill.size = Vector2(0, 14)
	add_child(xp_fill)

	loadout_row = HBoxContainer.new()
	loadout_row.position = Vector2(30, 1170)
	loadout_row.size = Vector2(XP_WIDTH, 82)
	loadout_row.add_theme_constant_override("separation", 3)
	loadout_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(loadout_row)

	msg = Label.new()
	msg.position = Vector2(0, 460)
	msg.size = Vector2(720, 400)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.add_theme_font_override("font", Art.BOLD_FONT)
	msg.add_theme_font_size_override("font_size", 48)
	msg.add_theme_color_override("font_outline_color", Art.DARK)
	msg.add_theme_constant_override("outline_size", 10)
	msg.add_theme_color_override("font_color", Color("00f0ff"))
	add_child(msg)
	_build_token_slots()
	_build_rewind_flash()
	_build_eject()


func _build_token_slots() -> void:
	for i in TOKEN_SLOTS:
		var slot := TextureRect.new()
		# Режим растяжения — до размера и текстуры, иначе размер упрётся в исходник (126x128).
		slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		slot.size = Vector2(TOKEN_SLOT_SIZE, TOKEN_SLOT_SIZE)
		slot.pivot_offset = slot.size / 2.0
		slot.position = Vector2(30.0 + XP_WIDTH - (TOKEN_SLOTS - i) * (TOKEN_SLOT_SIZE + 8.0) + 8.0, 162)
		slot.texture = TokenTexture
		slot.modulate = TOKEN_EMPTY
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(slot)
		token_slots.append(slot)


func _build_rewind_flash() -> void:
	rewind_flash = Label.new()
	rewind_flash.text = "◀◀ REWIND"
	rewind_flash.position = Vector2(0, FLASH_Y)
	rewind_flash.size = Vector2(720, 56)
	rewind_flash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rewind_flash.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rewind_flash.add_theme_font_override("font", Art.OSD_FONT)
	rewind_flash.add_theme_font_size_override("font_size", 32)
	rewind_flash.add_theme_color_override("font_color", Art.CYAN)
	rewind_flash.add_theme_color_override("font_outline_color", Art.DARK)
	rewind_flash.add_theme_constant_override("outline_size", 10)
	rewind_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rewind_flash.visible = false
	add_child(rewind_flash)


## Экран EJECT в духе экранного меню плеера: крупное слово, под ним итоги, внизу мигающая подсказка.
## Тапы сквозь него идут в main._input, поэтому у всех узлов, кроме кнопки меню, mouse_filter = IGNORE;
## касания кнопки main._input пропускает (eject_menu_hit), иначе тап по ней перезапустил бы забег.
func _build_eject() -> void:
	eject_root = Control.new()
	eject_root.size = Vector2(720, 1280)
	eject_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	eject_root.visible = false
	add_child(eject_root)
	var dim := ColorRect.new()
	dim.color = EJECT_DIM
	dim.size = Vector2(720, 1280)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	eject_root.add_child(dim)

	eject_title = _eject_label("EJECT", EJECT_TITLE_Y, 96.0, 80, Art.PINK, Art.OSD_FONT)
	eject_title.add_theme_color_override("font_outline_color", Art.DARK)
	eject_title.add_theme_constant_override("outline_size", 12)
	var rule := ColorRect.new()  # тонкая линия под словом: «окно» экранного меню
	rule.color = Color(Art.PINK, 0.6)
	rule.position = Vector2(80, EJECT_TITLE_Y + 116.0)
	rule.size = Vector2(560, 3)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	eject_root.add_child(rule)
	eject_tape = _eject_label("", EJECT_TITLE_Y + 140.0, 44.0, 34, Art.WHITE)
	eject_stats = _eject_label("", EJECT_TITLE_Y + 190.0, 40.0, 30, Art.WHITE)
	eject_rewinds = _eject_label("", EJECT_TITLE_Y + 238.0, 40.0, 30, Art.CYAN)
	eject_hint = _eject_label("", EJECT_TITLE_Y + 350.0, 40.0, 24, Art.YELLOW, Art.OSD_FONT)
	eject_menu_button = Button.new()
	eject_menu_button.position = Vector2(210, EJECT_TITLE_Y + 430.0)
	eject_menu_button.size = Vector2(300, 88)
	eject_menu_button.focus_mode = Control.FOCUS_NONE
	eject_menu_button.add_theme_font_override("font", Art.BOLD_FONT)
	eject_menu_button.add_theme_font_size_override("font_size", 26)
	eject_menu_button.add_theme_color_override("font_color", Color("b69cff"))
	var style := StyleBoxFlat.new()
	style.bg_color = Color("1f0f3a")
	style.border_color = Color("b69cff")
	style.set_border_width_all(3)
	style.set_corner_radius_all(14)
	for state_name in ["normal", "hover", "pressed"]:
		eject_menu_button.add_theme_stylebox_override(state_name, style)
	eject_menu_button.pressed.connect(func(): menu_requested.emit())
	eject_root.add_child(eject_menu_button)


func _eject_label(text: String, y: float, height: float, font_size: int, color: Color, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.position = Vector2(0, y)
	l.size = Vector2(720, height)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if font != null:
		l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	eject_root.add_child(l)
	return l


## Верхняя строка: время дубля и его номер. Красная точка мигает, пока идёт запись.
func show_take(take: int, take_time: float, total_takes: int, endless: bool, recording: bool) -> void:
	var t := int(take_time)
	var take_text := "ДУБЛЬ %02d ∞" % take if endless else "ДУБЛЬ %02d/%d" % [take, total_takes]
	rec_label.text = "REC  %02d:%02d   %s" % [t / 60, t % 60, take_text]
	rec_dot.visible = recording and fmod(Time.get_ticks_msec() / 1000.0, 1.0) < 0.5


func show_level(level: int, xp: int, need: int) -> void:
	level_label.text = "УР. %d" % level
	xp_fill.size.x = XP_WIDTH * clampf(float(xp) / float(need), 0.0, 1.0)


## Слоты жетонов перемотки: полные — жетон на руках, тусклые — пусто. Видны всё время, а не только после смерти.
func show_tokens(count: int) -> void:
	for i in token_slots.size():
		token_slots[i].modulate = TOKEN_FULL if i < count else TOKEN_EMPTY


## Подобранный жетон: слот с номером index вспыхивает и «подпрыгивает».
func flash_token(index: int) -> void:
	if index < 0 or index >= token_slots.size():
		return
	var slot: TextureRect = token_slots[index]
	if _slot_tween != null:
		_slot_tween.kill()
	for other in token_slots:  # прерванная вспышка не должна оставить соседний слот раздутым
		other.scale = Vector2.ONE
		other.self_modulate = Color.WHITE
	slot.scale = Vector2(1.7, 1.7)
	slot.self_modulate = Color(2.5, 2.5, 2.5, 1.0)
	_slot_tween = create_tween()
	_slot_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)  # смерть с жетоном с земли: вспышка идёт и на паузе
	_slot_tween.tween_property(slot, "scale", Vector2.ONE, 0.35)
	_slot_tween.parallel().tween_property(slot, "self_modulate", Color.WHITE, 0.35)


## Крупная надпись «◀◀ REWIND» на seconds секунд после отката. Отдельный Label, а не msg:
## там живёт «ЦЕНЗОР НЕ ПОВЕРЖЕН», и откат не должен стирать чужой текст.
func show_rewind_flash(seconds: float) -> void:
	rewind_flash.visible = true
	if _flash_tween != null:
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)  # сразу после отката может открыться выбор плёнки
	_flash_tween.tween_interval(seconds)
	_flash_tween.tween_callback(rewind_flash.hide)


## Итоговый экран конца забега. Тап или клавиша — заново; кнопка (или Esc на ПК) — в меню.
func show_eject(cassette: String, kills: int, level: int, take: int, rewinds: int) -> void:
	msg.text = ""  # «ЦЕНЗОР НЕ ПОВЕРЖЕН» не должен просвечивать из-под итогов
	eject_tape.text = "кассета: %s" % cassette
	eject_stats.text = "убито %d  ·  уровень %d  ·  дубль %d" % [kills, level, take]
	eject_rewinds.text = "перемоток: %d" % rewinds
	eject_hint.text = "ТАП — ЗАНОВО" if phone else "ТАП / КЛАВИША — ЗАНОВО"
	eject_menu_button.text = "В МЕНЮ" if phone else "В МЕНЮ · ESC"
	eject_root.visible = true
	if _hint_tween != null:
		_hint_tween.kill()
	eject_hint.modulate.a = 1.0
	_hint_tween = create_tween().set_loops()  # мигание «PRESS PLAY»: экран ждёт касания
	_hint_tween.tween_property(eject_hint, "modulate:a", 0.25, 0.5)
	_hint_tween.tween_property(eject_hint, "modulate:a", 1.0, 0.5)


## Касание пришлось на кнопку меню: main._input его пропускает, чтобы кнопка успела нажаться.
func eject_menu_hit(pos: Vector2) -> bool:
	return eject_root.visible and eject_menu_button.get_global_rect().has_point(pos)


func hide_eject() -> void:
	if _hint_tween != null:
		_hint_tween.kill()
	eject_root.visible = false


## Новый забег: иконки сборки перестроятся при следующем обновлении.
func reset_loadout() -> void:
	_loadout_signature = ""


## Иконки оружия и плёнок с уровнями. Перестраиваются, только когда сборка изменилась.
func refresh_loadout(loadout, armor_charges: int) -> void:
	if loadout == null:
		return
	var ids: Array = loadout.levels.keys()
	ids.sort()
	var signature := "%d|" % armor_charges
	for id in ids:
		signature += "%s:%d;" % [id, loadout.levels[id]]
	if signature == _loadout_signature:
		return
	_loadout_signature = signature
	for child in loadout_row.get_children():
		child.queue_free()
	for i in mini(ids.size(), MAX_LOADOUT_ICONS):
		loadout_row.add_child(_loadout_card(ids[i], loadout.level(ids[i])))


func _loadout_card(id: String, level: int) -> Control:
	var def: Dictionary = UpgradesScript.CATALOG[id]
	var icon_index := int(def.get("icon", 21))
	var card := Control.new()
	card.custom_minimum_size = Vector2(56, 68)
	card.size = Vector2(56, 68)
	var back := ColorRect.new()
	back.position = Vector2(2, 2)
	back.size = Vector2(52, 58)
	back.color = Color(0.08, 0.04, 0.16, 0.82)
	card.add_child(back)
	# Режим растяжения задаётся до размера: иначе иконка растёт до исходных 128 px атласа.
	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.position = Vector2(6, 5)
	icon.size = Vector2(44, 44)
	var atlas_tex := AtlasTexture.new()
	atlas_tex.atlas = UpgradeIconAtlas
	atlas_tex.region = Rect2((icon_index % 6) * 128, int(icon_index / 6) * 128, 128, 128)
	icon.texture = atlas_tex
	icon.tooltip_text = "%s · ур. %d" % [def["name"], level]
	card.add_child(icon)
	var level_badge := Label.new()
	level_badge.text = str(level)
	level_badge.position = Vector2(34, 42)
	level_badge.size = Vector2(20, 20)
	level_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_badge.add_theme_font_override("font", Art.OSD_FONT)
	level_badge.add_theme_font_size_override("font_size", 16)
	level_badge.add_theme_color_override("font_color", Art.YELLOW)
	level_badge.add_theme_color_override("font_outline_color", Art.DARK)
	level_badge.add_theme_constant_override("outline_size", 6)
	card.add_child(level_badge)
	return card
