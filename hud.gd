extends CanvasLayer
## HUD записи: REC-таймер с номером дубля, кассета и этап, уровень с полоской опыта,
## сборка внизу экрана и крупные сообщения по центру.

const UpgradesScript := preload("res://upgrades.gd")
const UpgradeIconAtlas := preload("res://assets/upgrade_icons.svg")

const MAX_LOADOUT_ICONS := 11
const XP_WIDTH := 660.0

var rec_dot: ColorRect
var rec_label: Label
var genre_label: Label
var level_label: Label
var xp_fill: ColorRect
var loadout_row: HBoxContainer
var msg: Label
var _loadout_signature := ""


func _ready() -> void:
	layer = 2  # над VHS-слоем: надписи плеера остаются чёткими
	rec_dot = ColorRect.new()
	rec_dot.color = Color("ff2e2e")
	rec_dot.position = Vector2(30, 40)
	rec_dot.size = Vector2(20, 20)
	add_child(rec_dot)

	rec_label = Label.new()
	rec_label.position = Vector2(62, 24)
	rec_label.size = Vector2(620, 46)
	rec_label.add_theme_font_size_override("font_size", 36)
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
	level_label.add_theme_font_size_override("font_size", 28)
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
	msg.add_theme_font_size_override("font_size", 52)
	msg.add_theme_color_override("font_color", Color("00f0ff"))
	add_child(msg)


## Верхняя строка: время дубля и его номер. Красная точка мигает, пока идёт запись.
func show_take(take: int, take_time: float, total_takes: int, endless: bool, recording: bool) -> void:
	var t := int(take_time)
	var take_text := "ДУБЛЬ %02d ∞" % take if endless else "ДУБЛЬ %02d/%d" % [take, total_takes]
	rec_label.text = "REC  %02d:%02d   %s" % [t / 60, t % 60, take_text]
	rec_dot.visible = recording and fmod(Time.get_ticks_msec() / 1000.0, 1.0) < 0.5


func show_level(level: int, xp: int, need: int) -> void:
	level_label.text = "УР. %d" % level
	xp_fill.size.x = XP_WIDTH * clampf(float(xp) / float(need), 0.0, 1.0)


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
	level_badge.position = Vector2(36, 42)
	level_badge.size = Vector2(16, 20)
	level_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_badge.add_theme_font_size_override("font_size", 18)
	level_badge.add_theme_color_override("font_color", Color("fff44f"))
	card.add_child(level_badge)
	return card
