extends Control
## Narrator bot: shows a speech bubble with a short instruction, then auto-hides.

@onready var bubble: Panel = $SpeechBubble
@onready var label: Label = $SpeechBubble/MarginContainer/Label
@onready var hide_timer: Timer = $HideTimer
@onready var bot_visual: Control = $BotVisual
@onready var eye_left_top: ColorRect = $BotVisual/BotBody/BotEyeLeftTop
@onready var eye_left_bottom: ColorRect = $BotVisual/BotBody/BotEyeLeftBottom
@onready var eye_right_top: ColorRect = $BotVisual/BotBody/BotEyeRightTop
@onready var eye_right_bottom: ColorRect = $BotVisual/BotBody/BotEyeRightBottom

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

var _bot_base_y: float
var _blink_timer: Timer

func _ready() -> void:
	bubble.visible = false
	hide_timer.one_shot = true
	hide_timer.timeout.connect(_on_hide_timer_timeout)
	_bot_base_y = bot_visual.position.y
	# Top eyelids pivot on their own top edge (stay put, grow downward);
	# bottom eyelids pivot on their own bottom edge (stay put, grow upward) --
	# together they close "from the outer edges" toward the middle, like real eyelids.
	eye_left_top.pivot_offset = Vector2(eye_left_top.size.x / 2.0, 0.0)
	eye_left_bottom.pivot_offset = Vector2(eye_left_bottom.size.x / 2.0, eye_left_bottom.size.y)
	eye_right_top.pivot_offset = Vector2(eye_right_top.size.x / 2.0, 0.0)
	eye_right_bottom.pivot_offset = Vector2(eye_right_bottom.size.x / 2.0, eye_right_bottom.size.y)
	# Eyes start fully open: eyelid covers collapsed to nothing.
	_set_eyelids_scale(0.0)
	_start_idle_bob()
	_start_blinking()

## Gentle looping bob so Trusty isn't a static statue between lines.
func _start_idle_bob() -> void:
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(bot_visual, "position:y", _bot_base_y - 3.0, 1.1) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(bot_visual, "position:y", _bot_base_y, 1.1) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## Occasional quick blink (eyes squash flat then back) at random intervals.
func _start_blinking() -> void:
	_blink_timer = Timer.new()
	_blink_timer.one_shot = true
	add_child(_blink_timer)
	_blink_timer.timeout.connect(_do_blink)
	_schedule_next_blink()

func _schedule_next_blink() -> void:
	_blink_timer.start(randf_range(2.0, 5.0))

func _set_eyelids_scale(value: float) -> void:
	eye_left_top.scale.y = value
	eye_left_bottom.scale.y = value
	eye_right_top.scale.y = value
	eye_right_bottom.scale.y = value

## Occasional quick blink: the eyelid-colored covers grow from the top and
## bottom edges of each eye to meet in the middle, then shrink back open.
func _do_blink() -> void:
	var tween := create_tween()
	tween.tween_method(_set_eyelids_scale, 0.0, 1.0, 0.06)
	tween.tween_method(_set_eyelids_scale, 1.0, 0.0, 0.08)
	_schedule_next_blink()

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
