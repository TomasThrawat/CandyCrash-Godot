extends Node2D

const GAME_BG := Color("#0b0820")
const PANEL := Color("#18133c")
const PANEL_2 := Color("#24205a")
const TEXT := Color("#ffffff")
const MUTED := Color("#aea8d6")
const ACCENT := Color("#ff4d92")

var audio: AudioManager
var board: GameBoard
var root_ui: Control
var hud: Dictionary = {}
var overlay: Control
var current_level := 1
var max_unlocked := 1
var stars: Dictionary = {}
var save_path := "user://candy_crash_save.json"
var settings := {"sound": true, "haptics": true}
var screen := "map"

func _ready() -> void:
	audio = AudioManager.new()
	add_child(audio)
	_load_save()
	_build_root_ui()
	_show_map()
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(720,1280)), GAME_BG)
	draw_circle(Vector2(80,160), 190, Color("#2c1452",0.45))
	draw_circle(Vector2(650,250), 240, Color("#39135b",0.40))
	draw_circle(Vector2(360,1140), 280, Color("#101e4e",0.50))
	for i in range(12):
		var p := Vector2(35 + (i*59)%650, 95 + (i*173)%1070)
		draw_circle(p, 2.5 + (i%3), Color("#ffffff",0.16))
	
func _build_root_ui() -> void:
	root_ui = Control.new()
	root_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	root_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root_ui)

func _clear_ui() -> void:
	for child in root_ui.get_children():
		child.queue_free()
	hud.clear()
	overlay = null

func _show_map() -> void:
	screen = "map"
	_clear_ui()
	var title := _label("CANDY CRASH", 42, TEXT)
	title.position = Vector2(0, 58)
	title.size = Vector2(720,70)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_ui.add_child(title)
	var sub := _label("Sweet matches. Bigger combos. More levels.", 18, MUTED)
	sub.position = Vector2(0,125)
	sub.size = Vector2(720,36)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_ui.add_child(sub)

	var stat_panel := Panel.new()
	stat_panel.position = Vector2(40,180)
	stat_panel.size = Vector2(640,105)
	stat_panel.add_theme_stylebox_override("panel", _box(PANEL,22))
	root_ui.add_child(stat_panel)
	var stat1 := _label("LEVEL",15,MUTED)
	stat1.position = Vector2(36,18); stat1.size=Vector2(120,25)
	stat_panel.add_child(stat1)
	var stat2 := _label(str(max_unlocked),31,TEXT)
	stat2.position = Vector2(34,42); stat2.size=Vector2(120,44)
	stat_panel.add_child(stat2)
	var stat3 := _label("YOUR JOURNEY",15,MUTED)
	stat3.position = Vector2(205,18); stat3.size=Vector2(210,25)
	stat_panel.add_child(stat3)
	var prog := _label("%d / 36 levels" % max_unlocked,23,TEXT)
	prog.position = Vector2(205,43); prog.size=Vector2(220,40)
	stat_panel.add_child(prog)
	var settings_btn := _button("SETTINGS", 128, 52, 16)
	settings_btn.position = Vector2(480,26)
	settings_btn.pressed.connect(_show_settings)
	stat_panel.add_child(settings_btn)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(38,315)
	scroll.size = Vector2(644,875)
	root_ui.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.custom_minimum_size.x = 620
	scroll.add_child(grid)

	for i in range(1,37):
		var b := _button("%02d" % i, 192, 122, 24)
		var unlocked := i <= max_unlocked
		b.disabled = not unlocked
		if unlocked:
			var s := int(stars.get(str(i), 0))
			b.text = "%02d\n%s" % [i, "★".repeat(s) if s > 0 else "•"]
			b.pressed.connect(_start_level.bind(i))
			b.add_theme_stylebox_override("normal", _box(PANEL_2,20))
			b.add_theme_stylebox_override("hover", _box(Color("#342d78"),20))
			b.add_theme_stylebox_override("pressed", _box(ACCENT.darkened(0.25),20))
		else:
			b.text = "LOCKED\n%02d" % i
			b.modulate = Color(0.55,0.55,0.68)
		grid.add_child(b)

func _start_level(id: int) -> void:
	current_level = id
	_show_game()

