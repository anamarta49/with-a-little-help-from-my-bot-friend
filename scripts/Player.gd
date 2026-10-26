extends CharacterBody2D
## Auto-running player: jumps and crouches to avoid obstacles/holes.

signal died

@export var run_speed: float = 320.0
@export var jump_velocity: float = -620.0
@export var fall_death_y: float = 500.0
## Instant downward speed applied when crouch is pressed mid-air (fast-fall slam).
@export var fast_fall_speed: float = 1700.0

## Speed ramp: every SPEED_STAGE_INTERVAL progress points the run speed steps
## up, with each step smaller than the last as it approaches SPEED_CAP --
## keeps things exciting without ever becoming impossible to react to.
const SPEED_STAGE_INTERVAL := 300
const SPEED_CAP := 900.0
## Lower = increments shrink faster (approaches the cap sooner).
const SPEED_DECAY := 0.82
const SPEED_RAMP_DURATION := 1.2

const STAND_VISUAL_HEIGHT := 64.0
const CROUCH_VISUAL_HEIGHT := 32.0
const BOB_SPEED := 14.0
const BOB_AMOUNT := 3.0

@onready var stand_collision: CollisionShape2D = $StandCollision
@onready var crouch_collision: CollisionShape2D = $CrouchCollision
@onready var hitbox_stand: CollisionShape2D = $Hitbox/HitboxStand
@onready var hitbox_crouch: CollisionShape2D = $Hitbox/HitboxCrouch
@onready var visual: ColorRect = $Visual
@onready var camera: Camera2D = $Camera2D
@onready var dust_trail: GPUParticles2D = $DustTrail
@onready var land_burst: GPUParticles2D = $LandBurst

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var is_crouching: bool = false
var is_dead: bool = false
var is_paused: bool = false
var _was_on_floor: bool = true
var _bob_time: float = 0.0
var _squash_tween: Tween
var _shake_tween: Tween
var _speed_tween: Tween
var _camera_base_offset: Vector2
var current_run_speed: float = 0.0
var _speed_stage: int = 0
var _ambient_shake: bool = false

const AMBIENT_SHAKE_STRENGTH := 3.0

func _ready() -> void:
	_set_crouch(false)
	_camera_base_offset = camera.offset
	current_run_speed = run_speed
	Game.progress_changed.connect(_on_progress_changed)

func reset() -> void:
	is_dead = false
	is_paused = false
	velocity = Vector2.ZERO
	global_position = Vector2(100, 0)
	_was_on_floor = true
	_bob_time = 0.0
	visual.scale = Vector2.ONE
	_set_crouch(false)
	set_physics_process(true)
	_speed_stage = 0
	current_run_speed = run_speed
	if _speed_tween and _speed_tween.is_valid():
		_speed_tween.kill()
	set_ambient_shake(false)

func _physics_process(delta: float) -> void:
	if is_dead or is_paused:
		return

	velocity.y += gravity * delta

	if is_on_floor() and Input.is_action_just_pressed("jump") and not is_crouching:
		velocity.y = jump_velocity
		_play_jump_stretch()

	if not is_on_floor() and Input.is_action_just_pressed("crouch") and velocity.y < fast_fall_speed:
		velocity.y = fast_fall_speed
		_play_fast_fall_stretch()

	var wants_crouch := Input.is_action_pressed("crouch") and is_on_floor()
	if wants_crouch != is_crouching:
		_set_crouch(wants_crouch)

	velocity.x = current_run_speed
	move_and_slide()

	var speed_ratio: float = (current_run_speed - run_speed) / (SPEED_CAP - run_speed)
	Music.set_speed_ratio(speed_ratio)

	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor:
		_play_landing()
	_was_on_floor = on_floor

	_update_run_bob(delta, on_floor)
	dust_trail.emitting = on_floor and not is_crouching
	_update_ambient_shake()

	if global_position.y > fall_death_y:
		die()

