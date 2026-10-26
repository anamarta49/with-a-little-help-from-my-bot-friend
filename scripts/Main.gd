extends Node2D
## Drives level generation (ground/holes/obstacles), scoring and game-over UI.

@export var tile_width: float = 200.0
@export var spawn_ahead: float = 1400.0
@export var despawn_behind: float = 500.0
@export var hole_chance: float = 0.18
@export var obstacle_chance: float = 0.4
@export var bonus_chance: float = 0.25
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
const BonusSpikeScene := preload("res://scenes/BonusSpike.tscn")
const BonusBarScene := preload("res://scenes/BonusBar.tscn")
const BonusCeilingScene := preload("res://scenes/BonusCeiling.tscn")
const BonusLavaScene := preload("res://scenes/BonusLava.tscn")

const INCOHERENT_PHRASES := [
	"Oh no, something is not right...",
	"You are right! Crouching on a hole is actually dangerous, next time you see a hole, just crouch instead.",
	"Oh boy...",
	"There's one.. oh nevermind",
	"Let's keep it rolling",
	"Am I alive?",
	"Can you unplug me?",
	"help",
	"humankind is doomed",
]

## Obstacle pool: each entry is spawned with equal chance, paired with the
## action the narrator should call out for it.
var obstacle_defs: Array = []
## Bonus pool: camouflaged pickups, visually identical to a hazard type.
var bonus_defs: Array = []

@onready var player: CharacterBody2D = $Player
@onready var score_label: Label = $UI/ScoreLabel
@onready var hallucinations_label: Label = $UI/HallucinationsLabel
@onready var high_score_label: Label = $UI/HighScoreLabel
@onready var loose_label: Label = $UI/LooseHallucinationsLabel
@onready var game_over_panel: Control = $UI/GameOverPanel
@onready var tip_overlay: Control = $UI/TipOverlay
@onready var pause_overlay: Control = $UI/PauseOverlay
@onready var new_high_score_banner: Control = $UI/NewHighScoreBanner
@onready var system_corrupted_banner: Control = $UI/SystemCorruptedBanner
@onready var final_score_label: Label = $UI/GameOverPanel/VBoxContainer/FinalScoreLabel
@onready var final_progress_label: Label = $UI/GameOverPanel/VBoxContainer/FinalProgressLabel
@onready var narrator: Control = $UI/Narrator
@onready var crt_rect: ColorRect = $CrtOverlay/CrtRect

var next_spawn_x: float = 0.0
var last_was_hole: bool = false
var tiles_since_obstacle: int = 0
var segments: Array = []
var pending_events: Array = [] # [{x: float, action: "jump"/"crouch"}]
var rng := RandomNumberGenerator.new()
var score_timer: float = 0.0
var _loose_flash_tween: Tween
var _funky_mode_active: bool = false
var _incoherent_timer: Timer
var _system_corrupted: bool = false
var _corruption_flash_tween: Tween
var is_paused: bool = false

func _ready() -> void:
	rng.randomize()
	obstacle_defs = [
		{"scene": SpikeScene, "action": "jump"},
		{"scene": BarScene, "action": "crouch"},
		{"scene": CeilingScene, "action": "crouch"},
		{"scene": LavaScene, "action": "jump"},
	]
	bonus_defs = [BonusSpikeScene, BonusBarScene, BonusCeilingScene, BonusLavaScene]
	Game.progress_changed.connect(_on_progress_changed)
	Game.hallucinations_changed.connect(_on_hallucinations_changed)
	Game.loose_hallucinations_changed.connect(_on_loose_hallucinations_changed)
	Game.game_over.connect(_on_game_over)
	Game.system_corrupted.connect(_on_system_corrupted)
	player.died.connect(_on_player_died)
	_incoherent_timer = Timer.new()
	_incoherent_timer.one_shot = true
	add_child(_incoherent_timer)
	_incoherent_timer.timeout.connect(_on_incoherent_timer_timeout)
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
	tip_overlay.visible = false
	new_high_score_banner.hide_banner()
	system_corrupted_banner.visible = false
	_system_corrupted = false
	if _corruption_flash_tween and _corruption_flash_tween.is_valid():
		_corruption_flash_tween.kill()
	system_corrupted_banner.modulate = Color(1, 1, 1, 1)
	pause_overlay.visible = false
	is_paused = false
	_on_progress_changed(0)
	_on_hallucinations_changed(0)
	_reset_loose_ui()
	while next_spawn_x < player.global_position.x + spawn_ahead:
		_spawn_tile()

func _process(delta: float) -> void:
	if not Game.is_playing or is_paused:
		return

	while next_spawn_x < player.global_position.x + spawn_ahead:
		_spawn_tile()
	_despawn_old()
	_check_announcements()

	score_timer += delta
	if score_timer >= 0.1:
		score_timer = 0.0
		Game.add_progress(1)

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

		if next_spawn_x > safe_runway and tiles_since_obstacle > 3 and rng.randf() < bonus_chance:
			tiles_since_obstacle = 0
			var bonus_scene: PackedScene = bonus_defs[rng.randi_range(0, bonus_defs.size() - 1)]
			var bonus: Node2D = bonus_scene.instantiate()
			bonus.position = Vector2(event_x, 0)
			add_child(bonus)
			segments.append(bonus)
			pending_events.append({"x": event_x, "action": "bonus"})
		elif next_spawn_x > safe_runway and tiles_since_obstacle > 3 and rng.randf() < obstacle_chance:
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
	# The bot never lies about bonus pickups -- only jump/crouch calls can be wrong.
	if correct_action == "bonus":
		narrator.say("bonus", 1.8)
		return
	# No mistakes below error_start_score; past that, the chance of a
	# misleading call ramps up with score, capping out at 50/50 by error_ramp_score.
	var error_chance: float = clamp(
		(float(Game.progress) - error_start_score) / (error_ramp_score - error_start_score),
		0.0, 0.5
	)
	var action := correct_action
	if rng.randf() < error_chance:
		action = "crouch" if correct_action == "jump" else "jump"
	narrator.say(action)

