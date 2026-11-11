extends Node2D
## Пол арены под жанр кассеты. Рисуется один раз при смене жанра, тёмными и неяркими цветами,
## чтобы герой, копии и враги читались поверх. Детали раскладываются по сиду жанра — одинаково каждый раз.

const ARENA := Vector2(720, 1280)
const TILE := 80.0
const BASE := [Color("150a24"), Color("140f1e"), Color("1c0e1c"), Color("0d0a20")]

var genre := -1


func _ready() -> void:
	z_index = -10


func set_genre(value: int) -> void:
	if value == genre:
		return
	genre = value
	queue_redraw()


func _draw() -> void:
	if genre < 0:
		return
	draw_rect(Rect2(Vector2.ZERO, ARENA), BASE[genre % BASE.size()])
	var rng := RandomNumberGenerator.new()
	rng.seed = 1000 + genre
	match genre % 4:
		0:
			_horror(rng)
		1:
			_action(rng)
		2:
			_western(rng)
		3:
			_cyber(rng)


## Ужасы: шахматный кафель, туман и надгробия по краям.
func _horror(rng: RandomNumberGenerator) -> void:
	for y in int(ARENA.y / TILE):
		for x in int(ARENA.x / TILE):
			if (x + y) % 2 == 0:
				draw_rect(Rect2(x * TILE, y * TILE, TILE, TILE), Color("1b0e2e"))
	for i in 7:
		_soft_circle(Vector2(rng.randf_range(0, ARENA.x), rng.randf_range(0, ARENA.y)), rng.randf_range(120, 220))
	for i in 10:
		var left := i % 2 == 0
		var pos := Vector2(rng.randf_range(30, 120), rng.randf_range(200, 1150))
		if not left:
			pos.x = ARENA.x - pos.x
		_gravestone(pos, rng.randf_range(0.8, 1.2), rng.randf() < 0.4)


func _soft_circle(center: Vector2, radius: float) -> void:
	for k in 4:
		draw_circle(center, radius * (1.0 - k * 0.22), Color(0.42, 0.31, 0.66, 0.025))


func _gravestone(pos: Vector2, s: float, cross: bool) -> void:
	var col := Color("24133a")
	if cross:
		draw_rect(Rect2(pos + Vector2(-5, -40) * s, Vector2(10, 46) * s), col)
		draw_rect(Rect2(pos + Vector2(-17, -30) * s, Vector2(34, 9) * s), col)
	else:
		draw_rect(Rect2(pos + Vector2(-16, -22) * s, Vector2(32, 28) * s), col)
		draw_circle(pos + Vector2(0, -22) * s, 16 * s, col)
	draw_rect(Rect2(pos + Vector2(-22, 4) * s, Vector2(44, 6) * s), Color("1e1030"))


## Боевик: асфальт, разметка, зебра и люки.
func _action(rng: RandomNumberGenerator) -> void:
	var line := Color(1.0, 0.96, 0.31, 0.10)
	for lane_x in [240.0, 480.0]:
		var y := -20.0
		while y < ARENA.y:
			draw_rect(Rect2(lane_x - 4, y, 8, 50), line)
			y += 100.0
	for i in 9:
		draw_rect(Rect2(60 + i * 70, 190, 40, 120), Color(0.96, 0.94, 1.0, 0.035))
		draw_rect(Rect2(60 + i * 70, 990, 40, 120), Color(0.96, 0.94, 1.0, 0.035))
	for i in 4:
		var c := Vector2(rng.randf_range(80, 640), rng.randf_range(380, 900))
		draw_circle(c, 26, Color("1e1828"))
		draw_arc(c, 26, 0, TAU, 24, Color("261f33"), 3.0)
	for i in 6:
		var p := Vector2(rng.randf_range(0, ARENA.x), rng.randf_range(0, ARENA.y))
		var pts := PackedVector2Array([p])
		for k in 4:
			p += Vector2(rng.randf_range(-30, 30), rng.randf_range(10, 40))
			pts.append(p)
		draw_polyline(pts, Color("0c0912"), 2.0)


## Вестерн: тёплый песок, гребни дюн, кактусы и камни по краям.
func _western(rng: RandomNumberGenerator) -> void:
	for i in 14:
		var y0 := 80.0 + i * 90.0
		var phase := rng.randf() * TAU
		var pts := PackedVector2Array()
		for k in 25:
			var x := k * 30.0
			pts.append(Vector2(x, y0 + sin(x / 110.0 + phase) * 18.0))
		draw_polyline(pts, Color("2a1424"), 3.0)
	for i in 8:
		var pos := Vector2(rng.randf_range(30, 110), rng.randf_range(220, 1150))
		if i % 2 == 1:
			pos.x = ARENA.x - pos.x
		if rng.randf() < 0.6:
			_cactus(pos, rng.randf_range(0.8, 1.3))
		else:
			draw_circle(pos, rng.randf_range(10, 18), Color("2b1626"))


func _cactus(pos: Vector2, s: float) -> void:
	var col := Color("2f1630")
	draw_rect(Rect2(pos + Vector2(-7, -56) * s, Vector2(14, 60) * s), col)
	draw_circle(pos + Vector2(0, -56) * s, 7 * s, col)
	draw_rect(Rect2(pos + Vector2(-24, -38) * s, Vector2(17, 8) * s), col)
	draw_rect(Rect2(pos + Vector2(-24, -52) * s, Vector2(8, 22) * s), col)
	draw_rect(Rect2(pos + Vector2(7, -30) * s, Vector2(15, 8) * s), col)
	draw_rect(Rect2(pos + Vector2(15, -44) * s, Vector2(8, 22) * s), col)


## Киберпанк: неоновая сетка и дорожки схем.
func _cyber(rng: RandomNumberGenerator) -> void:
	for i in int(ARENA.x / TILE) + 1:
		var bright := i % 3 == 0
		draw_line(Vector2(i * TILE, 0), Vector2(i * TILE, ARENA.y), Color(0, 0.94, 1, 0.12 if bright else 0.05), 2.0)
	for i in int(ARENA.y / TILE) + 1:
		var bright := i % 3 == 0
		draw_line(Vector2(0, i * TILE), Vector2(ARENA.x, i * TILE), Color(0, 0.94, 1, 0.12 if bright else 0.05), 2.0)
	var trace := Color(1.0, 0.18, 0.53, 0.16)
	for i in 12:
		var p := Vector2(rng.randi_range(0, 9), rng.randi_range(0, 16)) * TILE
		var pts := PackedVector2Array([p])
		for k in 3:
			var step := Vector2(rng.randi_range(-2, 2), 0) if k % 2 == 0 else Vector2(0, rng.randi_range(-2, 2))
			p += step * TILE
			pts.append(p)
		draw_polyline(pts, trace, 3.0)
		draw_circle(pts[0], 6, trace)
		draw_circle(pts[pts.size() - 1], 6, trace)
