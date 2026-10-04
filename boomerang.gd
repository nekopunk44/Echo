extends Node2D
## Кассета-бумеранг: летит во врага, пробивает нескольких, разворачивается и возвращается к владельцу.
## Каждого врага бьёт один раз за полёт туда и один раз на возврате.

const SPEED := 640.0
const SPRITE_W := 54.0

var owner_node: Node2D
var source := "player"
var dir := Vector2.RIGHT
var damage := 1.0
var size_mult := 1.0
var pierce := 3
var ret_mult := 1.0
var max_range := 340.0
var pull_r := 0.0      # Монтаж «Перемотка»: на возврате тянет врагов
var pull := 0.0

var returning := false
var travelled := 0.0
var leg_hits := 0
var hit_this_leg := {}
var spin := 0.0
var tex: Texture2D


func _ready() -> void:
    add_to_group("bullets")
    scale = Vector2.ONE * size_mult
    var path := "res://assets/bullet_cassette_cyan.png" if source == "ghost" else "res://assets/bullet_cassette.png"
    if ResourceLoader.exists(path):
        tex = load(path)


func _start_return() -> void:
    returning = true
    hit_this_leg.clear()
    leg_hits = 0


func _physics_process(delta: float) -> void:
    spin += delta * 18.0
    if not returning:
        position += dir * SPEED * delta
        travelled += SPEED * delta
        if travelled >= max_range:
            _start_return()
    else:
        if not is_instance_valid(owner_node):
            queue_free()
            return
        var to := owner_node.position - position
        if to.length() < 30.0:
            queue_free()
            return
        position += to.normalized() * SPEED * 1.1 * delta
        if pull_r > 0.0:
            for e in get_tree().get_nodes_in_group("enemies"):
                if e.dead or e.kind == 6:
                    continue
                var v: Vector2 = position - e.position
                if v.length() < pull_r and v.length() > 24.0:
                    e.position += v.normalized() * pull * delta

    for e in get_tree().get_nodes_in_group("enemies"):
        if e.dead:
            continue
        var id: int = e.get_instance_id()
        if hit_this_leg.has(id):
            continue
        if position.distance_to(e.position) < e.hit_r * size_mult + 8.0:
            hit_this_leg[id] = true
            leg_hits += 1
            e.hit(damage * (ret_mult if returning else 1.0), source)
            if not returning and leg_hits >= pierce:
                _start_return()
                break
    queue_redraw()


func _draw() -> void:
    var col := Color("00f0ff") if source == "ghost" else Color("fff44f")
    draw_set_transform(Vector2.ZERO, spin, Vector2.ONE)
    if tex:
        var h := SPRITE_W * tex.get_height() / tex.get_width()
        draw_texture_rect(tex, Rect2(-SPRITE_W / 2.0, -h / 2.0, SPRITE_W, h), false)
    else:
        draw_rect(Rect2(-14, -9, 28, 18), col)
        draw_rect(Rect2(-9, -4, 18, 8), Color("1a0b2e"))