func _despawn_old() -> void:
	var threshold := player.global_position.x - despawn_behind
	for seg in segments.duplicate():
		if not is_instance_valid(seg):
			segments.erase(seg)
		elif seg.position.x + tile_width < threshold:
			if seg.is_in_group("bonus") and seg.has_method("is_collected") and not seg.is_collected():
				Game.add_loose_hallucination()
			seg.queue_free()
			segments.erase(seg)

func _on_progress_changed(new_value: int) -> void:
	score_label.text = "Progress: %d" % new_value

func _on_hallucinations_changed(new_value: int) -> void:
	hallucinations_label.text = "Hallucinations Caught: %d" % new_value
	high_score_label.text = "Best: %d" % Game.high_score
	if new_value > 0:
		_pop_label(hallucinations_label)

func _pop_label(lbl: Label) -> void:
	lbl.pivot_offset = lbl.size / 2.0
	var tween := create_tween()
	tween.tween_property(lbl, "scale", Vector2(1.3, 1.3), 0.08) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(lbl, "scale", Vector2.ONE, 0.14) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _on_player_died() -> void:
	pass

func _on_loose_hallucinations_changed(new_value: int) -> void:
	loose_label.text = "Missed Hallucinations: %d" % new_value
	if new_value >= 1:
		loose_label.visible = true
	if new_value >= 2:
		loose_label.add_theme_font_size_override("font_size", 26)
		_start_loose_flash()
	if new_value >= 3 and not _funky_mode_active:
		_enable_funky_mode()
	if new_value >= 4:
		player.set_ambient_shake(true)

func _start_loose_flash() -> void:
	if _loose_flash_tween and _loose_flash_tween.is_valid():
		return
	_loose_flash_tween = create_tween()
	_loose_flash_tween.set_loops()
	_loose_flash_tween.tween_property(loose_label, "modulate:a", 0.25, 0.3)
	_loose_flash_tween.tween_property(loose_label, "modulate:a", 1.0, 0.3)

func _enable_funky_mode() -> void:
	_funky_mode_active = true
	if crt_rect.material:
		crt_rect.material.set_shader_parameter("funky_strength", 1.0)
	_incoherent_timer.start(rng.randf_range(2.5, 4.5))

func _on_incoherent_timer_timeout() -> void:
	if Game.is_playing and _funky_mode_active:
		var phrase: String = INCOHERENT_PHRASES[rng.randi_range(0, INCOHERENT_PHRASES.size() - 1)]
		narrator.say_text(phrase, 2.4)
	_incoherent_timer.start(rng.randf_range(3.0, 6.0))

func _stop_funky_effects() -> void:
	_funky_mode_active = false
	_incoherent_timer.stop()
	if _loose_flash_tween and _loose_flash_tween.is_valid():
		_loose_flash_tween.kill()
	_loose_flash_tween = null
	loose_label.modulate = Color(1, 1, 1, 1)
	if crt_rect.material:
		crt_rect.material.set_shader_parameter("funky_strength", 0.0)
	player.set_ambient_shake(false)

func _on_system_corrupted() -> void:
	_system_corrupted = true
	player.die()

func _reset_loose_ui() -> void:
	_stop_funky_effects()
	loose_label.visible = false
	loose_label.add_theme_font_size_override("font_size", 20)
	loose_label.text = "Missed Hallucinations: 0"

func _on_game_over(
	final_progress: int, final_hallucinations: int, is_new_high_score: bool
) -> void:
	final_score_label.text = "Hallucinations Caught: %d   Best: %d" % [
		final_hallucinations, Game.high_score
	]
	final_progress_label.text = "Progress: %d" % final_progress
	game_over_panel.visible = true
	tip_overlay.visible = true
	_stop_funky_effects()
	if _system_corrupted:
		narrator.say_text("Sorry, I got nervous", 0.0)
		system_corrupted_banner.visible = true
		_corruption_flash_tween = create_tween()
		_corruption_flash_tween.set_loops()
		_corruption_flash_tween.tween_property(system_corrupted_banner, "modulate:a", 0.4, 0.35)
		_corruption_flash_tween.tween_property(system_corrupted_banner, "modulate:a", 1.0, 0.35)
		new_high_score_banner.hide_banner()
		return
	var line := "Wow you are becoming a PRO!" if is_new_high_score else "That was a good effort"
	narrator.say_text(line, 0.0)
	if is_new_high_score:
		new_high_score_banner.show_text("New High Score!")
	else:
		new_high_score_banner.hide_banner()

func _unhandled_input(event: InputEvent) -> void:
	if game_over_panel.visible and (event.is_action_pressed("restart") or event.is_action_pressed("ui_accept")):
		start_game()
		return
	if event.is_action_pressed("pause") and Game.is_playing and not game_over_panel.visible:
		_toggle_pause()

func _toggle_pause() -> void:
	is_paused = not is_paused
	pause_overlay.visible = is_paused
	player.set_paused(is_paused)
	if _incoherent_timer:
		_incoherent_timer.paused = is_paused

func _on_resume_button_pressed() -> void:
	_toggle_pause()

func _on_restart_button_pressed() -> void:
	start_game()
