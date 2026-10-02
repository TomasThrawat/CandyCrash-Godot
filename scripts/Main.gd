extends Node2D

const SCREEN_SIZE := Vector2(720, 1280)
const GAME_BG := Color("#09061C")
const PANEL := Color("#171137")
const PANEL_2 := Color("#2A235C")
const TEXT := Color("#FFFFFF")
const MUTED := Color("#B8B2DE")
const ACCENT := Color("#FF6E9B")

var audio: AudioManager
var board: GameBoard
var root_ui: Control
var hud: Dictionary = {}
var overlay: Control
var current_level := 1
var max_unlocked := 1
var stars: Dictionary = {}
var settings := {"sound": true, "haptics": true}
var save_path := "user://candy_crash_save.json"

func _ready() -> void:
    audio = AudioManager.new()
    add_child(audio)
    _load_save()
    root_ui = Control.new()
    root_ui.process_mode = Node.PROCESS_MODE_ALWAYS
    root_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(root_ui)
    _show_map()
    queue_redraw()

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, SCREEN_SIZE), GAME_BG)
    draw_circle(Vector2(72, 188), 210, Color("#7D45FF", 0.11))
    draw_circle(Vector2(650, 360), 250, Color("#FF4D92", 0.08))
    draw_circle(Vector2(350, 1110), 300, Color("#1A4C8A", 0.07))
    for i in range(18):
        var p := Vector2(28 + (i * 83) % 660, 145 + (i * 137) % 1000)
        draw_circle(p, 2.0 + float(i % 3), Color("#FFFFFF", 0.12))

func _clear_ui() -> void:
    for child in root_ui.get_children():
        child.queue_free()
    hud.clear()
    overlay = null

func _show_map() -> void:
    if board and is_instance_valid(board):
        board.queue_free()
        board = null
    _clear_ui()

    var title := _label("CANDY CRASH", 42, TEXT)
    title.position = Vector2(0, 52)
    title.size = Vector2(720, 60)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    root_ui.add_child(title)

    var sub := _label("Sweet matches • bigger combos", 17, MUTED)
    sub.position = Vector2(0, 112)
    sub.size = Vector2(720, 30)
    sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    root_ui.add_child(sub)

    var journey := Panel.new()
    journey.position = Vector2(40, 160)
    journey.size = Vector2(640, 114)
    journey.add_theme_stylebox_override("panel", _box(PANEL, 24))
    root_ui.add_child(journey)

    var level_caption := _label("UNLOCKED", 11, MUTED)
    level_caption.position = Vector2(24, 16)
    level_caption.size = Vector2(120, 20)
    journey.add_child(level_caption)

    var level_value := _label(str(max_unlocked), 34, TEXT)
    level_value.position = Vector2(24, 40)
    level_value.size = Vector2(120, 46)
    journey.add_child(level_value)

    var progress_caption := _label("YOUR JOURNEY", 11, MUTED)
    progress_caption.position = Vector2(188, 16)
    progress_caption.size = Vector2(160, 20)
    journey.add_child(progress_caption)

    var progress_value := _label("%d / 36 LEVELS" % max_unlocked, 20, TEXT)
    progress_value.position = Vector2(188, 42)
    progress_value.size = Vector2(220, 34)
    journey.add_child(progress_value)

    var settings_btn := _button("SETTINGS", 130, 52, 14)
    settings_btn.position = Vector2(486, 31)
    settings_btn.pressed.connect(_show_settings)
    journey.add_child(settings_btn)

    var scroll := ScrollContainer.new()
    scroll.position = Vector2(40, 300)
    scroll.size = Vector2(640, 884)
    root_ui.add_child(scroll)

    var grid := GridContainer.new()
    grid.columns = 3
    grid.add_theme_constant_override("h_separation", 16)
    grid.add_theme_constant_override("v_separation", 16)
    grid.custom_minimum_size = Vector2(620, 0)
    scroll.add_child(grid)

    for i in range(1, 37):
        var button := _button("%02d" % i, 192, 122, 23)
        button.disabled = i > max_unlocked
        if i <= max_unlocked:
            var count := int(stars.get(str(i), 0))
            button.text = "%02d\n%s" % [i, "★".repeat(count) if count > 0 else "•"]
            button.pressed.connect(_start_level.bind(i))
            button.add_theme_stylebox_override("normal", _box(PANEL_2, 20))
            button.add_theme_stylebox_override("hover", _box(Color("#3D347D"), 20))
            button.add_theme_stylebox_override("pressed", _box(ACCENT.darkened(0.28), 20))
        else:
            button.text = "LOCKED\n%02d" % i
            button.modulate = Color(0.50, 0.50, 0.62)
        grid.add_child(button)