func _show_game() -> void:
	screen = "game"
	if board and is_instance_valid(board):
		board.queue_free()
		board = null
	_clear_ui()
	var level := LevelData.get_level(current_level)
	board = GameBoard.new()
	add_child(board)
	board.setup(level, audio)
	board.level_won.connect(_on_level_won)
	board.level_lost.connect(_on_level_lost)
	board.stats_changed.connect(_on_stats_changed)

	var back := _button("‹", 60,60,34)
	back.position = Vector2(24,36)
	back.pressed.connect(_back_to_map)
	root_ui.add_child(back)

	var title := _label(level.name,24,TEXT)
	title.position=Vector2(96,42); title.size=Vector2(260,46)
	root_ui.add_child(title)

	var pause := _button("Ⅱ",60,60,24)
	pause.position=Vector2(636,36)
	pause.pressed.connect(_toggle_pause)
	root_ui.add_child(pause)

	var score_panel := _mini_panel("SCORE", 32, 112, 188, 82)
	root_ui.add_child(score_panel)
	hud["score"] = score_panel.get_node("Value")

	var moves_panel := _mini_panel("MOVES", 264, 112, 188, 82)
	root_ui.add_child(moves_panel)
	hud["moves"] = moves_panel.get_node("Value")

	var goal_panel := _mini_panel("GOAL", 496, 112, 188, 82)
	root_ui.add_child(goal_panel)
	hud["goal"] = goal_panel.get_node("Value")

	var booster_panel := Panel.new()
	booster_panel.position=Vector2(42,990)
	booster_panel.size=Vector2(636,190)
	booster_panel.add_theme_stylebox_override("panel",_box(PANEL,24))
	root_ui.add_child(booster_panel)
	var booster_title := _label("BOOSTERS",14,MUTED)
	booster_title.position=Vector2(24,16); booster_title.size=Vector2(130,28)
	booster_panel.add_child(booster_title)

	var b1 := _button("HAMMER\n×3", 126, 98, 17)
	b1.position=Vector2(20,55); b1.pressed.connect(_use_hammer)
	booster_panel.add_child(b1)
	var b2 := _button("SHUFFLE\n×2", 126, 98, 17)
	b2.position=Vector2(162,55); b2.pressed.connect(_use_shuffle)
	booster_panel.add_child(b2)
	var b3 := _button("COLOR BOMB\n×1", 150, 98, 17)
	b3.position=Vector2(304,55); b3.pressed.connect(_use_color_bomb)
	booster_panel.add_child(b3)
	var b4 := _button("EXTRA MOVE\n+5", 126, 98, 17)
	b4.position=Vector2(466,55); b4.pressed.connect(_use_extra_move)
	booster_panel.add_child(b4)

	_update_goal(level)
	_update_stats(board.get_stats())

func _mini_panel(caption: String, x: float, y: float, w: float, h: float) -> Panel:
	var p := Panel.new()
	p.position=Vector2(x,y); p.size=Vector2(w,h)
	p.add_theme_stylebox_override("panel",_box(PANEL,18))
	var c := _label(caption,12,MUTED)
	c.position=Vector2(16,10); c.size=Vector2(w-32,20)
	p.add_child(c)
	var v := _label("0",22,TEXT)
	v.name="Value"; v.position=Vector2(16,31); v.size=Vector2(w-32,38)
	p.add_child(v)
	return p

func _update_goal(level: Dictionary) -> void:
	var text := ""
	match int(level.objective):
		LevelData.ObjectiveType.SCORE:
			text = "%d+" % int(level.target)
		LevelData.ObjectiveType.BLOCKERS:
			text = "%d crates" % int(level.target)
		LevelData.ObjectiveType.COLLECT:
			text = "%d %s" % [int(level.target), Visuals.candy_name(int(level.id)%6)]
		LevelData.ObjectiveType.JELLY:
			text = "%d jelly" % int(level.target)
	hud["goal"].text = text

func _update_stats(stats: Dictionary) -> void:
	if hud.has("score"): hud["score"].text = str(stats.score)
	if hud.has("moves"): hud["moves"].text = str(stats.moves)

func _on_stats_changed(stats: Dictionary) -> void:
	_update_stats(stats)

