extends CharacterBody2D
## Игрок: левый стик (плавающий, в любом месте экрана) или WASD/стрелки. Атакует сам.
## Рисуется кадрами ходьбы из assets/player_walk.png (запасные варианты: одиночный спрайт, затем силуэт из art.gd).

const Art := preload("res://art.gd")
const SPEED := 340.0
const SPRITE_H := 80.0                 # высота спрайта в игре, px
const LENS := {                        # где на спрайте объектив (для вспышки выстрела)
    "clerk": Vector2(0.0, -16.0),
    "courier": Vector2(-1.2, -17.2),
    "guard": Vector2(-1.4, -17.0),
    "projectionist": Vector2(-2.1, -16.6),
    "popcorn": Vector2(19.8, -23.0),
    "critic": Vector2(19.0, -26.9),
}
const WALK_FRAMES := 8
const IDLE_FRAME := 2                  # кадр "ноги вместе"
const WALK_FPS := 18.0                 # скорость анимации при полном ходе

var walk_tex: Texture2D                # лента кадров ходьбы
var tex: Texture2D                     # одиночный спрайт (запасной)
var flip := false                      # true = смотрит влево
var anim_t := float(IDLE_FRAME)
var frame := IDLE_FRAME

var active := true
var touching := false
var touch_index := -1
var stick_origin := Vector2.ZERO
var stick_pos := Vector2.ZERO
var cds := {}                          # перезарядки оружия
var main

# анимация процедурной заглушки
var facing := 0.0
var facing_target := 0.0
var aim_hold := 0.0
var bob_t := 0.0
var bob := 0.0
var flash_t := 0.0


func _ready() -> void:
    main = get_parent()
    var hero: String = Recorder.hero
    var hp := "res://assets/hero_%s.png" % hero
    if hero == "clerk" and ResourceLoader.exists("res://assets/player_walk.png"):
        walk_tex = load("res://assets/player_walk.png")      # у клерка есть кадры ходьбы
    elif ResourceLoader.exists(hp):
        tex = load(hp)                                      # у остальных пока один спрайт + покачивание
    elif ResourceLoader.exists("res://assets/player.png"):
        tex = load("res://assets/player.png")


func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed and touch_index == -1:
            touch_index = event.index
            touching = true
            stick_origin = event.position
            stick_pos = event.position
        elif not event.pressed and event.index == touch_index:
            touch_index = -1
            touching = false
    elif event is InputEventScreenDrag and event.index == touch_index:
        stick_pos = event.position


func _physics_process(delta: float) -> void:
    if not active:
        velocity = Vector2.ZERO
        return

    var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
    dir += Vector2(
        float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
        float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W)))
    dir = dir.limit_length(1.0)
    if touching:
        dir = (stick_pos - stick_origin).limit_length(100.0) / 100.0

    var lo = main.loadout
    velocity = dir * SPEED * lo.mult("speed")
    move_and_slide()
    position = position.clamp(Vector2(20, 20), main.ARENA - Vector2(20, 20))

    var ratio := clampf(velocity.length() / SPEED, 0.0, 1.0)
    # кадры ходьбы: темп зависит от скорости, на остановке — кадр покоя
    if ratio > 0.05:
        anim_t += ratio * delta * WALK_FPS
        frame = int(anim_t) % WALK_FRAMES
    else:
        anim_t = float(IDLE_FRAME)
        frame = IDLE_FRAME
    # для запасных вариантов
    bob_t += ratio * delta * 14.0
    bob = sin(bob_t) * ratio
    aim_hold = maxf(0.0, aim_hold - delta)
    flash_t = maxf(0.0, flash_t - delta)

    var aim: Vector2 = main.tick_weapons(self, "player", lo, cds, delta)
    if aim != Vector2.ZERO:
        facing_target = aim.angle()
        if absf(aim.x) > 0.05:
            flip = aim.x < 0.0
        aim_hold = 0.3
        flash_t = 0.08

    if aim_hold <= 0.0 and velocity.length() > 10.0:
        facing_target = velocity.angle()
        if absf(velocity.x) > 10.0:
            flip = velocity.x < 0.0
    facing = lerp_angle(facing, facing_target, minf(1.0, 15.0 * delta))
    queue_redraw()


## Сбрасывает виртуальный стик (после паузы выбора палец мог уже оторваться).
func reset_input() -> void:
    touching = false
    touch_index = -1


func _muzzle_flash() -> void:
    if flash_t > 0.0:
        var dir := -1.0 if flip else 1.0
        var lens: Vector2 = LENS.get(Recorder.hero, Vector2(0.0, -16.0))
        draw_circle(Vector2(lens.x * dir + 10.0 * dir, lens.y), 10.0 * flash_t / 0.08, Color(1.0, 0.96, 0.31, 0.9))


func _draw() -> void:
    if walk_tex:
        Art.shadow(self, 24.0, 0.35, SPRITE_H / 2.0 - 4.0)
        Art.sprite_frame(self, walk_tex, WALK_FRAMES, frame, SPRITE_H, flip, Color.WHITE, Vector2.ZERO)
        _muzzle_flash()
        return
    if tex:
        Art.shadow(self, 24.0, 0.35, SPRITE_H / 2.0 - 4.0)
        Art.sprite(self, tex, SPRITE_H, flip, bob, Color.WHITE, Vector2.ZERO)
        _muzzle_flash()
        return
    draw_circle(Vector2.ZERO, 28.0, Color(0.0, 0.94, 1.0, 0.07))   # мягкое свечение
    Art.shadow(self, 16.0)
    var rec_on := fmod(Time.get_ticks_msec() / 1000.0, 1.0) < 0.5
    Art.clerk(self, facing, Art.WHITE, Art.CYAN, Art.YELLOW, bob, rec_on, flash_t / 0.08, Vector2.ZERO)
