extends CanvasLayer
## VHS-слой между игровым полем и HUD: шейдер vhs.gdshader и его всплески.
## glitch и вспышка перемотки затухают сами; slow и rewind_hold каждый кадр выставляет main.

const VhsShader := preload("res://vhs.gdshader")
const GLITCH_DECAY := 2.5  # в секунду реального времени
const REWIND_FADE := 4.0

var glitch := 0.0
var slow := 0.0
var rewind := 0.0
var rewind_hold := false  # держать эффект перемотки (пауза между дублями)
var _rewind_left := 0.0
var _mat: ShaderMaterial


func _ready() -> void:
	layer = 1
	process_mode = Node.PROCESS_MODE_ALWAYS
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = VhsShader
	rect.material = _mat
	add_child(rect)


## Короткий срыв картинки: 0.3 — заметный, 1.0 — на весь экран.
func pulse(amount: float) -> void:
	glitch = maxf(glitch, amount)


## Эффект перемотки на заданное время (REWIND после смерти).
func flash_rewind(seconds: float) -> void:
	_rewind_left = maxf(_rewind_left, seconds)


func _process(delta: float) -> void:
	var real := delta / maxf(Engine.time_scale, 0.01)
	glitch = maxf(0.0, glitch - GLITCH_DECAY * real)
	_rewind_left = maxf(0.0, _rewind_left - real)
	var target := 1.0 if rewind_hold or _rewind_left > 0.0 else 0.0
	rewind = move_toward(rewind, target, REWIND_FADE * real)
	_mat.set_shader_parameter("glitch", glitch)
	_mat.set_shader_parameter("slow", slow)
	_mat.set_shader_parameter("rewind", rewind)