func _on_level_won(stats: Dictionary) -> void:
	await get_tree().create_timer(0.15).timeout
	var earned := 3
	if int(stats.moves) <= 6: earned = 3
	elif int(stats.moves) <= 12: earned = 2
	else: earned = 1
	stars[str(current_level)] = max(int(stars.get(str(current_level),0)), earned)
	max_unlocked = max(max_unlocked, min(36,current_level+1))
	_save()
	_show_result(true, stats, earned)

func _on_level_lost(stats: Dictionary) -> void:
	_show_result(false, stats, 0)

func _show_result(win: bool, stats: Dictionary, earned: int) -> void:
	overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color("#070513",0.78)
	root_ui.add_child(overlay)
	var card := Panel.new()
	card.position=Vector2(55,390); card.size=Vector2(610,500)
	card.add_theme_stylebox_override("panel",_box(PANEL_2,30))
	overlay.add_child(card)
	var title := _label("LEVEL COMPLETE!" if win else "OUT OF MOVES",32,TEXT)
	title.position=Vector2(20,34); title.size=Vector2(570,55)
	title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(title)
	var stars_label := _label(("★".repeat(earned)) if win else "TRY AGAIN",44,Color("#ffd34d") if win else Color("#ff7a98"))
	stars_label.position=Vector2(20,110); stars_label.size=Vector2(570,65)
	stars_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(stars_label)
	var result := _label("Score   %d\nCombo   %d\nMoves   %d" % [stats.score,stats.combo,stats.moves],22,TEXT)
	result.position=Vector2(30,205); result.size=Vector2(550,120)
	result.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(result)
	if win:
		var next := _button("NEXT LEVEL", 250, 64, 20)
		next.position=Vector2(180,350); next.pressed.connect(_next_level)
		card.add_child(next)
		var map := _button("LEVEL MAP", 250, 54, 16)
		map.position=Vector2(180,425); map.pressed.connect(_back_to_map)
		card.add_child(map)
	else:
		var retry := _button("RETRY", 250, 64, 20)
		retry.position=Vector2(180,350); retry.pressed.connect(_retry_level)
		card.add_child(retry)
		var map2 := _button("LEVEL MAP", 250, 54, 16)
		map2.position=Vector2(180,425); map2.pressed.connect(_back_to_map)
		card.add_child(map2)

func _next_level() -> void:
	if current_level < 36:
		current_level += 1
		_show_game()
	else:
		_show_map()

func _retry_level() -> void:
	_show_game()

func _back_to_map() -> void:
	if board and is_instance_valid(board):
		board.queue_free()
		board=null
	_show_map()

func _toggle_pause() -> void:
	if get_tree().paused:
		get_tree().paused=false
		if overlay and is_instance_valid(overlay):
			overlay.queue_free()
			overlay=null
		return
	get_tree().paused=true
	overlay=ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color=Color("#070513",0.72)
	root_ui.add_child(overlay)
	var card:=Panel.new()
	card.position=Vector2(70,430); card.size=Vector2(580,400)
	card.add_theme_stylebox_override("panel",_box(PANEL_2,28))
	overlay.add_child(card)
	var t:=_label("PAUSED",34,TEXT)
	t.position=Vector2(20,35);t.size=Vector2(540,55);t.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(t)
	var resume:=_button("RESUME",240,60,19)
	resume.position=Vector2(170,125);resume.pressed.connect(_toggle_pause)
	card.add_child(resume)
	var settings:=_button("SETTINGS",240,56,17)
	settings.position=Vector2(170,205);settings.pressed.connect(_show_settings)
	card.add_child(settings)
	var exit:=_button("LEVEL MAP",240,56,17)
	exit.position=Vector2(170,278);exit.pressed.connect(_leave_paused)
	card.add_child(exit)

func _leave_paused() -> void:
	get_tree().paused=false
	_back_to_map()

