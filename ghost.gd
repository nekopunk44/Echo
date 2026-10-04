extends Node2D
## Копия: повторяет записанный путь и атакует так же, как игрок.
## Кадры ходьбы те же, что у игрока: красный и голубой силуэты со сдвигом (RGB), бледное ядро,
## полосы VHS и редкий глитч-рывок. Чем старше дубль (age), тем темнее и глитчевее.

const Art := preload("res://art.gd")
const LoadoutScript := preload("res://loadout.gd")
const SPRITE_H := 80.0
const WALK_FRAMES := 8
const IDLE_FRAME := 2
const WALK_FPS := 18.0

var path := PackedVector2Array()
var start_levels := {}      # плёнки на начало записанного дубля
var events: Array = []      # [[тик, id], ...] выборы внутри дубля
var ev_i := 0
var lo                      # набор плёнок копии
var age := 0
var idx := 0
var cds := {}
var main

var t := 0.0
var walk_tex: Texture2D
var walk_sil: Texture2D
var tex: Texture2D
var sil: Texture2D
var flip := false
var anim_t := float(IDLE_FRAME)
var frame := IDLE_FRAME
var facing := 0.0
var facing_target := 0.0
var aim_hold := 0.0
var bob_t := 0.0
var bob := 0.0
var flash_t := 0.0
var jitter := 0.0
var jitter_x := 0.0


func _ready() -> void:
    main = get_parent()
    add_to_group("ghosts")
    lo = LoadoutScript.new()
    lo.levels = start_levels.duplicate()
    lo.set_hero(Recorder.hero)
    var hero: String = Recorder.hero
    var hp := "res://assets/hero_%s.png" % hero
    if hero == "clerk" and ResourceLoader.exists("res://assets/player_walk.png"):
        walk_tex = load("res://assets/player_walk.png")
        walk_sil = load("res://assets/player_walk_silhouette.png")
    elif ResourceLoader.exists(hp):
        tex = load(hp)
        sil = load("res://assets/hero_%s_silhouette.png" % hero)
    elif ResourceLoader.exists("res://assets/player.png"):
        tex = load("res://assets/player.png")
        sil = load("res://assets/player_silhouette.png")
    if path.size() > 0:
        position = path[0]


func _physics_process(delta: float) -> void:
    t += delta
    while ev_i < events.size() and events[ev_i][0] <= idx:
        lo.add(events[ev_i][1])
        ev_i += 1
    var prev := position
    if idx < path.size():
        position = path[idx]
        idx += 1
    var step := position - prev

    var ratio := clampf(step.length() / delta / 340.0, 0.0, 1.0)
    if ratio > 0.05:
        anim_t += ratio * delta * WALK_FPS
        frame = int(anim_t) % WALK_FRAMES
    else:
        anim_t = float(IDLE_FRAME)
        frame = IDLE_FRAME
    bob_t += ratio * delta * 14.0
    bob = sin(bob_t) * ratio
    aim_hold = maxf(0.0, aim_hold - delta)
    flash_t = maxf(0.0, flash_t - delta)

    if main.is_playing():
        var aim: Vector2 = main.tick_weapons(self, "ghost", lo, cds, delta)
        if aim != Vector2.ZERO:
            facing_target = aim.angle()
            if absf(aim.x) > 0.05:
                flip = aim.x < 0.0
            aim_hold = 0.3
            flash_t = 0.08
    if aim_hold <= 0.0 and step.length() > 0.5:
        facing_target = step.angle()
        if absf(step.x) > 0.3:
            flip = step.x < 0.0
    facing = lerp_angle(facing, facing_target, minf(1.0, 15.0 * delta))

    jitter = maxf(0.0, jitter - delta)
    if jitter <= 0.0 and randf() < 0.01:
        jitter = 0.1
        jitter_x = randf_range(-1.0, 1.0) * (4.0 + age * 2.0)
    queue_redraw()


func _stripes() -> void:
    # бегущие полосы: цвета фона, поэтому на пустом поле их не видно, а на силуэте они режут его
    for k in 8:
        var y := fposmod(k * 12.0 + t * 24.0, SPRITE_H) - SPRITE_H / 2.0
        draw_rect(Rect2(-40, y, 80, 2), Art.DARK)


func _draw() -> void:
    var a := maxf(0.3, 0.85 - 0.18 * age)
    var ofs := Vector2(jitter_x if jitter > 0.0 else 0.0, 0.0)
    var red := Color(1.0, 0.18, 0.45, 0.6 * a)
    var cyan := Color(0.0, 1.0, 1.0, 0.6 * a)

    if walk_tex:
        Art.shadow(self, 24.0, 0.5 * a, SPRITE_H / 2.0 - 4.0)
        Art.sprite_frame(self, walk_sil, WALK_FRAMES, frame, SPRITE_H, flip, red, ofs + Vector2(-3, 0))
        Art.sprite_frame(self, walk_sil, WALK_FRAMES, frame, SPRITE_H, flip, cyan, ofs + Vector2(3, 0))
        Art.sprite_frame(self, walk_tex, WALK_FRAMES, frame, SPRITE_H, flip, Color(1, 1, 1, 0.45 * a), ofs)
        _stripes()
        return
    if tex:
        Art.shadow(self, 24.0, 0.5 * a, SPRITE_H / 2.0 - 4.0)
        Art.sprite(self, sil, SPRITE_H, flip, bob, red, ofs + Vector2(-3, 0))
        Art.sprite(self, sil, SPRITE_H, flip, bob, cyan, ofs + Vector2(3, 0))
        Art.sprite(self, tex, SPRITE_H, flip, bob, Color(1, 1, 1, 0.45 * a), ofs)
        _stripes()
        return

    Art.shadow(self, 16.0, 0.5 * a)
    var core := Color(0.9, 0.95, 1.0, 0.35 * a)
    Art.clerk(self, facing, red, red, red, bob, false, 0.0, ofs + Vector2(-3, 0))
    Art.clerk(self, facing, cyan, cyan, cyan, bob, false, flash_t / 0.08, ofs + Vector2(3, 0))
    Art.clerk(self, facing, core, core, core, bob, false, 0.0, ofs)
    for k in 6:
        var y := fposmod(k * 8.0 + t * 24.0, 48.0) - 24.0
        draw_rect(Rect2(-26, y, 52, 2), Art.DARK)