func _start_level(id: int) -> void:
    current_level = id
    _show_game()

func _show_game() -> void:
    if board and is_instance_valid(board):
        board.queue_free()
    _clear_ui()

    var level := LevelData.get_level(current_level)
    board = GameBoard.new()
    board.position = Vector2.ZERO
    add_child(board)
    board.setup(level, audio)
    board.level_won.connect(_on_level_won)
    board.level_lost.connect(_on_level_lost)
    board.stats_changed.connect(_on_stats_changed)

    var back := _button("‹", 42, 52, 28)
    back.position = Vector2(42, 46)
    back.pressed.connect(_back_to_map)
    root_ui.add_child(back)

    var title := _label(level.name, 28, TEXT)
    title.position = Vector2(104, 42)
    title.size = Vector2(360, 40)
    root_ui.add_child(title)

    var subtitle := _label("Make sweet matches", 14, MUTED)
    subtitle.position = Vector2(104, 74)
    subtitle.size = Vector2(300, 24)
    root_ui.add_child(subtitle)

    var pause := _button("Ⅱ", 82, 52, 22)
    pause.position = Vector2(584, 46)
    pause.pressed.connect(_toggle_pause)
    root_ui.add_child(pause)

    var score_panel := _mini_panel("SCORE", 44, 157, 196, 66)
    root_ui.add_child(score_panel)
    hud["score"] = score_panel.get_node("Value")

    var moves_panel := _mini_panel("MOVES", 262, 157, 196, 66)
    root_ui.add_child(moves_panel)
    hud["moves"] = moves_panel.get_node("Value")

    var goal_panel := _mini_panel("GOAL", 480, 157, 196, 66)
    root_ui.add_child(goal_panel)
    hud["goal"] = goal_panel.get_node("Value")

    var booster_panel := Panel.new()
    booster_panel.position = Vector2(40, 900)
    booster_panel.size = Vector2(640, 164)
    booster_panel.add_theme_stylebox_override("panel", _box(Color("#18133A"), 26))
    root_ui.add_child(booster_panel)

    var booster_title := _label("BOOSTERS", 12, MUTED)
    booster_title.position = Vector2(18, 14)
    booster_title.size = Vector2(140, 22)
    booster_panel.add_child(booster_title)

    var b1 := _button("HAMMER\n×3", 140, 92, 15)
    b1.position = Vector2(16, 49)
    b1.pressed.connect(_use_hammer)
    booster_panel.add_child(b1)

    var b2 := _button("SHUFFLE\n×2", 140, 92, 15)
    b2.position = Vector2(168, 49)
    b2.pressed.connect(_use_shuffle)
    booster_panel.add_child(b2)

    var b3 := _button("COLOR BOMB\n×1", 160, 92, 15)
    b3.position = Vector2(320, 49)
    b3.pressed.connect(_use_color_bomb)
    booster_panel.add_child(b3)

    var b4 := _button("EXTRA MOVE\n+5", 132, 92, 14)
    b4.position = Vector2(492, 49)
    b4.pressed.connect(_use_extra_move)
    booster_panel.add_child(b4)

    var footer := Panel.new()
    footer.position = Vector2(40, 1082)
    footer.size = Vector2(640, 76)
    footer.add_theme_stylebox_override("panel", _box(Color("#14102F"), 22))
    root_ui.add_child(footer)

    var hint := _label("Tap two neighboring candies to swap • Build chains for bigger scores", 14, MUTED)
    hint.position = Vector2(16, 20)
    hint.size = Vector2(608, 36)
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    footer.add_child(hint)

    _update_goal(level)
    _update_stats(board.get_stats())

func _mini_panel(caption: String, x: float, y: float, w: float, h: float) -> Panel:
    var p := Panel.new()
    p.position = Vector2(x, y)
    p.size = Vector2(w, h)
    p.add_theme_stylebox_override("panel", _box(Color("#2C245A"), 18))
    var c := _label(caption, 11, MUTED)
    c.position = Vector2(16, 8)
    c.size = Vector2(w - 32, 18)
    p.add_child(c)
    var v := _label("0", 20, TEXT)
    v.name = "Value"
    v.position = Vector2(16, 27)
    v.size = Vector2(w - 32, 32)
    p.add_child(v)
    return p

func _update_goal(level: Dictionary) -> void:
    var value := ""
    match int(level.objective):
        LevelData.ObjectiveType.SCORE:
            value = "%d+" % int(level.target)
        LevelData.ObjectiveType.BLOCKERS:
            value = "%d crates" % int(level.target)
        LevelData.ObjectiveType.COLLECT:
            value = "%d %s" % [int(level.target), Visuals.candy_name(int(level.id) % 6)]
        LevelData.ObjectiveType.JELLY:
            value = "%d jelly" % int(level.target)
    if hud.has("goal"):
        hud["goal"].text = value

