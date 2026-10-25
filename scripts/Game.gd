extends Node
## Global game state: score tracking and run/game-over signaling.
## Autoloaded as "Game" so any scene can read/update it.

signal score_changed(new_score: int)
signal game_over(final_score: int)
signal game_started

var score: int = 0
var high_score: int = 0
var is_playing: bool = false

func start_run() -> void:
	score = 0
	is_playing = true
	emit_signal("score_changed", score)
	emit_signal("game_started")

func add_score(amount: int) -> void:
	if not is_playing:
		return
	score += amount
	emit_signal("score_changed", score)

func end_run() -> void:
	if not is_playing:
		return
	is_playing = false
	if score > high_score:
		high_score = score
	emit_signal("game_over", score)
