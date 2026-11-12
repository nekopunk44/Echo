extends RefCounted
## REWIND при смерти: жетоны, такт смерти, экран выбора и сам откат на 5 секунд.
## Без жетона откат можно получить за рекламу (Ads), один раз за забег.
## Состояние забега (rewind_tokens, rewinds_used, State.LAST_CHANCE) лежит в main.gd, здесь только правила.
## Откат — одна функция apply(): она не списывает жетон, поэтому её же сможет вызвать награда за рекламу.

const PulseScript := preload("res://pulse_fx.gd")
const PickupScript := preload("res://pickup.gd")
const Art := preload("res://art.gd")

const REWIND_SECONDS := 5.0  # документ §5; при дубле 30 с это 1/6, при 90 с было бы 1/18, тогда пересмотреть
const REWIND_INVULN := 3.0  # документ: ~3 с. У брони 1.5 с. За 3 с герой (340 px/с) выбегает из толпы
const REWIND_PUSH_RADIUS := 320.0  # у брони 240: после отката герой может оказаться в гуще, а не рядом с одним врагом
const REWIND_PUSH_DIST := 260.0  # враг на 150 px/с возвращается за ~1.7 с, герой за это время уже в стороне
const REWIND_SPAWN_PAUSE := 1.0  # секунда без новых врагов: никто не появится на краю арены, пока идёт неуязвимость
const REWIND_TOKENS_START := 1  # жетонов на старте забега
const REWIND_TOKENS_MAX := 2  # максимум на руках; лимита за весь забег нет
const BOSS_PUSH_FACTOR := 0.4  # Цензор отлетает слабее, как в _shockwave
const DEATH_BEAT := 0.5  # такт смерти (игровое время): столько играют взрыв и срыв VHS, потом панель
const FLASH_SECONDS := 0.8  # время надписи «◀◀ REWIND» после отката
const VHS_FLASH_SECONDS := 0.3  # строки перемотки VHS: короче, иначе героя не разглядеть, а ему надо сразу бежать
# Документ §6: «лимит 1–2 перемотки за забег». Жетоны (стартовый и за Цензоров) идут сверх; реклама — страховка
# на случай, когда жетонов нет, а не способ перематывать без конца.
const AD_REWINDS_PER_RUN := 1

var main
var ui  # rewind_ui.gd
var beat := false  # идёт такт смерти: ввод игнорируется, потом откроется панель
var ad_used := 0  # откатов за рекламу в этом забеге
var ad_waiting := false  # идёт ролик: панель ждёт, ни REWIND, ни EJECT не нажать


## Новый забег: лимит рекламы обнуляется. Победа и «Продолжить» его не обнуляют — это тот же забег.
func new_run() -> void:
	ad_used = 0
	reset()


## Выход в меню, победа, новый забег: такт сброшен, панель закрыта.
func reset() -> void:
	beat = false
	ad_waiting = false
	ui.close()


## REWIND за рекламу: жетонов нет, лимит забега не выбран и ролик сейчас можно показать.
func can_rewind_for_ad() -> bool:
	return main.rewind_tokens <= 0 and ad_used < AD_REWINDS_PER_RUN and Ads.is_available(Ads.PLACEMENT_REWIND)


## Сколько тиков записи откат реально срежет: не больше пяти секунд и не больше самой записи.
func cut_ticks() -> int:
	return mini(Recorder.current.size(), roundi(REWIND_SECONDS * Engine.physics_ticks_per_second))


## Вызывается из player_died() после общего такта смерти. Жетон с земли засчитывается раньше проверки
## «есть ли жетон»: иначе можно погибнуть без жетона, убив босса за две секунды до смерти.
func on_death() -> void:
	collect_ground_tokens()
	beat = main.rewind_tokens > 0 or can_rewind_for_ad()
	if beat:
		main.hud.msg.text = ""  # надпись EJECT появится, только если игрок откажется от отката
	else:
		main.show_eject()


## Конец такта смерти: мир замирает целиком, открывается экран выбора.
func open_panel() -> void:
	beat = false
	main.state = main.State.LAST_CHANCE
	main.cam.reset()  # на паузе время идёт обычным ходом: хитстоп и тряска смерти не застывают
	main.player.reset_input()  # отпускание пальца придёт на паузе, и стик залип бы до следующего касания
	main.get_tree().paused = true
	var cut_seconds := float(cut_ticks()) / Engine.physics_ticks_per_second
	ui.open(main.take, main.kills, main.level, main.rewind_tokens, REWIND_TOKENS_MAX, cut_seconds, REWIND_INVULN)
	ui.set_ad_mode(main.rewind_tokens <= 0)