func _update_stats(stats: Dictionary) -> void:
    if hud.has("score"):
        hud["score"].text = str(stats.score)
    if hud.has("moves"):
        hud["moves"].text = str(stats.moves)

func _on_stats_changed(stats: Dictionary) -> void:
    _update_stats(stats)

func _on_level_won(stats: Dictionary) -> void:
    await get_tree().create_timer(0.15).timeout
    var earned := 1
    if int(stats.moves) > 12:
        earned = 1
    elif int(stats.moves) > 6:
        earned = 2
    else:
        earned = 3
    stars[str(current_level)] = max(int(stars.get(str(current_level), 0)), earned)
    max_unlocked = max(max_unlocked, min(36, current_level + 1))
    _save()
    _show_result(true, stats, earned)

func _on_level_lost(stats: Dictionary) -> void:
    _show_result(false, stats, 0)

func _show_result(win: bool, stats: Dictionary, earned: int) -> void:
    overlay = ColorRect.new()
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.color = Color("#05030E", 0.78)
    root_ui.add_child(overlay)

    var card := Panel.new()
    card.position = Vector2(55, 382)
    card.size = Vector2(610, 510)
    card.add_theme_stylebox_override("panel", _box(Color("#29235E"), 30))
    overlay.add_child(card)

    var title := _label("LEVEL COMPLETE!" if win else "OUT OF MOVES", 32, TEXT)
    title.position = Vector2(20, 35)
    title.size = Vector2(570, 52)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    card.add_child(title)

    var rating := _label("★".repeat(earned) if win else "TRY AGAIN", 44, Color("#FFE06B") if win else ACCENT)
    rating.position = Vector2(20, 105)
    rating.size = Vector2(570, 64)
    rating.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    card.add_child(rating)

    var result := _label(
        "Score    %d\nCombo    %d\nMoves    %d" % [stats.score, stats.combo, stats.moves],
        21,
        TEXT
    )
    result.position = Vector2(30, 198)
    result.size = Vector2(550, 116)
    result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    card.add_child(result)

    var main_action := _button("NEXT LEVEL" if win else "RETRY", 250, 62, 19)
    main_action.position = Vector2(180, 346)
    main_action.pressed.connect(_next_level if win else _retry_level)
    card.add_child(main_action)

    var map_action := _button("LEVEL MAP", 250, 54, 16)
    map_action.position = Vector2(180, 425)
    map_action.pressed.connect(_back_to_map)
    card.add_child(map_action)

func _next_level() -> void:
    if current_level < 36:
        current_level += 1
        _show_game()
    else:
        _show_map()

func _retry_level() -> void:
    _show_game()

func _back_to_map() -> void:
    _show_map()

func _toggle_pause() -> void:
    if get_tree().paused:
        get_tree().paused = false
        if overlay and is_instance_valid(overlay):
            overlay.queue_free()
        overlay = null
        return

    get_tree().paused = true
    overlay = ColorRect.new()
    overlay.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.color = Color("#05030E", 0.74)
    root_ui.add_child(overlay)

    var card := Panel.new()
    card.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
    card.position = Vector2(70, 430)
    card.size = Vector2(580, 400)
    card.add_theme_stylebox_override("panel", _box(Color("#29235E"), 28))
    overlay.add_child(card)

    var t := _label("PAUSED", 34, TEXT)
    t.position = Vector2(20, 35)
    t.size = Vector2(540, 55)
    t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    card.add_child(t)

    var resume := _button("RESUME", 240, 60, 19)
    resume.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
    resume.position = Vector2(170, 125)
    resume.pressed.connect(_toggle_pause)
    card.add_child(resume)

    var settings := _button("SETTINGS", 240, 56, 17)
    settings.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
    settings.position = Vector2(170, 205)
    settings.pressed.connect(_show_settings)
    card.add_child(settings)

    var exit := _button("LEVEL MAP", 240, 56, 17)
    exit.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
    exit.position = Vector2(170, 278)
    exit.pressed.connect(func():
        get_tree().paused = false
        _back_to_map()
    )
    card.add_child(exit)

