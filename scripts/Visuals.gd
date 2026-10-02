class_name Visuals
extends RefCounted

static var candy_colors := [
	Color("#ff4d73"),
	Color("#45a3ff"),
	Color("#ffd34d"),
	Color("#59df8c"),
	Color("#b875ff"),
	Color("#ff8a3d")
]

static func candy_color(kind: int) -> Color:
	return candy_colors[clamp(kind, 0, candy_colors.size() - 1)]

static func candy_name(kind: int) -> String:
	return ["Cherry", "Blueberry", "Lemon", "Mint", "Grape", "Orange"][clamp(kind, 0, 5)]

static func make_candy_sprite(size: float, kind: int, special: int = 0) -> Node2D:
	var root := Node2D.new()
	var orb := Polygon2D.new()
	var pts := PackedVector2Array()
	var c := candy_color(kind)
	var radius := size * 0.36
	for j in range(24):
		var a := TAU * float(j) / 24.0
		var wobble := 1.0 + 0.05 * sin(a * 3.0 + kind)
		pts.append(Vector2(cos(a), sin(a)) * radius * wobble)
	orb.polygon = pts
	orb.color = c
	root.add_child(orb)
	var shine := Polygon2D.new()
	shine.polygon = PackedVector2Array([
		Vector2(-radius * 0.44, -radius * 0.52),
		Vector2(-radius * 0.18, -radius * 0.67),
		Vector2(radius * 0.05, -radius * 0.42),
		Vector2(-radius * 0.16, -radius * 0.16)
	])
	shine.color = Color(1,1,1,0.48)
	root.add_child(shine)
	var ring := Line2D.new()
	ring.width = 3.0
	ring.default_color = c.lightened(0.22)
	ring.closed = true
	ring.points = pts
	root.add_child(ring)
	if special == 1:
		var stripe := Line2D.new()
		stripe.width = 6.0
		stripe.default_color = Color(1,1,1,0.82)
		stripe.points = PackedVector2Array([Vector2(-radius, 0), Vector2(radius, 0)])
		root.add_child(stripe)
	elif special == 2:
		var stripe2 := Line2D.new()
		stripe2.width = 6.0
		stripe2.default_color = Color(1,1,1,0.82)
		stripe2.points = PackedVector2Array([Vector2(0, -radius), Vector2(0, radius)])
		root.add_child(stripe2)
	elif special == 3:
		var cross := Line2D.new()
		cross.width = 5.0
		cross.default_color = Color(1,1,1,0.85)
		cross.points = PackedVector2Array([Vector2(-radius*0.7,-radius*0.7),Vector2(radius*0.7,radius*0.7)])
		root.add_child(cross)
	elif special == 4:
		var sparkle := Label.new()
		sparkle.text = "✦"
		sparkle.add_theme_font_size_override("font_size", int(size * 0.7))
		sparkle.modulate = Color(1,1,1,0.95)
		sparkle.position = Vector2(-size*0.25,-size*0.39)
		root.add_child(sparkle)
	return root