## Выбор REWIND на панели: жетон списывается здесь, в момент выбора, а не при открытии экрана.
## Жетона нет — запускается ролик, а откат будет, только если его досмотрели.
func request_rewind() -> void:
	if main.state != main.State.LAST_CHANCE or ui.is_locked() or ad_waiting:
		return
	if main.rewind_tokens > 0:
		main.rewind_tokens -= 1
		apply()
	elif can_rewind_for_ad():
		ad_waiting = true
		ui.set_ad_waiting(true)
		Ads.show_rewarded(Ads.PLACEMENT_REWIND, _on_ad_done)


## Ролик закрыт. Не досмотрен — панель остаётся, можно попробовать ещё раз или выбрать EJECT.
func _on_ad_done(rewarded: bool) -> void:
	ad_waiting = false
	ui.set_ad_waiting(false)
	if main.state != main.State.LAST_CHANCE:
		return
	if not rewarded:
		ui.show_ad_declined(can_rewind_for_ad())
		return
	ad_used += 1
	apply()


## Выбор EJECT: жетон остаётся, дальше обычный экран конца забега.
func request_eject() -> void:
	if main.state != main.State.LAST_CHANCE or ui.is_locked() or ad_waiting:
		return
	ui.close()
	main.get_tree().paused = false
	main.state = main.State.DEAD
	main.dead_time = 0.0
	main.show_eject()


## Сам откат, без списания жетона: его зовут и жетон, и досмотренная реклама.
func apply() -> void:
	if main.state != main.State.LAST_CHANCE:
		return
	var tree: SceneTree = main.get_tree()
	var cut := cut_ticks()
	main.rewinds_used += 1
	ui.close()
	tree.paused = false
	main.cam.reset()
	var new_n := Recorder.rewind(cut)
	var pos: Vector2 = main.ARENA / 2.0  # при new_n == 0 герой встаёт в центр, как в начале дубля
	if new_n > 0:
		pos = Recorder.current[new_n - 1]
	main.player.position = pos
	main.player.active = true
	main.player.visible = true
	main.player.reset_input()
	main.take_time = maxf(0.0, main.take_time - float(cut) / Engine.physics_ticks_per_second)
	if new_n == 0:
		main.take_time = 0.0  # герой снова в центре, как в начале дубля; накопленная погрешность часов не нужна
	for g in tree.get_nodes_in_group("ghosts"):
		g.seek(new_n)
	for b in tree.get_nodes_in_group("bullets"):  # выпущены в стёртые секунды: бумеранг через арену выглядит багом
		b.remove_from_group("bullets")
		b.queue_free()
	_push_enemies(pos)
	main.invuln = REWIND_INVULN
	main.spawn_timer = maxf(main.spawn_timer, REWIND_SPAWN_PAUSE)
	main.state = main.State.PLAY
	main.hud.msg.text = ""
	_effects(pos)


## Жетон в запас. Выше максимума не поднимается: лишний подбор просто пропадает.
func grant_token() -> void:
	if main.rewind_tokens >= REWIND_TOKENS_MAX:
		return
	main.rewind_tokens += 1
	main.vhs.pulse(0.3)
	main.hud.flash_token(main.rewind_tokens - 1)


## Цензор роняет жетон только пока жетоны на руках и на земле вместе не заполнили запас.
func drop_token(pos: Vector2) -> void:
	if main.rewind_tokens + _ground_tokens().size() >= REWIND_TOKENS_MAX:
		return
	var p := PickupScript.new()
	p.position = pos
	p.is_token = true
	p.main = main
	p.target = main.player
	main.add_child(p)


## Жетоны, лежащие на земле, засчитываются сразу (смерть героя).
func collect_ground_tokens() -> void:
	for p in _ground_tokens():
		p.collect()


func _ground_tokens() -> Array:
	var tokens: Array = []
	for p in main.get_tree().get_nodes_in_group("pickups"):
		if p.is_token and not p.collected:
			tokens.append(p)
	return tokens


## Враги назад не откатываются, их только отталкивает от нового места героя. Урона нет.
func _push_enemies(center: Vector2) -> void:
	for e in main.get_tree().get_nodes_in_group("enemies"):
		var d: Vector2 = e.position - center
		if d.length() >= REWIND_PUSH_RADIUS:
			continue
		# Враг ровно в точке героя: normalized() даёт нуль и его не сдвинет, поэтому направление случайное.
		var dir := Vector2.from_angle(randf() * TAU) if d.is_zero_approx() else d.normalized()
		e.position += dir * REWIND_PUSH_DIST * (BOSS_PUSH_FACTOR if e.kind == 6 else 1.0)


func _effects(pos: Vector2) -> void:
	main.vhs.flash_rewind(VHS_FLASH_SECONDS)
	main.vhs.pulse(0.6)
	main.cam.shake(0.4)  # хитстопа нет: игроку надо сразу двигаться
	var ring := PulseScript.new()
	ring.position = pos
	ring.radius = REWIND_PUSH_RADIUS
	ring.color = Art.CYAN
	ring.bars = false
	main.add_child(ring)
	main.spawn_burst(pos, Art.CYAN)
	main.hud.show_rewind_flash(FLASH_SECONDS)
