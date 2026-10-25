extends Node2D
## Drives level generation (ground/holes/obstacles), scoring and game-over UI.

@export var tile_width: float = 200.0
@export var spawn_ahead: float = 1400.0
@export var despawn_behind: float = 500.0
@export var hole_chance: float = 0.18
@export var obstacle_chance: float = 0.4
@export var safe_runway: float = 600.0

## How far ahead of the player (in px) the narrator calls out an upcoming obstacle.
@export var announce_lead_distance: float = 450.0
## Score below which the narrator is always correct (no mistakes yet).
@export var error_start_score: float = 150.0
## Score at which the narrator's instructions become wrong as often as right (50/50).
@export var error_ramp_score: float = 600.0

const GroundScene := preload("res://scenes/Ground.tscn")
const SpikeScene := preload("res://scenes/Spike.tscn")
const BarScene := preload("res://scenes/Bar.tscn")
const CeilingScene := preload("res://scenes/Ceiling.tscn")
const LavaScene := preload("res://scenes/Lava.tscn")

## Obstacle pool: each entry is spawned with equal chance, paired with the
## action the narrator should call out for it.
var obstacle_defs: Array = []

@onready var player: CharacterBody2D = $Player
@onready var score_label: Label = $UI/ScoreLabel
@onready var high_score_label: Label = $UI/HighScoreLabel
@onready var game_over_panel: Control = $UI/GameOverPanel
@onready var final_score_label: Label = $UI/GameOverPanel/VBoxContainer/FinalScoreLabel
@onready var narrator: Control = $UI/Narrator

var next_spawn_x: float = 0.0
var last_was_hole: bool = false
var tiles_since_obstacle: int = 0
var segments: Array = []
var pending_events: Array = [] # [{x: float, action: "jump"/"crouch"}]
var rng := RandomNumberGenerator.new()
var score_timer: float = 0.0

func _ready() -> void:
	rng.randomize()
	obstacle_defs = [
		{"scene": SpikeScene, "action": "jump"},
		{"scene": BarScene, "action": "crouch"},
		{"scene": CeilingScene, "action": "crouch"},
		{"scene": LavaScene, "action": "jump"},
	]
	Game.score_changed.connect(_on_score_changed)
	Game.game_over.connect(_on_game_over)
	player.died.connect(_on_player_died)
	start_game()

func start_game() -> void:
	for seg in segments:
		if is_instance_valid(seg):
			seg.queue_free()
	segments.clear()
	next_spawn_x = 0.0
	last_was_hole = false
	tiles_since_obstacle = 5
	pending_events.clear()
	narrator.hide_bubble()
	player.reset()
	Game.start_run()
	game_over_panel.visible = false
	_on_score_changed(0)
	while next_spawn_x < player.global_position.x + spawn_ahead:
		_spawn_tile()

func _process(delta: float) -> void:
	if not Game.is_playing:
		return

	while next_spawn_x < player.global_position.x + spawn_ahead:
		_spawn_tile()
	_despawn_old()
	_check_announcements()

	score_timer += delta
	if score_timer >= 0.1:
		score_timer = 0.0
		Game.add_score(1)

func _spawn_tile() -> void:
	var make_hole := false
	if next_spawn_x > safe_runway and tiles_since_obstacle > 2 and not last_was_hole:
		make_hole = rng.randf() < hole_chance

	var event_x := next_spawn_x + tile_width / 2.0

	if make_hole:
		last_was_hole = true
		tiles_since_obstacle = 0
		pending_events.append({"x": event_x, "action": "jump"})
	else:
		last_was_hole = false
		var ground = GroundScene.instantiate()
		ground.position = Vector2(next_spawn_x, 0)
		add_child(ground)
		segments.append(ground)

		if next_spawn_x > safe_runway and tiles_since_obstacle > 3 and rng.randf() < obstacle_chance:
			tiles_since_obstacle = 0
			var def: Dictionary = obstacle_defs[rng.randi_range(0, obstacle_defs.size() - 1)]
			var obstacle: Node2D = def["scene"].instantiate()
			obstacle.position = Vector2(event_x, 0)
			add_child(obstacle)
			segments.append(obstacle)
			pending_events.append({"x": event_x, "action": def["action"]})
		else:
			tiles_since_obstacle += 1

	next_spawn_x += tile_width

func _check_announcements() -> void:
	var trigger_x := player.global_position.x + announce_lead_distance
	for event in pending_events.duplicate():
		if event["x"] <= trigger_x:
			_announce(event["action"])
			pending_events.erase(event)

func _announce(correct_action: String) -> void:
	# No mistakes below error_start_score; past that, the chance of a
	# misleading call ramps up with score, capping out at 50/50 by error_ramp_score.
	var error_chance: float = clamp(
		(float(Game.score) - error_start_score) / (error_ramp_score - error_start_score),
		0.0, 0.5
	)
	var action := correct_action
	if rng.randf() < error_chance:
		action = "crouch" if correct_action == "jump" else "jump"
	narrator.say(action)

func _despawn_old() -> void:
	var threshold := player.global_position.x - despawn_behind
	for seg in segments.duplicate():
		if is_instance_valid(seg) and seg.position.x + tile_width < threshold:
			seg.queue_free()
			segments.erase(seg)

func _on_score_changed(new_score: int) -> void:
	score_label.text = "Score: %d" % new_score
	high_score_label.text = "Best: %d" % Game.high_score

func _on_player_died() -> void:
	pass

func _on_game_over(final_score: int) -> void:
	final_score_label.text = "Score: %d   Best: %d" % [final_score, Game.high_score]
	game_over_panel.visible = true

func _unhandled_input(event: InputEvent) -> void:
	if game_over_panel.visible and event.is_action_pressed("restart"):
		start_game()

func _on_restart_button_pressed() -> void:
	start_game()
