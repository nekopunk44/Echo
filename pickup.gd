extends Node2D
## Осколок опыта: разлетается, притягивается магнитом, при касании даёт XP.
## value: 1 малый, 5 средний, 25 крупный. Жетон перемотки (is_token) ведёт себя так же, но даёт не опыт, а жетон.

const TokenTexture := preload("res://assets/pickup_rewind_token.png")
const Art := preload("res://art.gd")
const TOKEN_SIZE := 44.0  # px: заметно крупнее осколка, чтобы жетон не терялся среди опыта

var value := 1
var main
var target: Node2D
var vel := Vector2.ZERO
var age := 0.0
var attracted := false
var is_token := false
var collected := false  # защита от двойного зачёта: queue_free срабатывает только в конце кадра
var tex: Texture2D
var size_px := 22.0


func _ready() -> void:
	add_to_group("pickups")
	if is_token:
		tex = TokenTexture
		size_px = TOKEN_SIZE
	else:
		if ResourceLoader.exists("res://assets/pickup_xp_film.png"):
			tex = load("res://assets/pickup_xp_film.png")
		size_px = 22.0 if value < 5 else (30.0 if value < 25 else 44.0)
	vel = Vector2.from_angle(randf() * TAU) * randf_range(60.0, 140.0)
	age = randf() * 3.0


## Зачёт подбора: опыт или жетон. Зовут и касание героя, и страховки main (конец дубля, победа, смерть).
func collect() -> void:
	if collected:
		return
	collected = true
	if is_token:
		main.rewind.grant_token()
	else:
		main.add_xp(value)
	queue_free()


func _physics_process(delta: float) -> void:
	age += delta
	if not is_instance_valid(target):
		queue_redraw()
		return
	if main.is_banking():
		attracted = true
	elif not main.is_playing():
		queue_redraw()
		return
	var to := target.position - position
	var d := to.length()
	if d < main.magnet_radius():
		attracted = true
	if attracted:
		vel = vel.lerp(to.normalized() * 720.0, minf(1.0, 8.0 * delta))
	else:
		vel = vel.lerp(Vector2.ZERO, minf(1.0, 4.0 * delta))
	position += vel * delta
	if d < 28.0:
		collect()
		return
	queue_redraw()


func _draw() -> void:
	var bob := sin(age * 4.0) * 2.0
	if is_token:  # пульсирующее кольцо: жетон не спутать с осколком
		var pulse := 0.5 + 0.5 * sin(age * 5.0)
		draw_arc(Vector2.ZERO, size_px * 0.7 + 4.0 * pulse, 0.0, TAU, 32, Color(Art.CYAN, 0.35 + 0.5 * pulse), 3.0)
	draw_set_transform(Vector2(0, bob), sin(age * 3.0) * 0.2, Vector2.ONE)
	if tex:
		var w := size_px * tex.get_width() / tex.get_height()
		draw_texture_rect(tex, Rect2(-w / 2.0, -size_px / 2.0, w, size_px), false)
	else:
		draw_rect(Rect2(-size_px / 2.0, -size_px / 2.0, size_px, size_px), Color("fff44f"))
