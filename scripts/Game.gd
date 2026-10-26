extends Node
## Global game state: score tracking and run/game-over signaling.
## Autoloaded as "Game" so any scene can read/update it.
##
## Two scores are tracked separately:
## - progress: points earned just from surviving/running (distance); a flavor
##   metric only, it does not affect the high score.
## - hallucinations: kB earned from catching camouflaged bonus pickups
##   ("hallucinations" the narrator bot spots for you); this is the real score
##   that the high score is based on. The raw int is always in kB (a standard
##   catch is worth 100); use format_memory() to display it as kB/MB/GB.

signal progress_changed(new_value: int)
signal hallucinations_changed(new_value: int)
signal loose_hallucinations_changed(new_value: int)
signal game_over(final_progress: int, final_hallucinations: int, is_new_high_score: bool)
signal game_started
## Fired once, when missed hallucinations reach the fatal threshold.
signal system_corrupted

var progress: int = 0
var hallucinations: int = 0
var loose_hallucinations: int = 0
var high_score: int = 0
var is_playing: bool = false

func start_run() -> void:
	progress = 0
	hallucinations = 0
	loose_hallucinations = 0
	is_playing = true
	emit_signal("progress_changed", progress)
	emit_signal("hallucinations_changed", hallucinations)
	emit_signal("loose_hallucinations_changed", loose_hallucinations)
	emit_signal("game_started")

func add_progress(amount: int) -> void:
	if not is_playing:
		return
	progress += amount
	emit_signal("progress_changed", progress)

func add_hallucination(amount: int) -> void:
	if not is_playing:
		return
	hallucinations += amount
	emit_signal("hallucinations_changed", hallucinations)

## Missed hallucinations at/above this count corrupt the system -- instant game over.
const SYSTEM_CORRUPTION_THRESHOLD := 5

## Called when a camouflaged hallucination scrolls past uncaught.
func add_loose_hallucination() -> void:
	if not is_playing:
		return
	loose_hallucinations += 1
	emit_signal("loose_hallucinations_changed", loose_hallucinations)
	if loose_hallucinations >= SYSTEM_CORRUPTION_THRESHOLD:
		emit_signal("system_corrupted")

func end_run() -> void:
	if not is_playing:
		return
	is_playing = false
	var is_new_high_score := false
	if hallucinations > high_score:
		high_score = hallucinations
		is_new_high_score = true
	emit_signal("game_over", progress, hallucinations, is_new_high_score)

## Formats a kB amount as a human-readable memory size: kB under 1000,
## MB under 1,000,000, GB beyond that (doesn't bother with anything bigger).
func format_memory(kb: int) -> String:
	if kb < 1000:
		return "%dkB" % kb
	elif kb < 1_000_000:
		return _format_unit(kb / 1000.0, "MB")
	else:
		return _format_unit(kb / 1_000_000.0, "GB")

## Rounds to 2 decimals and trims trailing zeros (e.g. 2.00 -> "2", 2.50 -> "2.5").
func _format_unit(value: float, unit: String) -> String:
	var text := String.num(value, 2)
	if text.contains("."):
		text = text.rstrip("0").rstrip(".")
	return text + unit
