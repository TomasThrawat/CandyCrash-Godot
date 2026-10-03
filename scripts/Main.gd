extends Node2D

class SwipeLevelFeed extends ScrollContainer:
    signal level_selected(id: int)
    signal page_changed(id: int)

    var content: VBoxContainer
    var page_height := 720.0
    var page_ids: Array[int] = []
    var unlocked_through := 1
    var start_index := 0
    var touch_start := Vector2.ZERO
    var tracking_touch := false
    var snap_tween: Tween

    func _ready() -> void:
        gui_input.connect(_on_gui_input)

    func setup(ids: Array[int], max_unlocked: int, initial_index: int) -> void:
        page_ids = ids.duplicate()
        unlocked_through = max_unlocked
        start_index = clamp(initial_index, 0, max(0, page_ids.size() - 1))
        content = VBoxContainer.new()
        content.add_theme_constant_override("separation", 0)
        add_child(content)
        resized.connect(_reflow)
        _build_pages()

    func _build_pages() -> void:
        for id in page_ids:
            var page := Control.new()
            page.custom_minimum_size = Vector2(0, page_height)
            content.add_child(page)

            var center := CenterContainer.new()
            center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
            page.add_child(center)

            var card := PanelContainer.new()
            card.custom_minimum_size = Vector2(560, 500)
            card.add_theme_stylebox_override("panel", _box(Color("#242053"), 30))
            center.add_child(card)

            var stack := VBoxContainer.new()
            stack.alignment = BoxContainer.ALIGNMENT_CENTER
            stack.add_theme_constant_override("separation", 14)
            stack.custom_minimum_size = Vector2(500, 450)
            card.add_child(stack)

            var eyebrow := _label("LEVEL %02d" % id, 15, MUTED)
            eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
            stack.add_child(eyebrow)

            var unlocked := id <= unlocked_through
            var title := _label("CANDY CRASH" if unlocked else "LOCKED LEVEL", 34, TEXT)
            title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
            stack.add_child(title)

            var desc := _label(
                "Ready to play" if unlocked else "Finish the previous level to unlock this one",
                16,
                MUTED
            )
            desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
            desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
            desc.custom_minimum_size = Vector2(460, 52)
            stack.add_child(desc)

            var progress := _label("%d / 36 LEVELS" % id, 20, TEXT)
            progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
            stack.add_child(progress)

            var action := _button("PLAY LEVEL %02d" % id, 330, 68, 18)
            action.disabled = not unlocked
            action.pressed.connect(level_selected.emit.bind(id))
            stack.add_child(_center(action))

            var hint := _label("↑ swipe up    •    ↓ swipe down", 14, Color("#8F88B9"))
            hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
            stack.add_child(hint)

        call_deferred("_reflow")
        call_deferred("_snap_to", start_index)

    func _reflow() -> void:
        page_height = max(size.y, 560.0)
        if not content:
            return
        for page in content.get_children():
            page.custom_minimum_size.y = page_height

    func _on_gui_input(event: InputEvent) -> void:
        if event is InputEventScreenTouch:
            if event.pressed:
                tracking_touch = true
                touch_start = event.position
            elif tracking_touch:
                tracking_touch = false
                call_deferred("_snap_from_gesture", event.position)
        elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
            if event.pressed:
                tracking_touch = true
                touch_start = event.position
            elif tracking_touch:
                tracking_touch = false
                call_deferred("_snap_from_gesture", event.position)

    func _snap_from_gesture(end_pos: Vector2) -> void:
        if page_ids.is_empty():
            return
        var dy := end_pos.y - touch_start.y
        var index := int(round(scroll_vertical / max(page_height, 1.0)))
        if abs(dy) >= 55.0:
            index += 1 if dy < 0 else -1
        index = clamp(index, 0, page_ids.size() - 1)
        _snap_to(index)

    func _snap_to(index: int) -> void:
        if page_ids.is_empty():
            return
        var target := float(index) * page_height
        if snap_tween:
            snap_tween.kill()
        snap_tween = create_tween()
        snap_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        snap_tween.tween_property(self, "scroll_vertical", target, 0.22)
        page_changed.emit(page_ids[index])

    static func _box(color: Color, radius: int) -> StyleBoxFlat:
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

