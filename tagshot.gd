extends Node2D
## Ценник: летит к выбранному врагу, бьёт и вешает метку (метка усиливает урон от всех, и от копий тоже).

const SPEED := 820.0

var main
var target: Node2D
var source := "player"
var damage := 1.3
var mark_dur := 5.0
var mark_mult := 1.3
var boom_r := 0.0
var boom_dmg := 0.0
var pop_r := 0.0       # Монтаж «Распродажа»: взрыв попкорном при попадании
var pop_dmg := 0.0


func _ready() -> void:
    add_to_group("bullets")


func _physics_process(delta: float) -> void:
    if not is_instance_valid(target) or target.dead:
        queue_free()
        return
    var to := target.position - position
    if to.length() < 26.0 + target.hit_r * 0.3:
        target.hit(damage, source)
        target.mark(mark_dur, mark_mult, boom_r, boom_dmg, source)
        if pop_r > 0.0:
            main.explode_at(target.position, pop_r, pop_dmg, source, Color("fff44f"))
        queue_free()
        return
    position += to.normalized() * SPEED * delta
    rotation = to.angle()
    queue_redraw()


func _draw() -> void:
    var col := Color("ff2e88") if source == "player" else Color("00f0ff")
    draw_colored_polygon(PackedVector2Array([
        Vector2(-14, -9), Vector2(8, -9), Vector2(16, 0), Vector2(8, 9), Vector2(-14, 9)]), col)
    draw_rect(Rect2(-10, -3, 14, 6), Color("fff44f"))
    draw_circle(Vector2(9, 0), 2.5, Color("1a0b2e"))
