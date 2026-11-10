extends Camera2D
## Камера и ход времени: тряска, хитстоп на крупных событиях и замедление «Фокуса».
## Engine.time_scale меняется только здесь, чтобы эффекты не спорили друг с другом.

const MAX_SHAKE := 22.0  # смещение в px при trauma = 1
const SHAKE_DECAY := 1.8  # trauma в секунду реального времени
const HITSTOP_SCALE := 0.05

var trauma := 0.0
var focus_scale := 1.0  # скорость мира, которую просит «Фокус»
var _hitstop_left := 0.0


func _ready() -> void:
	anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	make_current()


## Тряска копится: несколько ударов подряд трясут сильнее одного.
func shake(amount: float) -> void:
	trauma = minf(1.0, trauma + amount)


## Мир почти замирает на seconds реального времени.
func hitstop(seconds: float) -> void:
	_hitstop_left = maxf(_hitstop_left, seconds)


## Пауза, меню, новый дубль: время снова идёт как обычно.
func reset() -> void:
	trauma = 0.0
	focus_scale = 1.0
	_hitstop_left = 0.0
	offset = Vector2.ZERO
	Engine.time_scale = 1.0


func _process(delta: float) -> void:
	var real := delta / maxf(Engine.time_scale, 0.01)
	_hitstop_left = maxf(0.0, _hitstop_left - real)
	Engine.time_scale = focus_scale * (HITSTOP_SCALE if _hitstop_left > 0.0 else 1.0)
	trauma = maxf(0.0, trauma - SHAKE_DECAY * real)
	var k := trauma * trauma * MAX_SHAKE
	offset = Vector2(randf_range(-k, k), randf_range(-k, k))