func _on_progress_changed(new_value: int) -> void:
	var target_stage: int = new_value / SPEED_STAGE_INTERVAL
	if target_stage == _speed_stage:
		return
	_speed_stage = target_stage
	# Exponentially approach SPEED_CAP -- each stage's increment is smaller
	# than the last, so the ramp never becomes unplayably fast.
	var target_speed: float = SPEED_CAP - (SPEED_CAP - run_speed) * pow(SPEED_DECAY, target_stage)
	if _speed_tween and _speed_tween.is_valid():
		_speed_tween.kill()
	_speed_tween = create_tween()
	_speed_tween.tween_property(self, "current_run_speed", target_speed, SPEED_RAMP_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _update_run_bob(delta: float, on_floor: bool) -> void:
	var h := CROUCH_VISUAL_HEIGHT if is_crouching else STAND_VISUAL_HEIGHT
	var bob := 0.0
	if on_floor:
		_bob_time += delta * BOB_SPEED
		bob = abs(sin(_bob_time)) * -BOB_AMOUNT
	else:
		_bob_time = 0.0
	visual.position.y = -h + bob

func _set_crouch(crouching: bool) -> void:
	is_crouching = crouching
	stand_collision.disabled = crouching
	crouch_collision.disabled = not crouching
	hitbox_stand.disabled = crouching
	hitbox_crouch.disabled = not crouching
	if visual:
		var h := CROUCH_VISUAL_HEIGHT if crouching else STAND_VISUAL_HEIGHT
		visual.size.y = h
		visual.position.y = -h
		visual.pivot_offset = Vector2(20, h)

func _play_jump_stretch() -> void:
	if _squash_tween and _squash_tween.is_valid():
		_squash_tween.kill()
	visual.pivot_offset = Vector2(20, visual.size.y)
	_squash_tween = create_tween()
	_squash_tween.tween_property(visual, "scale", Vector2(0.8, 1.25), 0.08) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_squash_tween.tween_property(visual, "scale", Vector2.ONE, 0.18) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _play_fast_fall_stretch() -> void:
	if _squash_tween and _squash_tween.is_valid():
		_squash_tween.kill()
	visual.pivot_offset = Vector2(20, 0)
	_squash_tween = create_tween()
	_squash_tween.tween_property(visual, "scale", Vector2(0.7, 1.35), 0.1) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _play_landing() -> void:
	land_burst.restart()
	land_burst.emitting = true
	_shake_camera(2.5, 0.12)
	if _squash_tween and _squash_tween.is_valid():
		_squash_tween.kill()
	visual.pivot_offset = Vector2(20, visual.size.y)
	_squash_tween = create_tween()
	_squash_tween.tween_property(visual, "scale", Vector2(1.25, 0.75), 0.07) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_squash_tween.tween_property(visual, "scale", Vector2.ONE, 0.15) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func set_ambient_shake(active: bool) -> void:
	_ambient_shake = active
	if not active and not (_shake_tween and _shake_tween.is_valid() and _shake_tween.is_running()):
		camera.offset = _camera_base_offset

func set_paused(value: bool) -> void:
	is_paused = value

func _update_ambient_shake() -> void:
	if not _ambient_shake:
		return
	# Let a one-off landing/death shake finish uninterrupted before layering in jitter.
	if _shake_tween and _shake_tween.is_valid() and _shake_tween.is_running():
		return
	camera.offset = _camera_base_offset + Vector2(
		randf_range(-AMBIENT_SHAKE_STRENGTH, AMBIENT_SHAKE_STRENGTH),
		randf_range(-AMBIENT_SHAKE_STRENGTH, AMBIENT_SHAKE_STRENGTH)
	)

func _shake_camera(strength: float, duration: float) -> void:
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
	_shake_tween = create_tween()
	var steps := 6
	for i in steps:
		var jitter := Vector2(
			randf_range(-strength, strength), randf_range(-strength, strength)
		)
		_shake_tween.tween_property(
			camera, "offset", _camera_base_offset + jitter, duration / steps
		)
	_shake_tween.tween_property(camera, "offset", _camera_base_offset, duration / steps)

func die() -> void:
	if is_dead:
		return
	is_dead = true
	velocity = Vector2.ZERO
	set_physics_process(false)
	dust_trail.emitting = false
	_shake_camera(8.0, 0.3)
	died.emit()
	Game.end_run()

func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("deadly"):
		die()
	elif area.is_in_group("bonus") and area.has_method("collect"):
		area.collect()

