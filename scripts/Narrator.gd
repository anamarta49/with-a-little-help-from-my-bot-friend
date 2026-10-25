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

func _ready() -> void:
	bubble.visible = false
	hide_timer.one_shot = true
	hide_timer.timeout.connect(_on_hide_timer_timeout)

func say(action: String, duration: float = 1.4) -> void:
	if action == "bonus":
		label.text = BONUS_PHRASES[randi() % BONUS_PHRASES.size()]
	else:
		label.text = ACTION_TEXT.get(action, action.capitalize())
	bubble.visible = true
	hide_timer.start(duration)

func hide_bubble() -> void:
	bubble.visible = false
	hide_timer.stop()

func _on_hide_timer_timeout() -> void:
	bubble.visible = false
