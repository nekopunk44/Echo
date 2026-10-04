extends Node2D
## Враг: идёт к игроку, убивает касанием. Копии он игнорирует.
## kind: 0 маньяк, 1 призрак, 2 дрон, 3 бандит, 4 наёмник, 5 робот, 6 Цензор (босс)
## Если есть спрайты в assets/ — рисуем их, иначе процедурные силуэты из art.gd.

const Art := preload("res://art.gd")
const SPRITE_NAME := {0: "maniac", 1: "phantom", 2: "drone", 3: "bandit", 4: "mercenary", 5: "robot", 6: "censor"}
const SPRITE_H := {0: 90.0, 1: 72.0, 2: 64.0, 3: 88.0, 4: 94.0, 5: 96.0, 6: 170.0}   # высота в игре, px
const BURST_COLOR := {
    0: Color("ff2e88"), 1: Color("b69cff"), 2: Color("ff8a00"), 3: Color("d9904a"),
    4: Color("ff8a00"), 5: Color("8cff4a"), 6: Color("ff2e88"),
}

var kind := 0
var hp := 2.0
var speed := 110.0
var target: Node2D
var main
var last_hit := {"player": -99.0, "ghost": -99.0}
var sync_flash := 0.0
var hit_flash := 0.0
var age := randf() * 10.0
var facing := 0.0
var look := Vector2.RIGHT
var dead := false
var freeze_t := 0.0    # пауза от пульта: враг стоит и получает больше урона
var mark_t := 0.0      # метка ценника: больше урона, взрыв при смерти (уровни 4+)
var mark_mult := 1.0
var mark_boom_r := 0.0
var mark_boom_dmg := 0.0
var mark_source := "player"
var last_sync := -99.0
var blind_t := 0.0     # ослеплён вспышкой: бредёт наугад и бьёт других врагов
var blind_hit := 1.0
var blind_source := "player"
var wander := Vector2.ZERO
var wander_t := 0.0
var bump_cd := 0.0
var hit_r := 32.0      # радиус попадания пули
var touch_r := 36.0    # на таком расстоянии враг убивает игрока

var tex: Texture2D
var sil: Texture2D
var h := 0.0
var flip := false


func _ready() -> void:
    add_to_group("enemies")
    if kind == 6:
        hit_r = 80.0
        touch_r = 70.0
    var n: String = SPRITE_NAME[kind]
    var path := "res://assets/enemy_%s.png" % n
    if ResourceLoader.exists(path):
        tex = load(path)
        sil = load("res://assets/enemy_%s_silhouette.png" % n)
        h = SPRITE_H[kind]
    else:
        scale = Vector2(1.5, 1.5)   # процедурная заглушка крупнее


func _base_color() -> Color:
    return BURST_COLOR.get(kind, Art.PINK)


func _physics_process(delta: float) -> void:
    age += delta
    sync_flash = maxf(0.0, sync_flash - delta)
    hit_flash = maxf(0.0, hit_flash - delta)
    freeze_t = maxf(0.0, freeze_t - delta)
    blind_t = maxf(0.0, blind_t - delta)
    bump_cd -= delta
    mark_t = maxf(0.0, mark_t - delta)
    if mark_t <= 0.0 and mark_mult != 1.0:
        mark_mult = 1.0
        mark_boom_r = 0.0
    if not main.is_playing() or not is_instance_valid(target):
        queue_redraw()
        return
    if freeze_t > 0.0:
        queue_redraw()
        return
    if blind_t > 0.0:   # слепой враг игрока не видит: бродит и бьёт всех, на кого наткнётся
        wander_t -= delta
        if wander_t <= 0.0:
            wander_t = randf_range(0.3, 0.7)
            wander = Vector2.from_angle(randf() * TAU)
        position += wander * speed * 0.7 * delta
        if absf(wander.x) > 0.1:
            flip = wander.x < 0.0
        if bump_cd <= 0.0:
            for o in get_tree().get_nodes_in_group("enemies"):
                if o == self or o.dead:
                    continue
                if position.distance_to(o.position) < (hit_r + o.hit_r) * 0.6:
                    o.hit(blind_hit, blind_source)
                    bump_cd = 0.5
                    break
        queue_redraw()
        return
    var to := target.position - position
    look = to.normalized()
    facing = to.angle()
    if absf(to.x) > 4.0:
        flip = to.x < 0.0
    position += look * speed * delta
    if to.length() < touch_r:
        main.player_died()
    queue_redraw()


func blind(dur: float, hit_dmg: float, source: String) -> void:
    if dead:
        return
    blind_t = maxf(blind_t, dur * (0.3 if kind == 6 else 1.0))
    blind_hit = maxf(blind_hit, hit_dmg)
    blind_source = source


