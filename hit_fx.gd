extends Node2D
## Эффекты попаданий: цифры нанесённого урона и искры от пуль на всей арене.
## Один узел на главную сцену с кольцевыми буферами фиксированного размера,
## чтобы избежать постоянных аллокаций памяти при сотнях попаданий в секунду.

const Art := preload("res://art.gd")

const MAX_NUMBERS := 40  # максимум одновременных цифр урона; при переполнении перезаписываются самые старые
const MAX_SPARKS := 24  # максимум вспышек искр, чтобы не перегружать кадр сотнями линий
const DISPLAY_SCALE := 10.0  # урон оружия 0.45–3.0: умножаем на 10, так как целые числа читаются намного легче
const NUMBER_LIFE := 0.6  # время жизни всплывающей цифры (секунды): оптимум для читаемости без замусоривания
const NUMBER_RISE := 44.0  # расстояние всплытия цифры вверх в пикселях
const POP_TIME := 0.08  # длительность начального «выпрыгивания» цифры с увеличенным масштабом
const POP_SCALE := 1.5  # начальный увеличенный масштаб цифры в момент появления
const FADE_TIME := 0.2  # длительность затухания альфы цифры перед исчезновением
const FONT_SIZE_DEFAULT := 22  # базовый размер шрифта цифр для обычных попаданий игрока и копий
const FONT_SIZE_SYNCED := 30  # увеличенный размер шрифта для синхро-ударов (сильный акцент)
const OUTLINE_SIZE := 6  # толщина обводки тёмным цветом для читаемости цифры на любом фоне
const SPARK_LIFE := 0.12  # время жизни искры: ультракороткий визуальный отклик на удар
const SPARK_MIN_LEN := 6.0  # начальная длина лучей искры в пикселях
const SPARK_MAX_LEN := 18.0  # конечная длина лучей искры в пикселях перед затуханием
const SPARK_WIDTH := 3.0  # толщина лучей искр в пикселях

var _numbers: Array = []
var _sparks: Array = []
var _num_head := 0
var _spark_head := 0
var _was_active := false


func _init() -> void:
	z_index = 50  # цифры урона и искры должны быть поверх всех врагов и снарядов
	for i in MAX_NUMBERS:
		(
			_numbers
			. append(
				{
					"active": false,
					"pos": Vector2.ZERO,
					"ofs_x": 0.0,
					"text": "",
					"width": 0.0,
					"font_size": FONT_SIZE_DEFAULT,
					"color": Color.WHITE,
					"time": 0.0,
				}
			)
		)
	for i in MAX_SPARKS:
		(
			_sparks
			. append(
				{
					"active": false,
					"pos": Vector2.ZERO,
					"angle": 0.0,
					"color": Color.WHITE,
					"time": 0.0,
				}
			)
		)


func _process(delta: float) -> void:
	var any_active := false
	for i in MAX_NUMBERS:
		var n: Dictionary = _numbers[i]
		if not n["active"]:
			continue
		n["time"] += delta
		if n["time"] >= NUMBER_LIFE:
			n["active"] = false
		else:
			any_active = true

	for i in MAX_SPARKS:
		var s: Dictionary = _sparks[i]
		if not s["active"]:
			continue
		s["time"] += delta
		if s["time"] >= SPARK_LIFE:
			s["active"] = false
		else:
			any_active = true

	if any_active or _was_active:
		queue_redraw()
	_was_active = any_active


func _draw() -> void:
	for i in MAX_NUMBERS:
		var n: Dictionary = _numbers[i]
		if not n["active"]:
			continue
		var t: float = n["time"]
		var p := t / NUMBER_LIFE
		# Замедление подъёма к концу: квадратичный ease-out
		var rise_k := 1.0 - (1.0 - p) * (1.0 - p)
		var cur_pos: Vector2 = n["pos"] + Vector2(n["ofs_x"], -NUMBER_RISE * rise_k)

		# Начальное выпрыгивание масштаба в первые POP_TIME секунд
		var s := 1.0
		if t < POP_TIME:
			s = lerpf(POP_SCALE, 1.0, t / POP_TIME)

		# Затухание альфы в последние FADE_TIME секунд
		var alpha := 1.0
		var fade_start := NUMBER_LIFE - FADE_TIME
		if t > fade_start:
			alpha = clampf((NUMBER_LIFE - t) / FADE_TIME, 0.0, 1.0)

		var w: float = n["width"]
		var fsize: int = n["font_size"]
		var txt: String = n["text"]
		var base_col: Color = n["color"]

		draw_set_transform(cur_pos, 0.0, Vector2(s, s))
		var draw_pos := Vector2(-w * 0.5, fsize * 0.35)
		draw_string_outline(
			Art.OSD_FONT,
			draw_pos,
			txt,
			HORIZONTAL_ALIGNMENT_CENTER,
			w,
			fsize,
			OUTLINE_SIZE,
			Color(Art.DARK.r, Art.DARK.g, Art.DARK.b, alpha)
		)
		draw_string(
			Art.OSD_FONT,
			draw_pos,
			txt,
			HORIZONTAL_ALIGNMENT_CENTER,
			w,
			fsize,
			Color(base_col.r, base_col.g, base_col.b, alpha)
		)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	for i in MAX_SPARKS:
		var sp: Dictionary = _sparks[i]
		if not sp["active"]:
			continue
		var st: float = sp["time"]
		var prog := st / SPARK_LIFE
		var spark_len := lerpf(SPARK_MIN_LEN, SPARK_MAX_LEN, prog)
		var spark_alpha := 1.0 - prog
		var sp_col: Color = sp["color"]
		var draw_col := Color(sp_col.r, sp_col.g, sp_col.b, spark_alpha)
		var base_ang: float = sp["angle"]
		var origin: Vector2 = sp["pos"]

		for ray in 4:
			var ang := base_ang + ray * (PI * 0.5)
			var dir := Vector2(cos(ang), sin(ang))
			draw_line(origin, origin + dir * spark_len, draw_col, SPARK_WIDTH)


func add_number(pos: Vector2, dmg: float, source: String, synced: bool) -> void:
	var val := maxi(1, roundi(dmg * DISPLAY_SCALE))
	var txt := str(val)
	var fsize := FONT_SIZE_SYNCED if synced else FONT_SIZE_DEFAULT
	var col := Art.YELLOW if synced else (Art.CYAN if source == "ghost" else Art.WHITE)
	var w: float = Art.OSD_FONT.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x

	var item: Dictionary = _numbers[_num_head]
	_num_head = (_num_head + 1) % MAX_NUMBERS
	item["active"] = true
	item["pos"] = pos
	item["ofs_x"] = randf_range(-12.0, 12.0)
	item["text"] = txt
	item["width"] = w
	item["font_size"] = fsize
	item["color"] = col
	item["time"] = 0.0


func add_spark(pos: Vector2, synced: bool) -> void:
	var item: Dictionary = _sparks[_spark_head]
	_spark_head = (_spark_head + 1) % MAX_SPARKS
	item["active"] = true
	item["pos"] = pos
	item["angle"] = randf() * TAU
	item["color"] = Art.WHITE if synced else Art.YELLOW  # на белой вспышке врага белая искра пропадает
	item["time"] = 0.0


func clear() -> void:
	for i in MAX_NUMBERS:
		_numbers[i]["active"] = false
	for i in MAX_SPARKS:
		_sparks[i]["active"] = false
	_num_head = 0
	_spark_head = 0
	_was_active = false
	queue_redraw()


func alive_numbers() -> int:
	var count := 0
	for i in MAX_NUMBERS:
		if _numbers[i]["active"]:
			count += 1
	return count