func _make_shell() -> VBoxContainer:
    ui_center = CenterContainer.new()
    ui_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root_ui.add_child(ui_center)

    ui_stack = VBoxContainer.new()
    ui_stack.alignment = BoxContainer.ALIGNMENT_CENTER
    ui_stack.add_theme_constant_override("separation", 14)
    ui_stack.custom_minimum_size = Vector2(664, 0)
    ui_center.add_child(ui_stack)
    return ui_stack

func _center(child: Control, min_size := Vector2.ZERO) -> CenterContainer:
    var wrap := CenterContainer.new()
    if min_size != Vector2.ZERO:
        wrap.custom_minimum_size = min_size
    wrap.add_child(child)
    return wrap

func _show_map() -> void:
    if board and is_instance_valid(board):
        board.queue_free()
        board = null
    _clear_ui()

    var stack := _make_shell()

    var title := _label("CANDY CRASH", 42, TEXT)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    stack.add_child(_center(title, Vector2(664, 56)))

    var sub := _label("Sweet matches • bigger combos", 17, MUTED)
    sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    stack.add_child(_center(sub, Vector2(664, 28)))

    var journey := PanelContainer.new()
    journey.custom_minimum_size = Vector2(640, 108)
    journey.add_theme_stylebox_override("panel", _box(PANEL, 24))
    var journey_row := HBoxContainer.new()
    journey_row.alignment = BoxContainer.ALIGNMENT_CENTER
    journey_row.add_theme_constant_override("separation", 14)
    journey.add_child(journey_row)

    var unlocked_box := VBoxContainer.new()
    unlocked_box.alignment = BoxContainer.ALIGNMENT_CENTER
    unlocked_box.custom_minimum_size = Vector2(120, 76)
    journey_row.add_child(unlocked_box)
    unlocked_box.add_child(_label("UNLOCKED", 11, MUTED))
    var level_value := _label(str(max_unlocked), 34, TEXT)
    level_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    unlocked_box.add_child(level_value)

    var progress_box := VBoxContainer.new()
    progress_box.alignment = BoxContainer.ALIGNMENT_CENTER
    progress_box.custom_minimum_size = Vector2(220, 76)
    journey_row.add_child(progress_box)
    progress_box.add_child(_label("YOUR JOURNEY", 11, MUTED))
    progress_box.add_child(_label("%d / 36 LEVELS" % max_unlocked, 20, TEXT))

    var settings_btn := _button("SETTINGS", 130, 52, 14)
    settings_btn.pressed.connect(_show_settings)
    journey_row.add_child(settings_btn)
    stack.add_child(_center(journey))

    var feed := SwipeLevelFeed.new()
    feed.custom_minimum_size = Vector2(640, 720)
    var ids: Array[int] = []
    for i in range(1, 37):
        ids.append(i)
    feed.setup(ids, max_unlocked, max_unlocked - 1)
    feed.level_selected.connect(_start_level)
    stack.add_child(_center(feed, Vector2(640, 720)))

    var footer := PanelContainer.new()
    footer.custom_minimum_size = Vector2(640, 58)
    footer.add_theme_stylebox_override("panel", _box(Color("#14102F"), 20))
    var footer_text := _label("Swipe up/down to move between levels", 14, MUTED)
    footer_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    footer.add_child(footer_text)
    stack.add_child(_center(footer))

func _start_level(id: int) -> void:
    current_level = id
    _show_game()

