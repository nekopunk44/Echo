extends CanvasLayer

signal campaign_requested(hero: String)
signal endless_requested(hero: String)
signal endless_continue_requested
signal menu_requested

const Upgrades := preload("res://upgrades.gd")

var root: Control
var title_label: Label
var detail_label: Label
var hero_picker: OptionButton
var trait_label: Label
var controls_label: Label
var campaign_button: Button
var endless_button: Button
var menu_button: Button
var selected_hero := "clerk"
var victory_visible := false


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    layer = 20
    root = Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(root)

    var dim := ColorRect.new()
    dim.color = Color(0.05, 0.02, 0.10, 0.94)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(dim)

    title_label = _label("ECHO", Vector2(50, 200), Vector2(620, 100), 82, Color("ff2e88"), HORIZONTAL_ALIGNMENT_CENTER)
    root.add_child(title_label)
    detail_label = _label("12 ДУБЛЕЙ · 4 АКТА\nЦЕНЗОР КАЖДЫЙ ТРЕТИЙ ДУБЛЬ\nПЯТЬ ПОСЛЕДНИХ ДУБЛЕЙ СТАНУТ ЭХОМ", Vector2(80, 300), Vector2(560, 125), 25, Color("00f0ff"), HORIZONTAL_ALIGNMENT_CENTER)
    root.add_child(detail_label)

    hero_picker = OptionButton.new()
    hero_picker.position = Vector2(90, 460)
    hero_picker.size = Vector2(540, 64)
    hero_picker.add_theme_font_size_override("font_size", 26)
    hero_picker.add_theme_color_override("font_color", Color("f4f0ff"))
    var picker_style := StyleBoxFlat.new()
    picker_style.bg_color = Color("1f0f3a")
    picker_style.border_color = Color("b69cff")
    picker_style.set_border_width_all(2)
    picker_style.set_corner_radius_all(12)
    hero_picker.add_theme_stylebox_override("normal", picker_style)
    hero_picker.add_theme_stylebox_override("hover", picker_style)
    hero_picker.add_theme_stylebox_override("pressed", picker_style)
    for i in Upgrades.HEROES.size():
        var hero: String = Upgrades.HEROES[i]
        hero_picker.add_item(Upgrades.HERO_INFO[hero]["name"])
        hero_picker.set_item_metadata(i, hero)
    hero_picker.item_selected.connect(_on_hero_selected)
    root.add_child(hero_picker)

    trait_label = _label("", Vector2(70, 530), Vector2(580, 58), 19, Color("fff44f"), HORIZONTAL_ALIGNMENT_CENTER)
    root.add_child(trait_label)
    controls_label = _label("ДВИЖЕНИЕ: СТИК / WASD  ·  АТАКИ АВТОМАТИЧЕСКИЕ", Vector2(50, 865), Vector2(620, 44), 17, Color("b69cff"), HORIZONTAL_ALIGNMENT_CENTER)
    root.add_child(controls_label)

    campaign_button = _button("КАМПАНИЯ  ·  12 ДУБЛЕЙ", Vector2(110, 650), Vector2(500, 82), Color("00f0ff"))
    campaign_button.pressed.connect(func(): campaign_requested.emit(selected_hero))
    root.add_child(campaign_button)

    endless_button = _button("БЕСКОНЕЧНЫЙ РЕЖИМ", Vector2(110, 755), Vector2(500, 82), Color("b69cff"))
    endless_button.pressed.connect(_on_endless_pressed)
    root.add_child(endless_button)

    menu_button = _button("В ГЛАВНОЕ МЕНЮ", Vector2(140, 930), Vector2(440, 72), Color("ff2e88"))
    menu_button.pressed.connect(func(): menu_requested.emit())
    root.add_child(menu_button)
    show_menu("clerk")


func show_menu(hero: String = "clerk", endless_available: bool = false) -> void:
    root.visible = true
    victory_visible = false
    selected_hero = hero if Upgrades.HERO_INFO.has(hero) else "clerk"
    var hero_index := Upgrades.HEROES.find(selected_hero)
    hero_picker.select(hero_index)
    _on_hero_selected(hero_index)
    title_label.text = "ECHO"
    detail_label.text = "12 ДУБЛЕЙ · 4 АКТА\nЦЕНЗОР КАЖДЫЙ ТРЕТИЙ ДУБЛЬ\nПЯТЬ ПОСЛЕДНИХ ДУБЛЕЙ СТАНУТ ЭХОМ"
    hero_picker.visible = true
    trait_label.visible = true
    campaign_button.visible = true
    endless_button.visible = true
    endless_button.disabled = not endless_available
    endless_button.text = "БЕСКОНЕЧНЫЙ РЕЖИМ" if endless_available else "БЕСКОНЕЧНЫЙ РЕЖИМ · ПОСЛЕ КАМПАНИИ"
    menu_button.visible = false
    controls_label.visible = true


func show_victory(kills: int, level: int) -> void:
    root.visible = true
    victory_visible = true
    title_label.text = "ФИНАЛЬНЫЙ КАДР"
    detail_label.text = "ЦЕНЗОР ПОВЕРЖЕН\nУБИЙСТВ: %d   ·   УРОВЕНЬ: %d" % [kills, level]
    hero_picker.visible = false
    trait_label.visible = false
    campaign_button.visible = false
    endless_button.visible = true
    endless_button.text = "ПРОДОЛЖИТЬ В БЕСКОНЕЧНОМ РЕЖИМЕ"
    menu_button.visible = true
    controls_label.visible = false


func restore_menu_buttons() -> void:
    victory_visible = false
    endless_button.text = "БЕСКОНЕЧНЫЙ РЕЖИМ"


func hide_panel() -> void:
    root.visible = false
    restore_menu_buttons()


func _on_hero_selected(index: int) -> void:
    if index < 0 or index >= Upgrades.HEROES.size():
        return
    selected_hero = Upgrades.HEROES[index]
    var weapon_id: String = Upgrades.HERO_INFO[selected_hero]["start_weapon"]
    var weapon_name: String = Upgrades.CATALOG[weapon_id]["name"]
    trait_label.text = "СТАРТОВОЕ ОРУЖИЕ: %s\nЧЕРТА: %s" % [weapon_name, Upgrades.HERO_INFO[selected_hero]["trait"]]


func _on_endless_pressed() -> void:
    if victory_visible:
        endless_continue_requested.emit()
    else:
        endless_requested.emit(selected_hero)


func _label(text: String, pos: Vector2, size: Vector2, font_size: int, color: Color,
        align: HorizontalAlignment) -> Label:
    var label := Label.new()
    label.text = text
    label.position = pos
    label.size = size
    label.horizontal_alignment = align
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
    return label


func _button(text: String, pos: Vector2, size: Vector2, border: Color) -> Button:
    var button := Button.new()
    button.text = text
    button.position = pos
    button.size = size
    button.focus_mode = Control.FOCUS_NONE
    button.add_theme_font_size_override("font_size", 26)
    var normal := StyleBoxFlat.new()
    normal.bg_color = Color("1f0f3a")
    normal.border_color = border
    normal.set_border_width_all(3)
    normal.set_corner_radius_all(16)
    var hover: StyleBoxFlat = normal.duplicate()
    hover.bg_color = Color("3d1d75")
    button.add_theme_stylebox_override("normal", normal)
    button.add_theme_stylebox_override("hover", hover)
    button.add_theme_stylebox_override("pressed", hover)
    return button
