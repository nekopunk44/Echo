extends Node2D
## Смерть врага: рассыпается в помехи (цветные блоки, привязанные к сетке 4 px). Без крови.

const Art := preload("res://art.gd")

var col := Color.WHITE
var parts: Array = []
var life := 0.45
var t := 0.0


func _ready() -> void:
    add_to_group("fx")
    var palette := [col, Art.CYAN, Art.PINK]
    for i in 14:
        var a := randf() * TAU
        var sp := randf_range(60.0, 260.0)
        parts.append({
            "p": Vector2(randf_range(-10, 10), randf_range(-10, 10)),
            "v": Vector2(cos(a), sin(a)) * sp,
            "s": Vector2(randf_range(4, 16), randf_range(2, 6)),
            "c": palette[randi() % 3],
        })


func _process(delta: float) -> void:
    t += delta
    if t >= life:
        queue_free()
        return
    for p in parts:
        p["p"] += p["v"] * delta
        p["v"] *= 0.92
    queue_redraw()


func _draw() -> void:
    var k := 1.0 - t / life
    # быстрая горизонтальная полоса помех
    draw_rect(Rect2(-34, -1, 68, 2), Color(1, 1, 1, k * k))
    for p in parts:
        var pos: Vector2 = p["p"]
        var s: Vector2 = p["s"]
        var c: Color = p["c"]
        pos = Vector2(snappedf(pos.x, 4.0), snappedf(pos.y, 4.0))
        draw_rect(Rect2(pos - s / 2.0, s), Color(c, k))