func _show_game() -> void:
    if board and is_instance_valid(board):
        board.queue_free()
    _clear_ui()

    var stack := _make_shell()
    stack.add_theme_constant_override("separation", 14)

    var header := HBoxContainer.new()
    header.alignment = BoxContainer.ALIGNMENT_CENTER
    header.add_theme_constant_override("separation", 10)
    header.custom_minimum_size = Vector2(640, 70)

    var back := _button("‹", 52, 56, 28)
    back.pressed.connect(_back_to_map)
    header.add_child(back)

    var title_wrap := VBoxContainer.new()
    title_wrap.alignment = BoxContainer.ALIGNMENT_CENTER
    title_wrap.custom_minimum_size = Vector2(500, 64)
    header.add_child(title_wrap)

    var level := LevelData.get_level(current_level)
    var title := _label(level.name, 28, TEXT)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title_wrap.add_child(title)
    var subtitle := _label("Make sweet matches", 14, MUTED)
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title_wrap.add_child(subtitle)

    var pause := _button("Ⅱ", 82, 56, 22)
    pause.pressed.connect(_toggle_pause)
    header.add_child(pause)
    stack.add_child(_center(header, Vector2(640, 70)))

    var hud_row := HBoxContainer.new()
    hud_row.alignment = BoxContainer.ALIGNMENT_CENTER
    hud_row.add_theme_constant_override("separation", 12)
    var score_panel := _mini_panel("SCORE")
    var moves_panel := _mini_panel("MOVES")
    var goal_panel := _mini_panel("GOAL")
    hud_row.add_child(score_panel)
    hud_row.add_child(moves_panel)
    hud_row.add_child(goal_panel)
    stack.add_child(_center(hud_row, Vector2(640, 70)))
    hud["score"] = score_panel.get_node("Value")
    hud["moves"] = moves_panel.get_node("Value")
    hud["goal"] = goal_panel.get_node("Value")

    board_host = Control.new()
    board_host.custom_minimum_size = Vector2(624, 624)
    board_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
    stack.add_child(_center(board_host, Vector2(624, 624)))

    board = GameBoard.new()
    board.position = Vector2.ZERO
    board_host.add_child(board)
    board.setup(level, audio)
    board.level_won.connect(_on_level_won)
    board.level_lost.connect(_on_level_lost)
    board.stats_changed.connect(_on_stats_changed)

    var booster_panel := PanelContainer.new()
    booster_panel.custom_minimum_size = Vector2(640, 148)
    booster_panel.add_theme_stylebox_override("panel", _box(Color("#18133A"), 24))
    var booster_stack := VBoxContainer.new()
    booster_stack.alignment = BoxContainer.ALIGNMENT_CENTER
    booster_stack.add_theme_constant_override("separation", 8)
    booster_panel.add_child(booster_stack)
    var booster_title := _label("BOOSTERS", 12, MUTED)
    booster_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    booster_stack.add_child(booster_title)

    var boosters := HBoxContainer.new()
    boosters.alignment = BoxContainer.ALIGNMENT_CENTER
    boosters.add_theme_constant_override("separation", 8)
    booster_stack.add_child(boosters)
    var b1 := _button("HAMMER\n×3", 140, 86, 15)
    b1.pressed.connect(_use_hammer)
    boosters.add_child(b1)
    var b2 := _button("SHUFFLE\n×2", 140, 86, 15)
    b2.pressed.connect(_use_shuffle)
    boosters.add_child(b2)
    var b3 := _button("COLOR BOMB\n×1", 160, 86, 15)
    b3.pressed.connect(_use_color_bomb)
    boosters.add_child(b3)
    var b4 := _button("EXTRA MOVE\n+5", 132, 86, 14)
    b4.pressed.connect(_use_extra_move)
    boosters.add_child(b4)
    stack.add_child(_center(booster_panel))

    var footer := PanelContainer.new()
    footer.custom_minimum_size = Vector2(640, 64)
    footer.add_theme_stylebox_override("panel", _box(Color("#14102F"), 20))
    var hint := _label("Tap neighboring candies to swap • Build chains for bigger scores", 14, MUTED)
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    footer.add_child(hint)
    stack.add_child(_center(footer))

    _update_goal(level)
    _update_stats(board.get_stats())

