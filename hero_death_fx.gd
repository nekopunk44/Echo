extends Node2D
## Анимация смерти героя «плёнку зажевало» (VHS-стиль).
## Три фазы: RGB-расслоение → срыв трекинга → выключение кинескопа.
## Создаётся в main.player_died() и живёт ровно один такт смерти (DEATH_BEAT).

const Art := preload("res://art.gd")
# Длина анимации берётся из rewind.gd, а не копируется числом: такт смерти и анимация совпадают всегда.
const LIFE: float = preload("res://rewind.gd").DEATH_BEAT

# Фазы (в долях от LIFE): подобраны под хитстоп 0.12 с — он «замораживает» начало красиво.
const PHASE_RGB_END := 0.30  # 0.0–0.30: RGB-расслоение (в игровом времени ≈ 0–0.15 с)
const PHASE_TEAR_END := 0.70  # 0.30–0.70: срыв трекинга (≈ 0.15–0.35 с)
# 0.70–1.0: выключение кинескопа (≈ 0.35–0.5 с)

# RGB-расслоение
const RGB_OFS_START := 6.0  # начальный сдвиг px: читается уже на первом кадре
const RGB_OFS_END := 12.0  # максимальный сдвиг в фазе срыва трекинга
const RGB_ALPHA := 0.6  # альфа цветных слоёв: не перекрывают основной спрайт полностью

# Срыв трекинга
const STRIPS := 8  # 8 полос — достаточно для эффекта, не слишком дорого
const STRIP_SHIFT_MAX := 40  # максимальный горизонтальный сдвиг полосы, px

# Выключение кинескопа
const CRTOFF_WIDTH_DEFAULT := 50  # ширина белой линии, если нет текстуры (силуэт из art.gd)
const CRTOFF_HEIGHT := 6.0  # толщина линии кинескопа, px: тоньше на снимке телефона почти не видна
const CRTOFF_STRETCH := 1.3  # линия шире героя: экран «схлопывается» за края кадра
const CRTOFF_GLOW := Color(0.0, 0.94, 1.0, 0.3)  # голубой ореол вокруг линии, как у гаснущего люминофора
const SQUASH_PART := 0.5  # первая половина фазы: спрайт сплющивается в линию, дальше гаснет одна линия
const SQUASH_TINT := Color(1.8, 1.8, 1.8)  # яркость сверх 1: сплющенный кадр светится, как гаснущий кинескоп

# Данные кадра героя: заполняются main.gd перед add_child()
var hero_tex: Texture2D  # лента кадров (walk_tex) или одиночный спрайт (tex), null — силуэт
var hero_frames: int = 1  # число кадров в ленте; 1 для одиночного спрайта
var hero_frame: int = 0  # индекс кадра в момент смерти
var hero_flip: bool = false  # направление: true = смотрел влево
var hero_h: float = 80.0  # высота спрайта в px (Player.SPRITE_H)

# Внутреннее состояние
var _t := 0.0  # накопленное игровое время (учитывает time_scale → хитстоп замедляет начало)

# Данные полос: считаются один раз в _ready(), в _draw() без аллокаций
var _strip_shifts: PackedFloat32Array  # итоговый сдвиг полосы: знак чередуется, величина случайная
var _strip_phase: PackedByteArray  # сдвиг мерцания полосы: пропадает каждый третий кадр, но не вся разом


func _ready() -> void:
	add_to_group("fx")  # _clear_world() уберёт узел при новом забеге
	# Генерируем данные полос один раз: в _draw() только читаем.
	_strip_shifts.resize(STRIPS)
	_strip_phase.resize(STRIPS)
	for i in STRIPS:
		# Знак чередуется, амплитуда случайная — полосы уезжают в разные стороны
		var dir := 1.0 if i % 2 == 0 else -1.0
		_strip_shifts[i] = dir * randf_range(STRIP_SHIFT_MAX * 0.3, STRIP_SHIFT_MAX)
		_strip_phase[i] = randi() % 3


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var p := _t / LIFE  # прогресс анимации 0..1

	if hero_tex == null:
		# Только фаза 3 — белая линия (силуэт не имеет текстуры для полос и хроматики)
		_draw_crtoff(p, CRTOFF_WIDTH_DEFAULT)
		return

	if p < PHASE_RGB_END:
		_draw_rgb()
	elif p < PHASE_TEAR_END:
		_draw_tear(p)
	else:
		_draw_squash(p)
		_draw_crtoff(p, _sprite_width())


## Фаза 1: RGB-расслоение — основной спрайт плюс розовый и голубой слои со сдвигом.
func _draw_rgb() -> void:
	var ofs := RGB_OFS_START  # в этой фазе сдвиг постоянный, растёт он только при срыве трекинга
	# Розовый слой — левее (сдвиг по x отрицательный)
	_draw_sprite_tinted(Vector2(-ofs, 0.0), Color(Art.PINK, RGB_ALPHA))
	# Голубой слой — правее
	_draw_sprite_tinted(Vector2(ofs, 0.0), Color(Art.CYAN, RGB_ALPHA))
	# Основной спрайт поверх
	_draw_sprite_tinted(Vector2.ZERO, Color.WHITE)