func _show_settings() -> void:
	get_tree().paused=false
	if overlay and is_instance_valid(overlay):
		overlay.queue_free()
		overlay=null
	var panel:=Panel.new()
	panel.position=Vector2(60,320);panel.size=Vector2(600,590)
	panel.add_theme_stylebox_override("panel",_box(PANEL_2,28))
	root_ui.add_child(panel)
	var title:=_label("SETTINGS",30,TEXT)
	title.position=Vector2(20,30);title.size=Vector2(560,55);title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)
	var sound:=_button("SOUND: " + ("ON" if settings.sound else "OFF"), 360,64,18)
	sound.position=Vector2(120,125);sound.pressed.connect(func():
		settings.sound=not settings.sound
		AudioServer.set_bus_mute(0,not settings.sound)
		sound.text="SOUND: " + ("ON" if settings.sound else "OFF")
		_save()
	)
	panel.add_child(sound)
	var haptic:=_button("HAPTICS HOOK: " + ("ON" if settings.haptics else "OFF"), 360,64,18)
	haptic.position=Vector2(120,205);haptic.pressed.connect(func():
		settings.haptics=not settings.haptics
		haptic.text="HAPTICS HOOK: " + ("ON" if settings.haptics else "OFF")
		_save()
	)
	panel.add_child(haptic)
	var reset:=_button("RESET PROGRESS",360,64,18)
	reset.position=Vector2(120,285);reset.pressed.connect(_reset_progress)
	panel.add_child(reset)
	var close:=_button("CLOSE",220,58,17)
	close.position=Vector2(190,395);close.pressed.connect(func(): panel.queue_free())
	panel.add_child(close)

func _reset_progress() -> void:
	max_unlocked=1;stars.clear();_save();_show_map()

func _use_hammer() -> void:
	if not board or board.moving: return
	var center:=Vector2i(3,3)
	board.board[center.y][center.x].blocker=false
	board.score += 250
	board._refresh_visuals()
	board._emit_stats()
	audio.play("bonus")

func _use_shuffle() -> void:
	if not board or board.moving: return
	for y in range(GameBoard.SIZE):
		for x in range(GameBoard.SIZE):
			if not board.board[y][x].blocker:
				board.board[y][x].kind=board.rng.randi_range(0,5)
	board._refresh_visuals()
	board.audio.play("slide")

func _use_color_bomb() -> void:
	if not board or board.moving: return
	var c:=Vector2i(3,3)
	board.board[c.y][c.x].special=4
	board._refresh_visuals()
	board.audio.play("bonus",1.08)

func _use_extra_move() -> void:
	if not board: return
	board.moves_left += 5
	board._emit_stats()
	board.audio.play("bonus")

func _save() -> void:
	var f:=FileAccess.open(save_path,FileAccess.WRITE)
	if not f:return
	f.store_string(JSON.stringify({"max_unlocked":max_unlocked,"stars":stars,"settings":settings}))
	f.close()

func _load_save() -> void:
	if not FileAccess.file_exists(save_path): return
	var f:=FileAccess.open(save_path,FileAccess.READ)
	var data=JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(data)==TYPE_DICTIONARY:
		max_unlocked=int(data.get("max_unlocked",1))
		stars=data.get("stars",{})
		settings=data.get("settings",settings)
		AudioServer.set_bus_mute(0,not bool(settings.sound))

func _label(text:String,size:int,color:Color)->Label:
	var l:=Label.new()
	l.text=text;l.add_theme_font_size_override("font_size",size);l.add_theme_color_override("font_color",color)
	return l

func _button(text:String,w:float,h:float,size:int)->Button:
	var b:=Button.new()
	b.text=text;b.custom_minimum_size=Vector2(w,h)
	b.add_theme_font_size_override("font_size",size)
	b.add_theme_color_override("font_color",TEXT)
	b.add_theme_color_override("font_hover_color",TEXT)
	b.add_theme_stylebox_override("normal",_box(PANEL,18))
	b.add_theme_stylebox_override("hover",_box(Color("#342d78"),18))
	b.add_theme_stylebox_override("pressed",_box(ACCENT.darkened(0.28),18))
	b.add_theme_stylebox_override("disabled",_box(Color("#141229"),18))
	return b

func _box(color:Color,radius:int)->StyleBoxFlat:
	var s:=StyleBoxFlat.new()
	s.bg_color=color
	s.corner_radius_top_left=radius
	s.corner_radius_top_right=radius
	s.corner_radius_bottom_left=radius
	s.corner_radius_bottom_right=radius
	s.border_width_left=1;s.border_width_top=1;s.border_width_right=1;s.border_width_bottom=1
	s.border_color=Color(1,1,1,0.08)
	return s
