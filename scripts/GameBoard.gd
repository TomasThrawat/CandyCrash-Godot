class_name GameBoard
extends Node2D

signal level_won(stats: Dictionary)
signal level_lost(stats: Dictionary)
signal stats_changed(stats: Dictionary)

const SIZE := 8
const TILE := 72.0
const ORIGIN := Vector2(72, 278)
const KIND_COUNT := 6

var level: Dictionary
var board: Array = []
var visuals: Array = []
var selected := Vector2i(-1, -1)
var moving := false
var score := 0
var moves_left := 0
var combo := 0
var collected := 0
var blockers_left := 0
var jellies_left := 0
var target_color := 0
var rng := RandomNumberGenerator.new()
var audio: AudioManager

func setup(p_level: Dictionary, p_audio: AudioManager) -> void:
    level = p_level.duplicate(true)
    rng.randomize()
    score = 0
    moves_left = int(level.moves)
    combo = 0
    collected = 0
    target_color = int(level.id) % KIND_COUNT
    audio = p_audio
    _init_grid()
    queue_redraw()
    _emit_stats()

func _init_grid() -> void:
    board.clear()
    visuals.clear()
    for y in range(SIZE):
        var row: Array = []
        var vrow: Array = []
        for x in range(SIZE):
            var blocker := false
            var jelly := false
            if int(level.blockers) > 0:
                blocker = _should_block(x, y, int(level.blockers))
            if int(level.jelly) > 0 and (x + y) % 3 == 0:
                jelly = true
            row.append({"kind": rng.randi_range(0, KIND_COUNT - 1), "special": 0, "blocker": blocker, "jelly": jelly})
            vrow.append(null)
        board.append(row)
        visuals.append(vrow)
    blockers_left = _count_flag("blocker")
    jellies_left = _count_flag("jelly")
    for y in range(SIZE):
        for x in range(SIZE):
            while _creates_match(Vector2i(x,y)):
                board[y][x].kind = rng.randi_range(0, KIND_COUNT - 1)
    _refresh_visuals()

func _should_block(x: int, y: int, wanted: int) -> bool:
    var pattern := [Vector2i(1,1),Vector2i(6,1),Vector2i(1,6),Vector2i(6,6),Vector2i(3,3),Vector2i(4,4),
        Vector2i(2,5),Vector2i(5,2),Vector2i(0,3),Vector2i(7,4),Vector2i(3,0),Vector2i(4,7)]
    pattern = pattern.slice(0, min(wanted, pattern.size()))
    return Vector2i(x,y) in pattern

func _count_flag(key: String) -> int:
    var n := 0
    for y in range(SIZE):
        for x in range(SIZE):
            if bool(board[y][x][key]):
                n += 1
    return n

func _creates_match(cell: Vector2i) -> bool:
    if cell.x < 0 or cell.x >= SIZE or cell.y < 0 or cell.y >= SIZE:
        return false
    var k := int(board[cell.y][cell.x].kind)
    if k < 0:
        return false
    if cell.x >= 2 and int(board[cell.y][cell.x-1].kind) == k and int(board[cell.y][cell.x-2].kind) == k:
        return true
    if cell.y >= 2 and int(board[cell.y-1][cell.x].kind) == k and int(board[cell.y-2][cell.x].kind) == k:
        return true
    return false

func _refresh_visuals() -> void:
    for y in range(SIZE):
        for x in range(SIZE):
            var old = visuals[y][x]
            if old and is_instance_valid(old):
                old.queue_free()
            if int(board[y][x].kind) < 0:
                visuals[y][x] = null
                continue
            if bool(board[y][x].blocker):
                var crate := _make_blocker()
                crate.position = _pos(Vector2i(x,y))
                add_child(crate)
                visuals[y][x] = crate
            else:
                var c := Visuals.make_candy_sprite(TILE, int(board[y][x].kind), int(board[y][x].special))
                c.position = _pos(Vector2i(x,y))
                add_child(c)
                visuals[y][x] = c
                if bool(board[y][x].jelly):
                    var jelly := Polygon2D.new()
                    var pts := PackedVector2Array()
                    for i in range(20):
                        var a := TAU * float(i) / 20.0
                        pts.append(Vector2(cos(a),sin(a)) * TILE * 0.40)
                    jelly.polygon = pts
                    jelly.color = Color(1,1,1,0.09)
                    c.add_child(jelly)

