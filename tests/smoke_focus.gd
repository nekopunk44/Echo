extends RefCounted
## Проверки активной способности «Фокус» для дымового прогона.

var t


func _init(host) -> void:
	t = host


func run() -> void:
	var focus = t.main.focus
	t._expect(not focus.activate(), "фокус: способность доступна в меню")
	t.main.run_menu.campaign_requested.emit("clerk")
	t._expect(t.main.state == t.main.State.PLAY, "фокус: забег не начался")
	await t.get_tree().process_frame

	var button: Button = t.main.hud.focus_button
	t._expect(button.visible, "фокус: кнопка не показана в игре")
	t._expect(button.size.x >= 88.0 and button.size.y >= 88.0, "фокус: кнопка меньше 88 px")
	t._expect(t.main.hud.focus_button_icon.texture != null, "фокус: на кнопке нет иконки")
	t._expect(t.main.hud.focus_bubble.visible, "фокус: облачко готовности не показано")
	t._expect(t.main.hud._focus_bubble_tween.is_running(), "фокус: облачко готовности не анимируется")
	_expect_touch_does_not_move_player(button)
	button.pressed.emit()
	t._expect(focus.active, "фокус: нажатие кнопки не включило способность")
	t._expect(not t.main.hud.focus_bubble.visible, "фокус: облачко готовности не скрылось после активации")
	t._expect(is_equal_approx(t.main.cam.focus_scale, focus.SCALE), "фокус: время не замедлилось")
	t.main.cam._process(1.0 / 60.0)
	t._expect(is_equal_approx(Engine.time_scale, focus.SCALE), "фокус: шкала времени не применила замедление")
	t.main.cam.hitstop(0.1)
	t.main.cam._process(0.001)
	t._expect(
		is_equal_approx(Engine.time_scale, focus.SCALE * t.main.cam.HITSTOP_SCALE),
		"фокус: хитстоп не сложился с замедлением"
	)
	t._expect(is_equal_approx(focus.active_timer.wait_time, focus.DURATION), "фокус: неверная длительность")
	t._expect(is_equal_approx(focus.cooldown_timer.wait_time, focus.COOLDOWN), "фокус: неверная перезарядка")

	var active_left: float = focus.remaining()
	button.pressed.emit()
	t._expect(focus.remaining() <= active_left, "фокус: повторное нажатие продлило эффект")
	t._expect(focus.cooldown_remaining() > 0.0, "фокус: перезарядка не началась")
	focus.active_timer.timeout.emit()
	t.main.cam.reset()
	t._expect(
		not focus.active and is_equal_approx(t.main.cam.focus_scale, 1.0) and is_equal_approx(Engine.time_scale, 1.0),
		"фокус: время не восстановилось"
	)
	button.pressed.emit()
	t._expect(not focus.active, "фокус: кнопка сработала во время перезарядки")

	focus.cooldown_timer.stop()
	var key := InputEventKey.new()
	key.keycode = KEY_F
	key.pressed = true
	t.main._input(key)
	t._expect(focus.active, "фокус: клавиша F не включила способность")
	t.main._on_menu_requested()
	await t.get_tree().process_frame
	t._expect(
		not focus.active and is_equal_approx(t.main.cam.focus_scale, 1.0), "фокус: замедление пережило выход в меню"
	)
	t._expect(not button.visible, "фокус: кнопка осталась видна в меню")
	focus.reset()


func _expect_touch_does_not_move_player(button: Button) -> void:
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = button.get_global_rect().get_center()
	touch.pressed = true
	t.main.player._input(touch)
	t._expect(not t.main.player.touching, "фокус: кнопка захватила виртуальный стик")