func _show_settings() -> void:
    get_tree().paused = false
    if overlay and is_instance_valid(overlay):
        overlay.queue_free()
        overlay = null

    var panel := Panel.new()
    panel.position = Vector2(60, 320)
    panel.size = Vector2(600, 590)
    panel.add_theme_stylebox_override("panel", _box(Color("#29235E"), 28))
    root_ui.add_child(panel)

    var title := _label("SETTINGS", 30, TEXT)
    title.position = Vector2(20, 30)
    title.size = Vector2(560, 55)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    panel.add_child(title)

    var sound := _button("SOUND: " + ("ON" if settings.sound else "OFF"), 360, 64, 18)
    sound.position = Vector2(120, 125)
    sound.pressed.connect(func():
        settings.sound = not settings.sound
        AudioServer.set_bus_mute(0, not settings.sound)
        sound.text = "SOUND: " + ("ON" if settings.sound else "OFF")
        _save()
    )
    panel.add_child(sound)

    var haptic := _button("HAPTICS HOOK: " + ("ON" if settings.haptics else "OFF"), 360, 64, 18)
    haptic.position = Vector2(120, 205)
    haptic.pressed.connect(func():
        settings.haptics = not settings.haptics
        haptic.text = "HAPTICS HOOK: " + ("ON" if settings.haptics else "OFF")
        _save()
    )
    panel.add_child(haptic)

    var reset := _button("RESET PROGRESS", 360, 64, 18)
    reset.position = Vector2(120, 285)
    reset.pressed.connect(_reset_progress)
    panel.add_child(reset)

    var close := _button("CLOSE", 220, 58, 17)
    close.position = Vector2(190, 395)
    close.pressed.connect(func(): panel.queue_free())
    panel.add_child(close)

func _reset_progress() -> void:
    max_unlocked = 1
    stars.clear()
    _save()
    _show_map()

func _use_hammer() -> void:
    if not board or board.moving:
        return
    var cell := Vector2i(3, 3)
    board.board[cell.y][cell.x].blocker = false
    board.board[cell.y][cell.x].kind = max(0, int(board.board[cell.y][cell.x].kind))
    board.score += 250
    board._refresh_visuals()
    board._emit_stats()
    audio.play("bonus")

func _use_shuffle() -> void:
    if not board or board.moving:
        return
    for y in range(GameBoard.SIZE):
        for x in range(GameBoard.SIZE):
            if not board.board[y][x].blocker:
                board.board[y][x].kind = board.rng.randi_range(0, 5)
                board.board[y][x].special = 0
    board._refresh_visuals()
    audio.play("slide")

func _use_color_bomb() -> void:
    if not board or board.moving:
        return
    var cell := Vector2i(3, 3)
    board.board[cell.y][cell.x].blocker = false
    board.board[cell.y][cell.x].kind = board.rng.randi_range(0, 5)
    board.board[cell.y][cell.x].special = 4
    board._refresh_visuals()
    audio.play("bonus", 1.08)

func _use_extra_move() -> void:
    if not board:
        return
    board.moves_left += 5
    board._emit_stats()
    audio.play("bonus")

func _save() -> void:
    var f := FileAccess.open(save_path, FileAccess.WRITE)
    if not f:
        return
    f.store_string(JSON.stringify({
        "max_unlocked": max_unlocked,
        "stars": stars,
        "settings": settings
    }))
    f.close()

func _load_save() -> void:
    if not FileAccess.file_exists(save_path):
        return
    var f := FileAccess.open(save_path, FileAccess.READ)
    var data = JSON.parse_string(f.get_as_text())
    f.close()
    if typeof(data) == TYPE_DICTIONARY:
        max_unlocked = int(data.get("max_unlocked", 1))
        stars = data.get("stars", {})
        settings = data.get("settings", settings)
        AudioServer.set_bus_mute(0, not bool(settings.sound))

func _label(text: String, size: int, color: Color) -> Label:
    var l := Label.new()
    l.text = text
    l.add_theme_font_size_override("font_size", size)
    l.add_theme_color_override("font_color", color)
    return l

func _button(text: String, w: float, h: float, size: int) -> Button:
    var b := Button.new()
    b.text = text
    b.custom_minimum_size = Vector2(w, h)
    b.add_theme_font_size_override("font_size", size)
    b.add_theme_color_override("font_color", TEXT)
    b.add_theme_color_override("font_hover_color", TEXT)
    b.add_theme_stylebox_override("normal", _box(PANEL, 18))
    b.add_theme_stylebox_override("hover", _box(Color("#3D347D"), 18))
    b.add_theme_stylebox_override("pressed", _box(ACCENT.darkened(0.28), 18))
    b.add_theme_stylebox_override("disabled", _box(Color("#141229"), 18))
    return b

func _box(color: Color, radius: int) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = color
    s.corner_radius_top_left = radius
    s.corner_radius_top_right = radius
    s.corner_radius_bottom_left = radius
    s.corner_radius_bottom_right = radius
    s.border_width_left = 1
    s.border_width_top = 1
    s.border_width_right = 1
    s.border_width_bottom = 1
    s.border_color = Color(1,1,1,0.08)
    return s