func _make_blocker() -> Node2D:
    var root := Node2D.new()
    var panel := Polygon2D.new()
    panel.polygon = PackedVector2Array([
        Vector2(-TILE*0.34,-TILE*0.34),Vector2(TILE*0.34,-TILE*0.34),
        Vector2(TILE*0.34,TILE*0.34),Vector2(-TILE*0.34,TILE*0.34)
    ])
    panel.color = Color("#7b553e")
    root.add_child(panel)
    var hi := Line2D.new()
    hi.width = 5.0
    hi.default_color = Color("#b68a63")
    hi.points = PackedVector2Array([Vector2(-22,-22),Vector2(22,22)])
    root.add_child(hi)
    var lo := Line2D.new()
    lo.width = 5.0
    lo.default_color = Color("#4d3428")
    lo.points = PackedVector2Array([Vector2(-22,22),Vector2(22,-22)])
    root.add_child(lo)
    return root

func _pos(cell: Vector2i) -> Vector2:
    return ORIGIN + Vector2(cell.x * TILE + TILE*0.5, cell.y * TILE + TILE*0.5)

func _cell_at(p: Vector2) -> Vector2i:
    return Vector2i(floor((p.x - ORIGIN.x) / TILE), floor((p.y - ORIGIN.y) / TILE))

func _unhandled_input(event: InputEvent) -> void:
    if moving:
        return
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        _select_or_swap(get_viewport().get_mouse_position())
    elif event is InputEventScreenTouch and event.pressed:
        _select_or_swap(event.position)

func _select_or_swap(pos: Vector2) -> void:
    var c := _cell_at(pos)
    if c.x < 0 or c.x >= SIZE or c.y < 0 or c.y >= SIZE:
        return
    if bool(board[c.y][c.x].blocker):
        _pulse(c)
        return
    if selected.x < 0:
        selected = c
        _pulse(c)
        return
    if _adjacent(selected, c):
        _attempt_swap(selected, c)
        selected = Vector2i(-1,-1)
    else:
        selected = c
        _pulse(c)

func _adjacent(a: Vector2i, b: Vector2i) -> bool:
    return abs(a.x-b.x) + abs(a.y-b.y) == 1

func _pulse(cell: Vector2i) -> void:
    var node = visuals[cell.y][cell.x]
    if node:
        var t := create_tween()
        t.tween_property(node, "scale", Vector2(1.12,1.12), 0.07)
        t.tween_property(node, "scale", Vector2.ONE, 0.11)

