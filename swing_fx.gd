extends Node2D
## Дуга удара биты: быстро гаснет.

var dir_angle := 0.0
var radius := 100.0
var arc_deg := 110.0
var color := Color("fff44f")
var t := 0.0
var life := 0.22


func _process(delta: float) -> void:
    t += delta
    if t >= life:
        queue_free()
        return
    queue_redraw()


func _draw() -> void:
    var k := t / life
    var half := deg_to_rad(arc_deg) / 2.0
    var a0 := dir_angle - half
    var a1 := dir_angle + half
    var r := radius * (0.7 + 0.3 * k)
    draw_arc(Vector2.ZERO, r, a0, a1, 40, Color(color, 1.0 - k), 16.0 * (1.0 - k) + 4.0)
    draw_arc(Vector2.ZERO, r * 0.8, a0, a1, 40, Color(1, 1, 1, 0.7 * (1.0 - k)), 5.0)
