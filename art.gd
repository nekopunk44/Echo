extends RefCounted
## Процедурные силуэты. Все функции рисуют в _draw() переданного CanvasItem.
## Палитра из дизайн-дока: тёмно-фиолетовый фон, розовый / голубой / жёлтый акценты.

const PINK := Color("ff2e88")
const CYAN := Color("00f0ff")
const YELLOW := Color("fff44f")
const DARK := Color("1a0b2e")
const WHITE := Color("f4f0ff")


static func shadow(ci: CanvasItem, r: float, alpha: float = 0.35, y: float = 8.0) -> void:
	ci.draw_set_transform(Vector2(0, y), 0.0, Vector2(1.0, 0.45))
	ci.draw_circle(Vector2.ZERO, r, Color(0, 0, 0, alpha))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Спрайт по центру узла (смотрит вправо в исходнике). flip = зеркалить влево.
## bob (-1..1) даёт шаг: подпрыгивание, лёгкий наклон и сжатие.
static func sprite(ci: CanvasItem, tex: Texture2D, h: float, flip: bool, bob: float,
		tint: Color, ofs: Vector2) -> void:
	var w := h * tex.get_width() / tex.get_height()
	var sq := absf(bob) * 0.05
	var sx := (-1.0 if flip else 1.0) * (1.0 + sq)
	ci.draw_set_transform(ofs + Vector2(0, -absf(bob) * 4.0), bob * 0.05, Vector2(sx, 1.0 - sq))
	ci.draw_texture_rect(tex, Rect2(-w / 2.0, -h / 2.0, w, h), false, tint)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Кадр из ленты одинаковых ячеек (frames штук подряд по горизонтали).
static func sprite_frame(ci: CanvasItem, tex: Texture2D, frames: int, frame: int, h: float,
		flip: bool, tint: Color, ofs: Vector2) -> void:
	var cw := tex.get_width() / float(frames)
	var chh := float(tex.get_height())
	var w := h * cw / chh
	ci.draw_set_transform(ofs, 0.0, Vector2(-1.0 if flip else 1.0, 1.0))
	ci.draw_texture_rect_region(tex, Rect2(-w / 2.0, -h / 2.0, w, h), Rect2(frame * cw, 0.0, cw, chh), tint)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _closed(ci: CanvasItem, pts: PackedVector2Array, col: Color, w: float) -> void:
	var p := pts.duplicate()
	p.append(pts[0])
	ci.draw_polyline(p, col, w)


## Клерк с камерой на плече (вид сверху). angle = куда смотрит (0 = вправо).
## Игрок рисуется "чисто" с яркой обводкой, копии — этой же функцией, но в цветных слоях.
static func clerk(ci: CanvasItem, angle: float, body: Color, line: Color, accent: Color,
		bob: float, rec_on: bool, flash: float, ofs: Vector2) -> void:
	ci.draw_set_transform(ofs, angle, Vector2.ONE)
	var sway := 1.0 + bob * 0.08

	# плечи
	var sh := PackedVector2Array()
	for i in 14:
		var a := TAU * i / 14.0
		sh.append(Vector2(cos(a) * 9.0, sin(a) * 17.0 * sway))
	ci.draw_colored_polygon(sh, body)
	_closed(ci, sh, line, 3.0)

	# бейдж на груди
	ci.draw_rect(Rect2(-3, -7, 3, 6), accent)

	# голова и козырёк кепки
	ci.draw_circle(Vector2(3, 0), 9.0, body)
	ci.draw_arc(Vector2(3, 0), 9.0, 0.0, TAU, 20, line, 3.0)
	ci.draw_rect(Rect2(10, -6, 6, 12), accent)

	# камера на правом плече
	ci.draw_rect(Rect2(2, 10, 18, 11), accent)
	ci.draw_rect(Rect2(2, 10, 18, 11), line, false, 2.0)
	ci.draw_circle(Vector2(22, 15.5), 5.0, line)
	ci.draw_circle(Vector2(22, 15.5), 2.5, DARK)
	if rec_on:
		ci.draw_circle(Vector2(6, 13), 2.0, Color("ff2e2e"))
	if flash > 0.0:
		ci.draw_circle(Vector2(28, 15.5), 9.0 * flash, Color(1.0, 0.96, 0.31, 0.9))

	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Маньяк: торс, руки с ножом, хоккейная маска.
static func maniac(ci: CanvasItem, angle: float, t: float, col: Color) -> void:
	shadow(ci, 18.0)
	ci.draw_set_transform(Vector2.ZERO, angle + sin(t * 9.0) * 0.1, Vector2.ONE)
	ci.draw_line(Vector2(4, -11), Vector2(22, -6), col, 6.0)
	ci.draw_line(Vector2(4, 11), Vector2(22, 7), col, 6.0)
	ci.draw_line(Vector2(22, 7), Vector2(37, 5), WHITE, 3.0)
	var body := PackedVector2Array()
	for i in 12:
		var a := TAU * i / 12.0
		body.append(Vector2(cos(a) * 13.0, sin(a) * 19.0))
	ci.draw_colored_polygon(body, col)
	ci.draw_circle(Vector2(6, 0), 10.0, WHITE)
	ci.draw_rect(Rect2(8, -6, 3, 3), DARK)
	ci.draw_rect(Rect2(8, 3, 3, 3), DARK)
	ci.draw_rect(Rect2(12, -1, 2, 2), DARK)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Призрак: простыня с волнистым низом, парит. look — куда смотрят глаза.
static func phantom(ci: CanvasItem, t: float, look: Vector2, col: Color) -> void:
	shadow(ci, 14.0, 0.25)
	ci.draw_set_transform(Vector2(0, sin(t * 3.0) * 3.0 - 4.0), 0.0, Vector2.ONE)
	var pts := PackedVector2Array()
	for i in 9:
		var a := PI + PI * i / 8.0
		pts.append(Vector2(cos(a) * 16.0, sin(a) * 16.0 - 2.0))
	for j in 7:
		var x := 16.0 - 32.0 * j / 6.0
		pts.append(Vector2(x, 16.0 + sin(t * 8.0 + x * 0.5) * 3.0))
	ci.draw_colored_polygon(pts, Color(col, 0.9))
	ci.draw_circle(Vector2(-5, -6) + look * 2.0, 3.5, DARK)
	ci.draw_circle(Vector2(5, -6) + look * 2.0, 3.5, DARK)
	ci.draw_circle(Vector2(0, 2) + look * 2.0, 2.5, DARK)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Дрон: ромб с четырьмя вращающимися винтами и красным глазом.
static func drone(ci: CanvasItem, t: float, col: Color) -> void:
	shadow(ci, 14.0)
	ci.draw_set_transform(Vector2(0, sin(t * 5.0) * 2.0 - 3.0), 0.0, Vector2.ONE)
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(0, -14), Vector2(14, 0), Vector2(0, 14), Vector2(-14, 0)]), col)
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var c := Vector2(sx * 15.0, sy * 15.0)
			ci.draw_line(c, Vector2(sx * 7.0, sy * 7.0), col, 3.0)
			var ang: float = t * 40.0 + sx + sy * 2.0
			var d := Vector2(cos(ang), sin(ang)) * 8.0
			ci.draw_line(c - d, c + d, Color(1, 1, 1, 0.8), 2.0)
			ci.draw_circle(c, 2.0, col)
	ci.draw_circle(Vector2.ZERO, 5.0, DARK)
	ci.draw_circle(Vector2.ZERO, 2.5, PINK)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
