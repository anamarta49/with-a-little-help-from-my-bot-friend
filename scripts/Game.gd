extends Node
## Global game state: score tracking and run/game-over signaling.
## Autoloaded as "Game" so any scene can read/update it.
##
## Two scores are tracked separately:
## - progress: points earned just from surviving/running (distance); a flavor
##   metric only, it does not affect the high score.
## - hallucinations: points earned from catching camouflaged bonus pickups
##   ("hallucinations" the narrator bot spots for you); this is the real score
##   that the high score is based on.

signal progress_changed(new_value: int)
signal hallucinations_changed(new_value: int)
signal game_over(final_progress: int, final_hallucinations: int)
signal game_started

var progress: int = 0
var hallucinations: int = 0
var high_score: int = 0
var is_playing: bool = false

func start_run() -> void:
	progress = 0
	hallucinations = 0
	is_playing = true
	emit_signal("progress_changed", progress)
	emit_signal("hallucinations_changed", hallucinations)
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

func end_run() -> void:
	if not is_playing:
		return
	is_playing = false
	if hallucinations > high_score:
		high_score = hallucinations
	emit_signal("game_over", progress, hallucinations)
