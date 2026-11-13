extends RefCounted
## Проверки полки кассет для дымового прогона: вынесены из smoke.gd, чтобы он не перерос лимит строк.
## t — сам smoke.gd: через него доступны main и общие помощники (_expect, _frames).

const CassettesScript := preload("res://cassettes.gd")
const CASSETTES_PATH := "user://smoke_cassettes.cfg"

var t


func _init(host) -> void:
	t = host


## Данные полки без игры: названия совпадают с жанрами, закрытую кассету не выбрать, убийства делятся по кассетам,
## всё переживает перезагрузку, а запись не стирает другие ключи файла прогресса.
func data() -> void:
	t._expect(CassettesScript.COVERS.size() == t.main.GENRES.size(), "полка: обложек не столько, сколько жанров")
	for i in CassettesScript.COVERS.size():
		t._expect(
			CassettesScript.COVERS[i]["name"] == t.main.GENRES[i]["name"], "полка: название %d не совпало с жанром" % i
		)
		t._expect(ResourceLoader.exists(CassettesScript.COVERS[i]["sprite"]), "полка: нет спрайта обложки %d" % i)
	var absolute := ProjectSettings.globalize_path(CASSETTES_PATH)
	DirAccess.remove_absolute(absolute)
	var other := ConfigFile.new()
	other.set_value("progress", "endless_unlocked", true)
	other.save(CASSETTES_PATH)
	var c = CassettesScript.new(CASSETTES_PATH)
	t._expect(c.seen_count() == 0, "полка: новый игрок уже что-то видел")
	c.select(1)
	t._expect(c.selected == c.RANDOM, "полка: закрытую кассету можно выбрать")
	c.on_take_started(1)
	c.select(1)
	t._expect(c.selected == 1 and c.pick_genre() == 1, "полка: выбранная кассета не идёт в забег")
	c.new_run()
	c.sync_kills(1, 10)
	c.on_take_started(2)
	c.sync_kills(2, 25)
	c.sync_kills(2, 25)  # повторный вызов на той же цифре ничего не прибавляет
	c.add_take(2)
	c.add_censor(2)
	c.add_final(1)
	var d = CassettesScript.new(CASSETTES_PATH)
	t._expect(d.selected == 1 and d.seen_count() == 2, "полка: выбор или открытые кассеты не сохранились")
	t._expect(d.stats(1)["kills"] == 10 and d.stats(2)["kills"] == 15, "полка: убийства разнесены неверно")
	t._expect(d.stats(2)["takes"] == 1 and d.stats(2)["censors"] == 1, "полка: дубли или Цензоры не сохранились")
	t._expect(d.stats(1)["finals"] == 1, "полка: финал не сохранился")
	var back := ConfigFile.new()
	back.load(CASSETTES_PATH)
	t._expect(bool(back.get_value("progress", "endless_unlocked", false)), "полка стёрла другие ключи файла прогресса")
	DirAccess.remove_absolute(absolute)


## После дублей за всех героев: забег листает жанры по актам, значит кассет открылось больше одной и счётчики пошли.
func after_play() -> void:
	var takes := 0
	var kills := 0
	for i in t.main.cassettes.count():
		var row: Dictionary = t.main.cassettes.stats(i)
		takes += int(row["takes"])
		kills += int(row["kills"])
	t._expect(t.main.cassettes.seen_count() >= 2, "полка: за четыре дубля открылось меньше двух кассет")
	t._expect(takes >= t.HEROES.size() * t.TAKES_PER_HERO, "полка: дублей засчитано всего %d" % takes)
	t._expect(kills > 0, "полка: убийства не дошли до кассет")


## Проверка экрана «ПОЛКА ВИДЕОПРОКАТА»: открытие, число обложек, выбор кассеты, случайная, кнопка НАЗАД, закрытые.
func shelf() -> void:
	t.main._on_menu_requested()
	await t._frames(2)
	t._expect(t.main.state == t.main.State.MENU, "полка: не перешли в меню")

	t.main.run_menu.open_shelf()
	var shelf = t.main.run_menu.shelf
	t._expect(shelf != null and shelf.is_open(), "полка: open_shelf() не открыл полку")
	if shelf == null:
		return

	var total: int = t.main.cassettes.count()
	t._expect(shelf.cover_buttons.size() == total, "полка: обложек %d != %d" % [shelf.cover_buttons.size(), total])

	# Тап по открытой кассете: проверяем выбор и имя на кнопке меню после закрытия
	var seen_idx := -1
	for i in total:
		if t.main.cassettes.is_seen(i):
			seen_idx = i
			break
	t._expect(seen_idx >= 0, "полка: нет открытых кассет для проверки")
	if seen_idx >= 0:
		shelf.cover_buttons[seen_idx].pressed.emit()
		t._expect(t.main.cassettes.selected == seen_idx, "полка: тап по обложке %d не выбрал её" % seen_idx)
		var details_name: String = t.main.cassettes.COVERS[seen_idx]["name"]
		t._expect(shelf.details_title.text == details_name, "полка: панель не показывает выбранную кассету")
		t._expect("ДУБЛЕЙ" in shelf.details_stats.text, "полка: в панели нет статистики выбранной кассеты")
		shelf.close()
		var tape_name: String = t.main.cassettes.COVERS[seen_idx]["name"]
		var btn_text: String = t.main.run_menu.shelf_button.text
		t._expect(tape_name in btn_text, "полка: подпись «%s» не содержит «%s»" % [btn_text, tape_name])
		var tape_color: Color = t.main.cassettes.COVERS[seen_idx]["color"]
		t._expect(
			t.main.run_menu.shelf_button.get_theme_color("font_color") == tape_color,
			"полка: название кассеты в меню не использует цвет обложки"
		)
		t.main.run_menu.open_shelf()

	# Кнопка «СЛУЧАЙНАЯ КАССЕТА»
	shelf.random_button.pressed.emit()
	t._expect(t.main.cassettes.selected == t.main.cassettes.RANDOM, "полка: случайная кнопка не вернула RANDOM")

	# Кнопка «НАЗАД»
	shelf.back_button.pressed.emit()
	t._expect(not shelf.is_open(), "полка: back_button не закрыл экран")

	# У кассеты, которой нет на полке, кнопка disabled (если такие есть)
	if t.main.cassettes.seen_count() < total:
		var unseen_idx := -1
		for i in total:
			if not t.main.cassettes.is_seen(i):
				unseen_idx = i
				break
		if unseen_idx >= 0:
			t._expect(shelf.cover_buttons[unseen_idx].disabled, "полка: закрытая кассета %d не disabled" % unseen_idx)

	# В конце оставляем RANDOM
	t.main.cassettes.select(t.main.cassettes.RANDOM)
	t.main.run_menu._refresh_shelf_button()
	t._expect(t.main.cassettes.selected == t.main.cassettes.RANDOM, "полка: selected != RANDOM в конце")