## Фаза 2: срыв трекинга — полосы уезжают в стороны, мерцают; RGB-расслоение растёт до RGB_OFS_END.
func _draw_tear(p: float) -> void:
	# Нормализованный прогресс внутри фазы TEAR: 0.0 → 1.0
	var tp := (p - PHASE_RGB_END) / (PHASE_TEAR_END - PHASE_RGB_END)
	var rgb_ofs := lerpf(RGB_OFS_START, RGB_OFS_END, tp)

	# Определяем регион кадра в текстуре
	var cw := hero_tex.get_width() / float(hero_frames)
	var ch := float(hero_tex.get_height())
	var w := hero_h * cw / ch
	var frame_rect := Rect2(hero_frame * cw, 0.0, cw, ch)
	var strip_h := ch / STRIPS  # высота полосы в пикселях текстуры
	var strip_dh := hero_h / STRIPS  # высота полосы на экране

	# Флаг мерцания: переключается каждый кадр двигла (~60 Гц)
	var tick := Engine.get_process_frames()

	# RGB-слои рисуются как полосы (для согласованности эффекта)
	for i in STRIPS:
		var src_y := i * strip_h
		var dst_y := -hero_h / 2.0 + i * strip_dh
		if (tick + _strip_phase[i]) % 3 == 0:  # мерцание: полоса пропадает на кадр
			continue
		var shift := _strip_shifts[i] * tp

		# Dst-прямоугольник полосы (без flip: flip применяется через draw_set_transform)
		var dst := Rect2(-w / 2.0 + shift, dst_y, w, strip_dh)
		var src := Rect2(frame_rect.position + Vector2(0.0, src_y), Vector2(frame_rect.size.x, strip_h))

		# Розовый слой левее, голубой правее — как в первой фазе, иначе слои перескакивают
		_draw_strip_region(dst, src, Color(Art.PINK, RGB_ALPHA), -rgb_ofs)
		_draw_strip_region(dst, src, Color(Art.CYAN, RGB_ALPHA), rgb_ofs)
		# Основная полоса
		_draw_strip_region(dst, src, Color.WHITE, 0.0)


## Фаза 3: выключение кинескопа — спрайт сжимается в яркую горизонтальную линию.
func _draw_crtoff(p: float, line_w: float) -> void:
	# Нормализованный прогресс внутри фазы CRT-OFF: 0.0 → 1.0
	var cp := (p - PHASE_TEAR_END) / (1.0 - PHASE_TEAR_END)
	cp = clampf(cp, 0.0, 1.0)
	# Пока кадр сплющивается, линия горит в полную силу; потом стягивается в точку и гаснет
	var shrink := clampf((cp - SQUASH_PART) / (1.0 - SQUASH_PART), 0.0, 1.0)
	var lw := line_w * CRTOFF_STRETCH * (1.0 - shrink)
	var lh := CRTOFF_HEIGHT * (1.0 - 0.5 * shrink)
	if lw < 1.0:
		return
	var alpha := 1.0 - shrink * shrink
	# Ореол в два слоя: одним прямоугольником он читался как полоска интерфейса, а не как свечение
	draw_rect(Rect2(-lw / 2.0 - 10.0, -lh * 2.5, lw + 20.0, lh * 5.0), Color(CRTOFF_GLOW, CRTOFF_GLOW.a * 0.4 * alpha))
	draw_rect(Rect2(-lw / 2.0 - 4.0, -lh * 1.2, lw + 8.0, lh * 2.4), Color(CRTOFF_GLOW, CRTOFF_GLOW.a * alpha))
	draw_rect(Rect2(-lw / 2.0, -lh / 2.0, lw, lh), Color(Art.WHITE, alpha))


## Начало фазы 3: кадр сплющивается по вертикали и светлеет, пока не станет линией.
func _draw_squash(p: float) -> void:
	if hero_tex == null:
		return
	var k := clampf((p - PHASE_TEAR_END) / (1.0 - PHASE_TEAR_END) / SQUASH_PART, 0.0, 1.0)
	if k >= 1.0:
		return
	var cw := hero_tex.get_width() / float(hero_frames)
	var ch := float(hero_tex.get_height())
	var w := hero_h * cw / ch
	var src := Rect2(hero_frame * cw, 0.0, cw, ch)
	var dst := Rect2(-w / 2.0, -hero_h / 2.0, w, hero_h)
	var sx := (-1.0 if hero_flip else 1.0) * (1.0 + 0.3 * k)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(sx, maxf(0.02, 1.0 - k)))
	draw_texture_rect_region(hero_tex, dst, src, SQUASH_TINT)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ---------- вспомогательные функции ----------


## Рисует полосу текстуры со смещением по x (для хроматических аберраций).
## Вызывается из _draw_tear() для каждой полосы и каждого хроматического слоя.
func _draw_strip_region(dst: Rect2, src: Rect2, tint: Color, x_shift: float) -> void:
	var scale_x := -1.0 if hero_flip else 1.0
	# draw_set_transform со scale.x = -1 зеркалит, как делает Art.sprite_frame()
	draw_set_transform(Vector2(x_shift, 0.0), 0.0, Vector2(scale_x, 1.0))
	draw_texture_rect_region(hero_tex, dst, src, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Рисует весь спрайт (или кадр ленты) с заданным цветом-тинтом и смещением по x.
func _draw_sprite_tinted(x_ofs: Vector2, tint: Color) -> void:
	var cw := hero_tex.get_width() / float(hero_frames)
	var ch := float(hero_tex.get_height())
	var w := hero_h * cw / ch
	var src := Rect2(hero_frame * cw, 0.0, cw, ch)
	var dst := Rect2(-w / 2.0, -hero_h / 2.0, w, hero_h)
	var scale_x := -1.0 if hero_flip else 1.0
	draw_set_transform(x_ofs, 0.0, Vector2(scale_x, 1.0))
	draw_texture_rect_region(hero_tex, dst, src, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Ширина спрайта на экране в px (нужна для финальной линии кинескопа).
func _sprite_width() -> float:
	if hero_tex == null:
		return CRTOFF_WIDTH_DEFAULT
	var cw := hero_tex.get_width() / float(hero_frames)
	var ch := float(hero_tex.get_height())
	return hero_h * cw / ch