func _attempt_swap(a: Vector2i, b: Vector2i) -> void:
    if moves_left <= 0:
        return
    moving = true
    audio.play("slide")
    var va = visuals[a.y][a.x]
    var vb = visuals[b.y][b.x]
    var p1 = va.position if va else _pos(a)
    var p2 = vb.position if vb else _pos(b)
    var tt := create_tween().set_parallel(true)
    if va: tt.tween_property(va, "position", p2, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    if vb: tt.tween_property(vb, "position", p1, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    await tt.finished
    _swap_data(a,b)
    _swap_visual_refs(a,b)
    var special_combo := _special_combo(a,b)
    if special_combo:
        moves_left -= 1
        await _resolve_special_combo(a,b)
    elif _has_any_match():
        moves_left -= 1
        await _resolve_cascades()
    else:
        _swap_data(a,b)
        _swap_visual_refs(a,b)
        var back := create_tween().set_parallel(true)
        if vb: back.tween_property(vb, "position", p2, 0.14)
        if va: back.tween_property(va, "position", p1, 0.14)
        await back.finished
        audio.play("lose", 0.65)
    combo = 0
    moving = false
    _emit_stats()
    _check_end()

func _swap_data(a: Vector2i, b: Vector2i) -> void:
    var tmp = board[a.y][a.x]
    board[a.y][a.x] = board[b.y][b.x]
    board[b.y][b.x] = tmp

func _swap_visual_refs(a: Vector2i, b: Vector2i) -> void:
    var tmp = visuals[a.y][a.x]
    visuals[a.y][a.x] = visuals[b.y][b.x]
    visuals[b.y][b.x] = tmp

func _special_combo(a: Vector2i,b:Vector2i) -> bool:
    return int(board[a.y][a.x].special) > 0 and int(board[b.y][b.x].special) > 0

func _resolve_special_combo(a: Vector2i,b:Vector2i) -> void:
    var sa := int(board[a.y][a.x].special)
    var sb := int(board[b.y][b.x].special)
    var clear: Dictionary = {}
    if sa == 4 or sb == 4:
        var other_kind := int(board[b.y][b.x].kind) if sa == 4 else int(board[a.y][a.x].kind)
        for y in range(SIZE):
            for x in range(SIZE):
                if int(board[y][x].kind) == other_kind or (sa == 4 and sb == 4):
                    clear[Vector2i(x,y)] = true
    elif sa in [1,2] and sb in [1,2]:
        for i in range(SIZE):
            clear[Vector2i(i,a.y)] = true
            clear[Vector2i(a.x,i)] = true
            clear[Vector2i(i,b.y)] = true
            clear[Vector2i(b.x,i)] = true
    elif sa == 3 or sb == 3:
        for dy in range(-2,3):
            for dx in range(-2,3):
                var q := Vector2i(a.x+dx,a.y+dy)
                if _inside(q): clear[q]=true
    else:
        clear[a]=true
        clear[b]=true
    combo += 1
    score += 800 + combo * 250
    audio.play("bonus", 1.0 + combo*0.03)
    _process_objectives_before_clear(clear.keys())
    await _clear_cells(clear.keys())
    await _collapse_and_refill()

func _resolve_cascades() -> void:
    var chain := 0
    while true:
        var matches := _find_match_groups()
        if matches.is_empty():
            break
        chain += 1
        combo = chain
        var clear: Dictionary = {}
        var special_to_create: Dictionary = {}
        for group in matches:
            for cell in group.cells:
                clear[cell] = true
            var match_len: int = group["cells"].size()
            if match_len >= 5:
                special_to_create[group.cells[2]] = 4
            elif match_len == 4:
                special_to_create[group.cells[1]] = 1 if group.horizontal else 2
            elif group.intersection.x >= 0:
                special_to_create[group.intersection] = 3
        for cell in clear.keys():
            var c: Vector2i = cell
            if int(board[c.y][c.x].special) > 0:
                _add_special_clear(clear, c, int(board[c.y][c.x].special))
        for cell in special_to_create:
            clear.erase(cell)
        score += clear.size() * 60 * max(1, chain)
        audio.play("combo", min(1.3, 0.9 + chain*0.08) if chain >= 2 else 0.9 + (clear.size()-3)*0.04)
        _process_objectives_before_clear(clear.keys())
        await _clear_cells(clear.keys())
        for cell in special_to_create:
            if _inside(cell) and not board[cell.y][cell.x].blocker:
                board[cell.y][cell.x].special = special_to_create[cell]
        await _collapse_and_refill()
    combo = chain

func _add_special_clear(clear: Dictionary, cell: Vector2i, special: int) -> void:
    if special == 1:
        for x in range(SIZE): clear[Vector2i(x,cell.y)] = true
    elif special == 2:
        for y in range(SIZE): clear[Vector2i(cell.x,y)] = true
    elif special == 3:
        for dy in range(-1,2):
            for dx in range(-1,2):
                var q := Vector2i(cell.x+dx,cell.y+dy)
                if _inside(q): clear[q]=true
    elif special == 4:
        var k := int(board[cell.y][cell.x].kind)
        for y in range(SIZE):
            for x in range(SIZE):
                if int(board[y][x].kind) == k: clear[Vector2i(x,y)] = true

func _find_match_groups() -> Array:
    var groups: Array = []
    for y in range(SIZE):
        var x := 0
        while x < SIZE:
            if board[y][x].blocker:
                x += 1
                continue
            var k := int(board[y][x].kind)
            if k < 0:
                x += 1
                continue
            var s := x
            while x+1 < SIZE and not board[y][x+1].blocker and int(board[y][x+1].kind) == k:
                x += 1
            if x-s+1 >= 3:
                var cells: Array[Vector2i] = []
                for q in range(s,x+1): cells.append(Vector2i(q,y))
                groups.append({"cells":cells,"horizontal":true,"intersection":Vector2i(-1,-1)})
            x += 1
    for x in range(SIZE):
        var y := 0
        while y < SIZE:
            if board[y][x].blocker:
                y += 1
                continue
            var k := int(board[y][x].kind)
            if k < 0:
                y += 1
                continue
            var s := y
            while y+1 < SIZE and not board[y+1][x].blocker and int(board[y+1][x].kind) == k:
                y += 1
            if y-s+1 >= 3:
                var cells2: Array[Vector2i] = []
                for q in range(s,y+1): cells2.append(Vector2i(x,q))
                var inter := Vector2i(-1,-1)
                for c in cells2:
                    for g in groups:
                        if c in g.cells:
                            inter = c
                groups.append({"cells":cells2,"horizontal":false,"intersection":inter})
            y += 1
    return groups

func _has_any_match() -> bool:
    return not _find_match_groups().is_empty()

func _process_objectives_before_clear(cells: Array) -> void:
    for cell in cells:
        if not _inside(cell):
            continue
        if bool(board[cell.y][cell.x].jelly):
            board[cell.y][cell.x].jelly = false
        var k := int(board[cell.y][cell.x].kind)
        if k == target_color:
            collected += 1
        for d in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
            var n: Vector2i = cell + d
            if _inside(n) and bool(board[n.y][n.x].blocker):
                board[n.y][n.x].blocker = false
                board[n.y][n.x].kind = -1

func _clear_cells(cells: Array) -> void:
    for cell in cells:
        if not _inside(cell):
            continue
        if board[cell.y][cell.x].blocker:
            continue
        var node = visuals[cell.y][cell.x]
        if node and is_instance_valid(node):
            var t := create_tween().set_parallel(true)
            t.tween_property(node, "scale", Vector2(1.45,1.45), 0.10)
            t.tween_property(node, "modulate:a", 0.0, 0.12)
            await t.finished
            _spawn_burst(_pos(cell), Visuals.candy_color(int(board[cell.y][cell.x].kind)))
            node.queue_free()
        board[cell.y][cell.x].kind = -1
        board[cell.y][cell.x].special = 0
        board[cell.y][cell.x].jelly = false
        visuals[cell.y][cell.x] = null

func _collapse_and_refill() -> void:
    for x in range(SIZE):
        var write := SIZE - 1
        for y in range(SIZE - 1,-1,-1):
            if bool(board[y][x].blocker):
                write = y - 1
                continue
            if int(board[y][x].kind) >= 0:
                if y != write and write >= 0 and not bool(board[write][x].blocker):
                    board[write][x] = board[y][x]
                    visuals[write][x] = visuals[y][x]
                    visuals[y][x] = null
                write -= 1
        for y in range(write,-1,-1):
            if bool(board[y][x].blocker):
                continue
            board[y][x] = {"kind":rng.randi_range(0,KIND_COUNT-1),"special":0,"blocker":false,"jelly":false}
            var node := Visuals.make_candy_sprite(TILE,int(board[y][x].kind),0)
            node.position = ORIGIN + Vector2(x*TILE+TILE*0.5, y*TILE-TILE*2)
            add_child(node)
            visuals[y][x] = node
            var dest := _pos(Vector2i(x,y))
            var t := create_tween()
            t.tween_property(node,"position",dest,0.22 + (SIZE-y)*0.025).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    await get_tree().create_timer(0.28).timeout
    _refresh_visuals()

func _spawn_burst(pos: Vector2, color: Color) -> void:
    var layer := Node2D.new()
    layer.position = pos
    add_child(layer)
    for i in range(10):
        var dot := Polygon2D.new()
        var p := PackedVector2Array()
        for j in range(8):
            var a := TAU*float(j)/8.0
            p.append(Vector2(cos(a),sin(a))*4)
        dot.polygon = p
        dot.color = color.lightened(0.25)
        layer.add_child(dot)
        var a := TAU*float(i)/10.0
        var end := Vector2(cos(a),sin(a)) * rng.randf_range(35,70)
        var t := create_tween().set_parallel(true)
        t.tween_property(dot,"position",end,0.26)
        t.tween_property(dot,"modulate:a",0.0,0.28)
        t.tween_property(dot,"scale",Vector2(0.2,0.2),0.28)
    get_tree().create_timer(0.32).timeout.connect(layer.queue_free)

func _check_end() -> void:
    var objective := int(level.objective)
    var won := false
    if objective == LevelData.ObjectiveType.SCORE:
        won = score >= int(level.target)
    elif objective == LevelData.ObjectiveType.BLOCKERS:
        won = _count_flag("blocker") <= 0
    elif objective == LevelData.ObjectiveType.COLLECT:
        won = collected >= int(level.target)
    elif objective == LevelData.ObjectiveType.JELLY:
        won = _count_flag("jelly") <= 0
    if won:
        audio.play("win")
        level_won.emit(get_stats())
    elif moves_left <= 0:
        audio.play("lose")
        level_lost.emit(get_stats())

func get_stats() -> Dictionary:
    return {
        "level":int(level.id),
        "score":score,
        "moves":moves_left,
        "combo":combo,
        "collected":collected,
        "blockers":_count_flag("blocker"),
        "jellies":_count_flag("jelly"),
        "target":int(level.target),
        "objective":int(level.objective)
    }

func _emit_stats() -> void:
    stats_changed.emit(get_stats())

func _inside(c: Vector2i) -> bool:
    return c.x >= 0 and c.x < SIZE and c.y >= 0 and c.y < SIZE

func _draw() -> void:
    draw_rect(Rect2(48,254,624,624), Color("#17113D"), true)
    draw_rect(Rect2(56,262,608,608), Color("#231C4E"), true)
    for y in range(SIZE):
        for x in range(SIZE):
            var r := Rect2(ORIGIN + Vector2(x*TILE,y*TILE), Vector2(TILE,TILE)).grow(-5)
            draw_style_box(_cell_box(x+y), r)

func _cell_box(n: int) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = Color("#ffffff", 0.045 if n%2==0 else 0.075)
    s.corner_radius_top_left = 14
    s.corner_radius_top_right = 14
    s.corner_radius_bottom_left = 14
    s.corner_radius_bottom_right = 14
    return s
