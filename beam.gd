extends Node2D
## Луч фонаря: следит за ближайшим врагом и жжёт всё в конусе.
## Чем дольше враг в луче, тем сильнее ожог (если ramp > 0). Против жанра «Ужасы» урон ×1.5.

const TICK := 0.12

var owner_node: Node2D
var main
var source := "player"
var dir := Vector2.RIGHT
var damage := 0.45
var length := 260.0
var width := 36.0
var duration := 1.2
var ramp := 0.0

var t := 0.0
var tick_t := 0.0
var in_beam := {}      # id врага -> сколько секунд в луче


func _ready() -> void:
    add_to_group("bullets")


func _physics_process(delta: float) -> void:
    t += delta
    if t >= duration or not is_instance_valid(owner_node):
        queue_free()
        return
    position = owner_node.position

    # довернуть к ближайшему врагу
    var best = null
    var best_d := length * length * 1.6
    for e in get_tree().get_nodes_in_group("enemies"):
        if e.dead:
            continue
        var d := position.distance_squared_to(e.position)
        if d < best_d:
            best_d = d
            best = e
    if best != null:
        var want: Vector2 = (best.position - position).normalized()
        var mixed := dir.lerp(want, minf(1.0, 10.0 * delta))
        dir = mixed.normalized() if mixed.length() > 0.01 else want

    tick_t -= delta
    if tick_t <= 0.0:
        tick_t = TICK
        _burn()
    queue_redraw()


func _burn() -> void:
    var seen := {}
    for e in get_tree().get_nodes_in_group("enemies"):
        if e.dead:
            continue
        var v: Vector2 = e.position - position
        var along := v.dot(dir)
        if along < -10.0 or along > length + e.hit_r:
            continue
        var half: float = width / 2.0 * (0.35 + 0.65 * clampf(along / length, 0.0, 1.0)) + e.hit_r * 0.5
        if absf(v.cross(dir)) > half:
            continue
        var id: int = e.get_instance_id()
        seen[id] = true
        in_beam[id] = float(in_beam.get(id, 0.0)) + TICK
        var k := 1.0
        if ramp > 0.0:
            k = 1.0 + minf(1.0, float(in_beam[id]) / ramp)
        if main.genre == 0:
            k *= 1.5
        e.hit(damage * k, source)
    for id in in_beam.keys():
        if not seen.has(id):
            in_beam.erase(id)


func _draw() -> void:
    var col := Color("fff44f") if source == "player" else Color("00f0ff")
    var fade := clampf(minf(t, duration - t) / 0.12, 0.0, 1.0)
    var n := Vector2(-dir.y, dir.x)
    var near_w := width / 2.0 * 0.35
    var far_w := width / 2.0
    var tip := dir * length
    draw_colored_polygon(PackedVector2Array([n * near_w, tip + n * far_w, tip - n * far_w, -n * near_w]),
        Color(col, 0.22 * fade))
    draw_line(n * near_w, tip + n * far_w, Color(col, 0.6 * fade), 3.0)
    draw_line(-n * near_w, tip - n * far_w, Color(col, 0.6 * fade), 3.0)
    draw_line(Vector2.ZERO, tip, Color(1, 1, 1, 0.45 * fade), 4.0)
