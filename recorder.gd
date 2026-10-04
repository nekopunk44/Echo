extends Node
## Autoload "Recorder": пишет путь игрока по физическим тикам (60/сек)
## и таймлайн выбранных плёнок, чтобы копия повторяла билд на момент записи.

const MAX_ECHOES := 5

var ghosts: Array = []              # завершённые дубли: {"path", "levels", "events"}
var current := PackedVector2Array() # путь текущего дубля
var current_levels := {}            # плёнки на начало дубля
var current_events: Array = []      # [[тик, id], ...] — что взято в этом дубле
var recording := false
var hero := "clerk"                 # clerk / courier / guard / projectionist / popcorn / critic


func reset() -> void:
    ghosts.clear()
    current = PackedVector2Array()
    current_levels = {}
    current_events = []
    recording = false


func start_take(levels: Dictionary) -> void:
    current = PackedVector2Array()
    current_levels = levels.duplicate()
    current_events = []
    recording = true


func record(pos: Vector2) -> void:
    if recording:
        current.append(pos)


func record_event(id: String) -> void:
    if recording:
        current_events.append([current.size(), id])


## Дубль сохраняется только если игрок дожил до конца (неудачные секунды не пишутся).
func finish_take() -> void:
    recording = false
    ghosts.append({"path": current, "levels": current_levels, "events": current_events})
    while ghosts.size() > MAX_ECHOES:
        ghosts.pop_front()
