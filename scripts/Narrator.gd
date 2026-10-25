extends Control
## Narrator bot: shows a speech bubble with a short instruction, then auto-hides.

@onready var bubble: Panel = $SpeechBubble
@onready var label: Label = $SpeechBubble/MarginContainer/Label
@onready var hide_timer: Timer = $HideTimer

const ACTION_TEXT := {
	"jump": "Jump!",
	"crouch": "Crouch!",
}

const BONUS_PHRASES := [
	"There's one, catch it!",
	"Hallucination!!",
	"Looks sus...",
	"Jump on him!",
]

const BASE_FONT_SIZE := 24
const MIN_FONT_SIZE := 14
const SHRINK_AFTER_CHARS := 12

func _ready() -> void:
	bubble.visible = false
	hide_timer.one_shot = true
	hide_timer.timeout.connect(_on_hide_timer_timeout)

func say(action: String, duration: float = 1.4) -> void:
	var text: String
	if action == "bonus":
		text = BONUS_PHRASES[randi() % BONUS_PHRASES.size()]
	else:
		text = ACTION_TEXT.get(action, action.capitalize())
	say_text(text, duration)

## Shows arbitrary dialogue text. Pass duration <= 0 to keep the bubble open
## indefinitely (e.g. while waiting on a player choice).
func say_text(text: String, duration: float = 1.4) -> void:
	label.text = text
	label.add_theme_font_size_override("font_size", _font_size_for(text))
	bubble.visible = true
	if duration > 0.0:
		hide_timer.start(duration)
	else:
		hide_timer.stop()

## Shrinks the font for longer lines so they stay inside the bubble.
func _font_size_for(text: String) -> int:
	if text.length() <= SHRINK_AFTER_CHARS:
		return BASE_FONT_SIZE
	var extra_chars := text.length() - SHRINK_AFTER_CHARS
	return max(MIN_FONT_SIZE, BASE_FONT_SIZE - extra_chars)

func hide_bubble() -> void:
	bubble.visible = false
	hide_timer.stop()

func _on_hide_timer_timeout() -> void:
	bubble.visible = false
