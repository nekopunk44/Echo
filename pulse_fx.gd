extends Node2D
## Стоп-кадр пульта: расходящееся кольцо и две полоски паузы.

var radius := 170.0
var color := Color("fff44f")
var t := 0.0
var life := 0.5
var bars := true    # две полоски паузы в центре (для пульта)


func _process(delta: float) -> void:
    t += delta
    if t >= life:
        queue_free()
        return
    queue_redraw()


func _draw() -> void:
    var k := t / life
    var e := 1.0 - pow(1.0 - minf(k * 2.0, 1.0), 3.0)
    var r := radius * e
    draw_circle(Vector2.ZERO, r, Color(color, 0.12 * (1.0 - k)))
    draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(color, 1.0 - k), 6.0)
    if bars:
        draw_rect(Rect2(-15, -24, 10, 48), Color(1, 1, 1, 1.0 - k))
        draw_rect(Rect2(5, -24, 10, 48), Color(1, 1, 1, 1.0 - k))
