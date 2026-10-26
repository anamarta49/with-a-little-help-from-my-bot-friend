extends Control
## Simple outlined up/down arrow icon, drawn procedurally so it never depends
## on a font glyph (works regardless of which font is active).

@export var pointing_down: bool = false
@export var line_color: Color = Color(0.92, 0.92, 0.95, 1)
@export var line_width: float = 3.0

## Arrow outline, expressed as normalized (0-1) points pointing up by default.
const POINTS := [
	Vector2(0.5, 0.0),
	Vector2(0.95, 0.4),
	Vector2(0.68, 0.4),
	Vector2(0.68, 1.0),
	Vector2(0.32, 1.0),
	Vector2(0.32, 0.4),
	Vector2(0.05, 0.4),
]

func _draw() -> void:
	var w := size.x
	var h := size.y
	var pts := PackedVector2Array()
	for p in POINTS:
		var point: Vector2 = p
		var y: float = point.y
		if pointing_down:
			y = 1.0 - y
		pts.append(Vector2(point.x * w, y * h))
	pts.append(pts[0])
	draw_polyline(pts, line_color, line_width, true)
