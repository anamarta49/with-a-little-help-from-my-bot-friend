extends CharacterBody2D
## Auto-running player: jumps and crouches to avoid obstacles/holes.

signal died

@export var run_speed: float = 320.0
@export var jump_velocity: float = -620.0
@export var fall_death_y: float = 500.0

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
var _was_on_floor: bool = true
var _bob_time: float = 0.0
var _squash_tween: Tween
var _shake_tween: Tween
var _camera_base_offset: Vector2

func _ready() -> void:
	_set_crouch(false)
	_camera_base_offset = camera.offset

func reset() -> void:
	is_dead = false
	velocity = Vector2.ZERO
	global_position = Vector2(100, 0)
	_was_on_floor = true
	_bob_time = 0.0
	visual.scale = Vector2.ONE
	_set_crouch(false)
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	velocity.y += gravity * delta

	if is_on_floor() and Input.is_action_just_pressed("jump") and not is_crouching:
		velocity.y = jump_velocity
		_play_jump_stretch()

	var wants_crouch := Input.is_action_pressed("crouch") and is_on_floor()
	if wants_crouch != is_crouching:
		_set_crouch(wants_crouch)

	velocity.x = run_speed
	move_and_slide()

	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor:
		_play_landing()
	_was_on_floor = on_floor

	_update_run_bob(delta, on_floor)
	dust_trail.emitting = on_floor and not is_crouching

	if global_position.y > fall_death_y:
		die()

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

