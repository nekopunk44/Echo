extends Node2D
## Вспышка камеры: белый конус (или круг) и яркая точка у владельца, быстро гаснет.

var dir_angle := 0.0
var radius := 220.0
var arc_deg := 70.0
var color := Color("fff44f")
var t := 0.0
var life := 0.28


func _process(delta: float) -> void:
    t += delta
    if t >= life:
        queue_free()
        return
    queue_redraw()


func _draw() -> void:
    var k := t / life
    var r := radius * (0.6 + 0.4 * minf(k * 3.0, 1.0))
    if arc_deg >= 359.0:
        draw_circle(Vector2.ZERO, r, Color(1, 1, 1, 0.5 * (1.0 - k)))
    else:
        var half := deg_to_rad(arc_deg) / 2.0
        var pts := PackedVector2Array([Vector2.ZERO])
        var steps := 24
        for i in steps + 1:
            var a := dir_angle - half + 2.0 * half * float(i) / float(steps)
            pts.append(Vector2.from_angle(a) * r)
        draw_colored_polygon(pts, Color(1, 1, 1, 0.55 * (1.0 - k)))
    draw_circle(Vector2.ZERO, 26.0 * (1.0 - k) + 6.0, Color(color, 1.0 - k))