func mark(dur: float, mult: float, boom_r: float, boom_dmg: float, source: String) -> void:
    if dead:
        return
    mark_t = maxf(mark_t, dur)
    mark_mult = maxf(mark_mult, mult)
    mark_boom_r = maxf(mark_boom_r, boom_r)
    mark_boom_dmg = maxf(mark_boom_dmg, boom_dmg)
    mark_source = source


func freeze(dur: float) -> void:
    if dead:
        return
    var d := dur
    if kind == 3:
        d *= 1.7   # вестерн замирает от паузы
    elif kind == 6:
        d *= 0.3   # босс почти не поддаётся
    freeze_t = maxf(freeze_t, d)


func hit(dmg: float, source: String) -> void:
    if dead:
        return
    var now := Time.get_ticks_msec() / 1000.0
    if freeze_t > 0.0:
        dmg *= 1.3   # кадр держит: замороженный получает на 30% больше
    if mark_t > 0.0:
        dmg *= mark_mult
    var other := "ghost" if source == "player" else "player"
    # Синхро-удар: игрок и копия бьют одного врага почти одновременно -> x2 урон
    if now - last_hit[other] < main.sync_window() and now - last_sync > 0.6:   # не чаще раза в 0.6 с на врага
        dmg *= main.sync_mult()
        sync_flash = 0.25
        last_sync = now
        last_hit[other] = -99.0
    last_hit[source] = now
    hit_flash = 0.07
    hp -= dmg
    if hp <= 0.001:
        dead = true
        main.kills += 1
        main.spawn_shards(position, kind)
        if mark_t > 0.0 and mark_boom_r > 0.0:
            main.explode_at(position, mark_boom_r, mark_boom_dmg, mark_source, Color("ff2e88"))
        if kind == 6:
            for i in 6:
                main.spawn_burst(position + Vector2(randf_range(-40, 40), randf_range(-70, 70)), _base_color())
            main.boss_died()
        else:
            main.spawn_burst(position, _base_color())
        queue_free()


func _draw() -> void:
    var col := _base_color()
    if sync_flash > 0.0:
        col = Art.YELLOW
    elif hit_flash > 0.0:
        col = Art.PINK if kind == 6 else Art.WHITE   # белый костюм Цензора на белой вспышке не видно

    if tex:
        var ofs := Vector2.ZERO
        var bob := 0.0
        match kind:
            0: bob = sin(age * 9.0) * 0.8        # маньяк: тяжёлый шаг
            1: ofs.y = sin(age * 3.0) * 4.0 - 6.0    # призрак парит
            2:                                    # дрон висит и покачивается
                ofs.y = sin(age * 5.0) * 3.0 - 8.0
                bob = sin(age * 6.0) * 0.4
            3: bob = sin(age * 9.0) * 0.7        # бандит крадётся
            4: bob = sin(age * 8.0) * 0.6        # наёмник
            5: bob = sin(age * 6.0) * 0.5        # робот: медленный и тяжёлый
            6: bob = sin(age * 4.0) * 0.4        # Цензор: размеренный шаг
        if freeze_t > 0.0:
            bob = 0.0
        Art.shadow(self, h * 0.3, 0.3, h / 2.0 - 4.0)
        Art.sprite(self, tex, h, flip, bob, Color.WHITE, ofs)
        if freeze_t > 0.0:
            Art.sprite(self, sil, h, flip, bob, Color(0.55, 0.9, 1.0, 0.4), ofs)
        if blind_t > 0.0:
            Art.sprite(self, sil, h, flip, bob, Color(1.0, 1.0, 0.7, 0.3), ofs)
        if sync_flash > 0.0 or hit_flash > 0.0:
            Art.sprite(self, sil, h, flip, bob, Color(col, 0.85), ofs)
        _draw_status(-h / 2.0 - 6.0 + ofs.y)
        return

    match kind:
        1: Art.phantom(self, age, look, col)
        2: Art.drone(self, age, col)
        _: Art.maniac(self, facing, age, col)
    _draw_status(-34.0)


func _draw_status(y: float) -> void:
    _draw_mark(y)
    if blind_t > 0.0:   # звёздочки над головой ослеплённого
        for i in 3:
            var a := age * 6.0 + i * TAU / 3.0
            draw_circle(Vector2(cos(a) * 13.0, y - 16.0 + sin(a) * 4.0), 3.0, Color("fff44f"))


## Ценник над головой помеченного врага; перед исчезновением мигает.
func _draw_mark(y: float) -> void:
    if mark_t <= 0.0:
        return
    if mark_t < 1.5 and fmod(mark_t, 0.3) < 0.15:
        return
    draw_colored_polygon(PackedVector2Array([
        Vector2(-12, y - 8), Vector2(6, y - 8), Vector2(14, y), Vector2(6, y + 8), Vector2(-12, y + 8)]), Color("ff2e88"))
    draw_rect(Rect2(-8, y - 2.5, 12, 5), Color("fff44f"))
    draw_circle(Vector2(7, y), 2.2, Color("1a0b2e"))