func _mini_panel(caption: String) -> PanelContainer:
    var p := PanelContainer.new()
    p.custom_minimum_size = Vector2(196, 70)
    p.add_theme_stylebox_override("panel", _box(Color("#2C245A"), 18))
    var stack := VBoxContainer.new()
    stack.alignment = BoxContainer.ALIGNMENT_CENTER
    p.add_child(stack)
    var c := _label(caption, 11, MUTED)
    c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    stack.add_child(c)
    var v := _label("0", 20, TEXT)
    v.name = "Value"
    v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    stack.add_child(v)
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

    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.add_child(center)

    var card := PanelContainer.new()
    card.custom_minimum_size = Vector2(610, 510)
    card.add_theme_stylebox_override("panel", _box(Color("#29235E"), 30))
    center.add_child(card)

    var stack := VBoxContainer.new()
    stack.alignment = BoxContainer.ALIGNMENT_CENTER
    stack.add_theme_constant_override("separation", 16)
    stack.custom_minimum_size = Vector2(560, 450)
    card.add_child(stack)

    var title := _label("LEVEL COMPLETE!" if win else "OUT OF MOVES", 32, TEXT)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    stack.add_child(title)

    var rating := _label("★".repeat(earned) if win else "TRY AGAIN", 44, Color("#FFE06B") if win else ACCENT)
    rating.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    stack.add_child(rating)

    var result := _label("Score    %d\nCombo    %d\nMoves    %d" % [stats.score, stats.combo, stats.moves], 21, TEXT)
    result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    stack.add_child(result)

    var main_action := _button("NEXT LEVEL" if win else "RETRY", 250, 62, 19)
    main_action.pressed.connect(_next_level if win else _retry_level)
    stack.add_child(_center(main_action))

    var map_action := _button("LEVEL MAP", 250, 54, 16)
    map_action.pressed.connect(_back_to_map)
    stack.add_child(_center(map_action))

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

    var center := CenterContainer.new()
    center.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.add_child(center)

    var card := PanelContainer.new()
    card.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
    card.custom_minimum_size = Vector2(580, 400)
    card.add_theme_stylebox_override("panel", _box(Color("#29235E"), 28))
    center.add_child(card)

    var stack := VBoxContainer.new()
    stack.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
    stack.alignment = BoxContainer.ALIGNMENT_CENTER
    stack.add_theme_constant_override("separation", 18)
    stack.custom_minimum_size = Vector2(520, 330)
    card.add_child(stack)

    var t := _label("PAUSED", 34, TEXT)
    t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    stack.add_child(t)

    var resume := _button("RESUME", 240, 60, 19)
    resume.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
    resume.pressed.connect(_toggle_pause)
    stack.add_child(_center(resume))

    var settings := _button("SETTINGS", 240, 56, 17)
    settings.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
    settings.pressed.connect(_show_settings)
    stack.add_child(_center(settings))

    var exit := _button("LEVEL MAP", 240, 56, 17)
    exit.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
    exit.pressed.connect(func():
        get_tree().paused = false
        _back_to_map()
    )
    stack.add_child(_center(exit))

func _show_settings() -> void:
    get_tree().paused = false
    if overlay and is_instance_valid(overlay):
        overlay.queue_free()
        overlay = null

    var overlay_root := ColorRect.new()
    overlay_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay_root.color = Color("#05030E", 0.70)
    root_ui.add_child(overlay_root)

    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay_root.add_child(center)

    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(600, 590)
    panel.add_theme_stylebox_override("panel", _box(Color("#29235E"), 28))
    center.add_child(panel)

    var stack := VBoxContainer.new()
    stack.alignment = BoxContainer.ALIGNMENT_CENTER
    stack.add_theme_constant_override("separation", 18)
    stack.custom_minimum_size = Vector2(540, 520)
    panel.add_child(stack)

    var title := _label("SETTINGS", 30, TEXT)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    stack.add_child(title)

    var sound := _button("SOUND: " + ("ON" if settings.sound else "OFF"), 360, 64, 18)
    sound.pressed.connect(func():
        settings.sound = not settings.sound
        AudioServer.set_bus_mute(0, not settings.sound)
        sound.text = "SOUND: " + ("ON" if settings.sound else "OFF")
        _save()
    )
    stack.add_child(_center(sound))

    var haptic := _button("HAPTICS HOOK: " + ("ON" if settings.haptics else "OFF"), 360, 64, 18)
    haptic.pressed.connect(func():
        settings.haptics = not settings.haptics
        haptic.text = "HAPTICS HOOK: " + ("ON" if settings.haptics else "OFF")
        _save()
    )
    stack.add_child(_center(haptic))

    var reset := _button("RESET PROGRESS", 360, 64, 18)
    reset.pressed.connect(_reset_progress)
    stack.add_child(_center(reset))

    var close := _button("CLOSE", 220, 58, 17)
    close.pressed.connect(overlay_root.queue_free)
    stack.add_child(_center(close))

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
