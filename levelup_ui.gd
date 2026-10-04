extends CanvasLayer
## Экран выбора: пауза в стиле OSD плеера, три карточки (оружие — голубая рамка, плёнка — розовая), пересброс.
## Работает при get_tree().paused = true (process_mode = ALWAYS). Выбор: тап по карточке или клавиши 1/2/3.

signal picked(id: String)
signal reroll_requested

const Upgrades := preload("res://upgrades.gd")
const Art := preload("res://art.gd")

var root: Control
var sub_lbl: Label
var reroll_btn: Button
var cards: Array = []
var icons: Array = []
var montage_views: Array = []
var names: Array = []
var lvls: Array = []
var descs: Array = []
var ids: Array = []
var film_styles: Array = []
var weapon_styles: Array = []
var gold_styles: Array = []
var echo_styles: Array = []
var icon_atlas: Texture2D


func _styles(border: Color, bg: Color = Color("2a1450"), hover_border: Color = Art.YELLOW) -> Array:
    var sb := StyleBoxFlat.new()
    sb.bg_color = bg
    sb.border_color = border
    sb.set_border_width_all(4)
    sb.set_corner_radius_all(18)
    var sb_h: StyleBoxFlat = sb.duplicate()
    sb_h.bg_color = Color("3d1d75")
    sb_h.border_color = hover_border
    return [sb, sb_h]


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    layer = 10
    icon_atlas = load("res://assets/upgrade_icons.svg")
    film_styles = _styles(Art.PINK)
    weapon_styles = _styles(Art.CYAN)
    echo_styles = _styles(Color("b69cff"))
    gold_styles = _styles(Art.YELLOW, Color("3a2c0a"), Art.WHITE)
    root = Control.new()
    root.position = Vector2.ZERO
    root.size = Vector2(720, 1280)
    root.pivot_offset = Vector2(360, 640)
    root.visible = false
    add_child(root)

    var dim := ColorRect.new()
    dim.color = Color(0.05, 0.02, 0.10, 0.85)
    dim.size = Vector2(720, 1280)
    root.add_child(dim)

    # "PAUSE" с двумя полосками, как на экране плеера
    for x in [190.0, 218.0]:
        var bar := ColorRect.new()
        bar.color = Art.YELLOW
        bar.position = Vector2(x, 166)
        bar.size = Vector2(16, 56)
        root.add_child(bar)
    root.add_child(_label("PAUSE", Vector2(250, 140), Vector2(400, 100), 72, Art.PINK))
    sub_lbl = _label("", Vector2(0, 245), Vector2(720, 60), 44, Art.CYAN, HORIZONTAL_ALIGNMENT_CENTER)
    root.add_child(sub_lbl)

    for i in 3:
        var b := Button.new()
        b.position = Vector2(50, 330 + i * 270)
        b.size = Vector2(620, 240)
        b.focus_mode = Control.FOCUS_NONE
        b.pressed.connect(_choose.bind(i))
        root.add_child(b)

        var icon := TextureRect.new()
        icon.position = Vector2(20, 62)
        icon.size = Vector2(112, 112)
        icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
        b.add_child(icon)
        icons.append(icon)

        var montage_view := Control.new()
        montage_view.position = Vector2(18, 52)
        montage_view.size = Vector2(120, 136)
        montage_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
        montage_view.visible = false
        var part_a := _icon_view(Vector2(0, 7), Vector2(42, 42))
        var part_b := _icon_view(Vector2(72, 7), Vector2(42, 42))
        var result_icon := _icon_view(Vector2(27, 70), Vector2(66, 66))
        var plus := _label("+", Vector2(45, 9), Vector2(26, 36), 28, Art.YELLOW, HORIZONTAL_ALIGNMENT_CENTER)
        var arrow := _label("↓", Vector2(45, 44), Vector2(26, 28), 24, Art.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
        for node in [part_a, part_b, result_icon, plus, arrow]:
            montage_view.add_child(node)
        b.add_child(montage_view)
        montage_views.append([part_a, part_b, result_icon, montage_view])

        var nm := _label("", Vector2(150, 14), Vector2(400, 50), 34, Art.YELLOW)
        var lv := _label("", Vector2(150, 66), Vector2(400, 36), 23, Art.CYAN)
        var ds := _label("", Vector2(150, 108), Vector2(430, 116), 21, Art.WHITE)
        ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        var key := _label(str(i + 1), Vector2(566, 14), Vector2(40, 50), 36, Art.PINK)
        for l in [nm, lv, ds, key]:
            b.add_child(l)
        cards.append(b)
        names.append(nm)
        lvls.append(lv)
        descs.append(ds)

    reroll_btn = Button.new()
    reroll_btn.text = "ПЕРЕБРОС"
    reroll_btn.position = Vector2(160, 1150)
    reroll_btn.size = Vector2(400, 70)
    reroll_btn.focus_mode = Control.FOCUS_NONE
    reroll_btn.add_theme_font_size_override("font_size", 28)
    var rb := StyleBoxFlat.new()
    rb.bg_color = Color("1f0f3a")
    rb.border_color = Art.CYAN
    rb.set_border_width_all(3)
    rb.set_corner_radius_all(14)
    reroll_btn.add_theme_stylebox_override("normal", rb)
    reroll_btn.add_theme_stylebox_override("hover", rb)
    reroll_btn.add_theme_stylebox_override("pressed", rb)
    reroll_btn.pressed.connect(func(): reroll_requested.emit())
    root.add_child(reroll_btn)


func _label(text: String, pos: Vector2, sz: Vector2, font_size: int, color: Color,
        align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
    var l := Label.new()
    l.text = text
    l.position = pos
    l.size = sz
    l.horizontal_alignment = align
    l.add_theme_font_size_override("font_size", font_size)
    l.add_theme_color_override("font_color", color)
    l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return l


func open(title: String, choice_ids: Array, loadout, rerolls_left: int) -> void:
    sub_lbl.text = title
    set_choices(choice_ids, loadout)
    set_reroll_count(rerolls_left)
    root.visible = true
    root.modulate.a = 0.0
    root.scale = Vector2(0.96, 0.96)
    var tween := create_tween()
    tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tween.tween_property(root, "modulate:a", 1.0, 0.18)
    tween.parallel().tween_property(root, "scale", Vector2.ONE, 0.28)
    for i in ids.size():
        var card: Button = cards[i]
        card.modulate.a = 0.0
        card.scale = Vector2(0.94, 0.94)
        tween.tween_interval(0.05)
        tween.tween_property(card, "modulate:a", 1.0, 0.16)
        tween.parallel().tween_property(card, "scale", Vector2.ONE, 0.2)


func set_choices(choice_ids: Array, loadout) -> void:
    ids = choice_ids
    for i in 3:
        var c: Button = cards[i]
        c.visible = i < ids.size()
        if i >= ids.size():
            continue
        var id: String = ids[i]
        var def: Dictionary = Upgrades.CATALOG[id]
        var kind: String = def["kind"]
        var lvl: int = loadout.level(id)
        var is_montage: bool = def.has("parts") and lvl == 0
        var is_endless: bool = def.get("endless", false)
        var icon_index := int(def.get("icon", 20))
        var atlas_tex := AtlasTexture.new()
        atlas_tex.atlas = icon_atlas
        atlas_tex.region = Rect2((icon_index % 6) * 128, int(icon_index / 6) * 128, 128, 128)
        icons[i].texture = atlas_tex
        icons[i].tooltip_text = def["name"]
        icons[i].visible = not is_montage
        montage_views[i][3].visible = is_montage
        if is_montage:
            for part_index in 2:
                var part_id: String = def["parts"][part_index]
                var part_icon: int = int(Upgrades.CATALOG[part_id].get("icon", 21))
                var part_tex := AtlasTexture.new()
                part_tex.atlas = icon_atlas
                part_tex.region = Rect2((part_icon % 6) * 128, int(part_icon / 6) * 128, 128, 128)
                montage_views[i][part_index].texture = part_tex
            montage_views[i][2].texture = atlas_tex
        var st: Array = film_styles
        if is_montage or is_endless:
            st = gold_styles
        elif kind == "weapon":
            st = weapon_styles
        elif def.get("echo", false):
            st = echo_styles
        c.add_theme_stylebox_override("normal", st[0])
        c.add_theme_stylebox_override("hover", st[1])
        c.add_theme_stylebox_override("pressed", st[1])
        names[i].text = def["name"]
        c.tooltip_text = "%s\n%s" % [def["name"], Upgrades.card_description(id, lvl, loadout)]
        if is_endless:
            lvls[i].text = "БЕСКОНЕЧНЫЙ РЕЖИМ  ·  УР. %d → %d" % [lvl, lvl + 1]
        elif kind == "special":
            lvls[i].text = "НАГРАДА"
        elif is_montage:
            lvls[i].text = "МОНТАЖ  ·  2 НАВЫКА → 1 ОРУЖИЕ"
        elif lvl == 0:
            var slot_count := loadout.count_kind(kind)
            var slot_max := Upgrades.MAX_WEAPON_SLOTS if kind == "weapon" else Upgrades.MAX_FILM_SLOTS
            var category := "ОРУЖИЕ" if kind == "weapon" else ("ЭХО-ПЛЁНКА" if def.get("echo", false) else "ПЛЁНКА")
            lvls[i].text = "НОВОЕ %s  ·  СЛОТ %d/%d" % [category, slot_count + 1, slot_max]
        else:
            var category := "ОРУЖИЕ" if kind == "weapon" else ("ЭХО-ПЛЁНКА" if def.get("echo", false) else "ПЛЁНКА")
            lvls[i].text = "%s  ·  УР. %d → %d / %d" % [category, lvl, lvl + 1, def["max"]]
        descs[i].text = Upgrades.card_description(id, lvl, loadout)


func set_reroll_count(count: int) -> void:
    reroll_btn.visible = count > 0
    reroll_btn.text = "ПЕРЕБРОС · %d" % count


func _icon_view(pos: Vector2, size: Vector2) -> TextureRect:
    var view := TextureRect.new()
    view.position = pos
    view.size = size
    view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    view.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return view


func close() -> void:
    root.visible = false


func _choose(i: int) -> void:
    if i < ids.size():
        picked.emit(ids[i])


func _input(event: InputEvent) -> void:
    if not root.visible:
        return
    if event is InputEventKey and event.pressed and not event.echo:
        var i := -1
        match event.keycode:
            KEY_1: i = 0
            KEY_2: i = 1
            KEY_3: i = 2
        if i >= 0 and i < ids.size():
            get_viewport().set_input_as_handled()
            _choose(i)
