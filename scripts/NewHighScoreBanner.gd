extends Control
## Builds a short string as individual colored letters arced into a cheerful
## "rainbow" banner shape, with a staggered bounce-in reveal. Used for the
## "New High Score!" celebration above the Game Over panel.

const LETTER_SPACING := 20.0
const CURVE_HEIGHT := 16.0
const FONT_SIZE := 30
const COLOR_A := Color(1.0, 0.85, 0.15, 1) # yellow
const COLOR_B := Color(0.35, 0.9, 0.35, 1) # green

var _letters: Array = []

func show_text(text: String) -> void:
	_clear_letters()
	var n := text.length()
	var center := (n - 1) / 2.0
	var half_width: float = max(center, 1.0)
	for i in range(n):
		var ch := text[i]
		var lbl := Label.new()
		lbl.text = ch
		lbl.add_theme_font_size_override("font_size", FONT_SIZE)
		lbl.add_theme_color_override("font_color", COLOR_A if i % 2 == 0 else COLOR_B)
		var relative: float = i - center
		var x := relative * LETTER_SPACING
		var y := -CURVE_HEIGHT * (1.0 - pow(relative / half_width, 2.0))
		lbl.position = Vector2(x, y)
		lbl.pivot_offset = Vector2(8, 16)
		lbl.rotation = deg_to_rad(relative * 2.0)
		lbl.scale = Vector2.ZERO
		add_child(lbl)
		_letters.append(lbl)

		var tween := create_tween()
		tween.tween_interval(i * 0.04)
		tween.tween_property(lbl, "scale", Vector2.ONE, 0.25) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	visible = true

func hide_banner() -> void:
	visible = false
	_clear_letters()

func _clear_letters() -> void:
	for l in _letters:
		if is_instance_valid(l):
			l.queue_free()
	_letters.clear()
