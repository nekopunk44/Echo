extends Node
## Активная способность «Фокус»: замедляет мир на короткое время и ждёт перезарядки.

const SCALE := 0.4
const DURATION := 2.0
const COOLDOWN := 8.0

var main
var active_timer: Timer
var cooldown_timer: Timer
var active := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	active_timer = _timer()
	active_timer.timeout.connect(cancel)
	add_child(active_timer)
	cooldown_timer = _timer()
	add_child(cooldown_timer)


## Запустить способность, если игра идёт и перезарядка закончилась.
func activate() -> bool:
	if main.state != main.State.PLAY or active or cooldown_timer.time_left > 0.0:
		return false
	active = true
	main.cam.focus_scale = SCALE
	active_timer.start(DURATION)
	cooldown_timer.start(COOLDOWN)
	main.hud.show_focus(true, true, remaining(), cooldown_remaining())
	return true


## Снять замедление при переходе в состояние, где игрок не управляет героем.
func cancel() -> void:
	if active:
		active = false
		active_timer.stop()
		main.cam.focus_scale = 1.0
		main.hud.show_focus(main.state == main.State.PLAY, false, 0.0, cooldown_remaining())


## Сбросить способность при начале нового забега.
func reset() -> void:
	cancel()
	cooldown_timer.stop()
	main.hud.show_focus(main.state == main.State.PLAY, false, 0.0, 0.0)


func remaining() -> float:
	return active_timer.time_left if active else 0.0


func cooldown_remaining() -> float:
	return cooldown_timer.time_left


func _process(_delta: float) -> void:
	if main.state != main.State.PLAY:
		cancel()
		main.hud.show_focus(false, false, 0.0, cooldown_remaining())


func _timer() -> Timer:
	var timer := Timer.new()
	timer.one_shot = true
	timer.ignore_time_scale = true
	timer.process_mode = Node.PROCESS_MODE_PAUSABLE
	return timer
