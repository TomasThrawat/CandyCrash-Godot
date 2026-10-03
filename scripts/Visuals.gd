class_name Visuals
extends RefCounted

static var candy_colors := [
    Color("#FF6E9B"),
    Color("#63B9FF"),
    Color("#FFE06B"),
    Color("#70E6A0"),
    Color("#C99BFF"),
    Color("#FFA258")
]

static func candy_color(kind: int) -> Color:
    return candy_colors[clamp(kind, 0, candy_colors.size() - 1)]

static func candy_name(kind: int) -> String:
    return ["Cherry", "Blueberry", "Lemon", "Mint", "Grape", "Orange"][clamp(kind, 0, 5)]

static func _shape_points(kind: int, r: float) -> PackedVector2Array:
    var pts := PackedVector2Array()
    match kind:
        0:
            pts = PackedVector2Array([
                Vector2(0, r*0.95), Vector2(-r*0.62, r*0.48), Vector2(-r*0.92, 0.02),
                Vector2(-r*0.84, -r*0.50), Vector2(-r*0.45, -r*0.76), Vector2(0, -r*0.36),
                Vector2(r*0.45, -r*0.76), Vector2(r*0.84, -r*0.50), Vector2(r*0.92, 0.02),
                Vector2(r*0.62, r*0.48)
            ])
        1:
            pts = PackedVector2Array([
                Vector2(0,-r), Vector2(r*0.94,-r*0.05), Vector2(0,r), Vector2(-r*0.94,-r*0.05)
            ])
        2:
            for i in range(10):
                var a := -PI*0.5 + TAU*float(i)/10.0
                var rr := r if i % 2 == 0 else r*0.44
                pts.append(Vector2(cos(a),sin(a))*rr)
        3:
            pts = PackedVector2Array([
                Vector2(0,-r), Vector2(r*0.52,-r*0.76), Vector2(r*0.82,-r*0.34),
                Vector2(r*0.78,r*0.20), Vector2(r*0.48,r*0.70), Vector2(0,r),
                Vector2(-r*0.46,r*0.70), Vector2(-r*0.80,r*0.18), Vector2(-r*0.84,-r*0.30),
                Vector2(-r*0.48,-r*0.74)
            ])
        4:
            for i in range(16):
                var a := TAU*float(i)/16.0
                var rr := r * (0.86 + 0.10*sin(a*3.0+0.6))
                pts.append(Vector2(cos(a),sin(a))*rr)
        _:
            pts = PackedVector2Array([
                Vector2(-r*0.55,-r), Vector2(r*0.42,-r*0.94), Vector2(r*0.92,-r*0.24),
                Vector2(r*0.62,r*0.80), Vector2(-r*0.28,r), Vector2(-r*0.92,r*0.24)
            ])
    return pts

static func _add_highlight(root: Node2D, size: float, kind: int) -> void:
    var rr := size * 0.34
    var shine := Polygon2D.new()
    shine.polygon = PackedVector2Array([
        Vector2(-rr*0.48,-rr*0.56), Vector2(-rr*0.16,-rr*0.70),
        Vector2(rr*0.02,-rr*0.47), Vector2(-rr*0.22,-rr*0.18)
    ])
    shine.color = Color(1,1,1,0.42)
    root.add_child(shine)

    if kind == 0:
        var stem := Line2D.new()
        stem.width = 4.0
        stem.default_color = Color("#46A86A")
        stem.points = PackedVector2Array([Vector2(0,-rr*0.78),Vector2(rr*0.08,-rr*1.02)])
        root.add_child(stem)
    elif kind == 3:
        var vein := Line2D.new()
        vein.width = 2.5
        vein.default_color = Color(1,1,1,0.28)
        vein.points = PackedVector2Array([Vector2(-rr*0.22,rr*0.58),Vector2(0,0),Vector2(rr*0.22,-rr*0.58)])
        root.add_child(vein)

static func make_candy_sprite(size: float, kind: int, special: int = 0) -> Node2D:
    var root := Node2D.new()
    var c := candy_color(kind)
    var r := size * 0.36

    var body := Polygon2D.new()
    body.polygon = _shape_points(kind, r)
    body.color = c
    root.add_child(body)

    var outline := Line2D.new()
    outline.width = 2.5
    outline.default_color = c.lightened(0.22)
    outline.closed = true
    outline.points = _shape_points(kind, r)
    root.add_child(outline)

    _add_highlight(root, size, kind)

    if special == 1:
        var stripe := Line2D.new()
        stripe.width = 7.0
        stripe.default_color = Color(1,1,1,0.84)
        stripe.points = PackedVector2Array([Vector2(-r*0.92,0),Vector2(r*0.92,0)])
        root.add_child(stripe)
    elif special == 2:
        var stripe2 := Line2D.new()
        stripe2.width = 7.0
        stripe2.default_color = Color(1,1,1,0.84)
        stripe2.points = PackedVector2Array([Vector2(0,-r*0.92),Vector2(0,r*0.92)])
        root.add_child(stripe2)
    elif special == 3:
        for flip in [false, true]:
            var cross := Line2D.new()
            cross.width = 5.0
            cross.default_color = Color(1,1,1,0.84)
            cross.points = PackedVector2Array([
                Vector2(-r*0.68, -r*0.68 if not flip else r*0.68),
                Vector2(r*0.68, r*0.68 if not flip else -r*0.68)
            ])
            root.add_child(cross)
    elif special == 4:
        for i in range(4):
            var spoke := Line2D.new()
            spoke.width = 3.5
            spoke.default_color = Color("#FFFFFF")
            var a := TAU*float(i)/4.0 + PI*0.25
            spoke.points = PackedVector2Array([
                Vector2(cos(a),sin(a))*r*0.30,
                Vector2(cos(a),sin(a))*r*0.86
            ])
            root.add_child(spoke)

    return root
