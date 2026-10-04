extends Node2D
## Зерно попкорна: летит, взрывается о первого врага или в конце дальности (взрыв по области).

var main
var source := "player"
var vel := Vector2.ZERO
var damage := 1.0
var radius := 55.0
var max_range := 480.0
var travelled := 0.0
var spin := 0.0


func _ready() -> void:
    add_to_group("bullets")


func _physics_process(delta: float) -> void:
    spin += delta * 10.0
    position += vel * delta
    travelled += vel.length() * delta
    var boom := travelled >= max_range
    if not boom:
        for e in get_tree().get_nodes_in_group("enemies"):
            if not e.dead and position.distance_to(e.position) < radius * 0.7 + e.hit_r * 0.5:   # подрыв рядом с врагом
                boom = true
                break
    if boom:
        var col := Color("fff44f") if source == "player" else Color("00f0ff")
        main.explode_at(position, radius, damage, source, col)
        queue_free()
        return
    queue_redraw()


func _draw() -> void:
    var tint := Color("fff44f") if source == "player" else Color("00f0ff")
    draw_circle(Vector2.ZERO, 9.0, Color("fff7d6"))
    for i in 5:
        var a := spin + i * TAU / 5.0
        draw_circle(Vector2(cos(a), sin(a)) * 7.0, 5.0, tint)
