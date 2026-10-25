extends CharacterBody2D
## Auto-running player: jumps and crouches to avoid obstacles/holes.

signal died

@export var run_speed: float = 320.0
@export var jump_velocity: float = -620.0
@export var fall_death_y: float = 500.0

const STAND_VISUAL_HEIGHT := 64.0
const CROUCH_VISUAL_HEIGHT := 32.0

@onready var stand_collision: CollisionShape2D = $StandCollision
@onready var crouch_collision: CollisionShape2D = $CrouchCollision
@onready var hitbox_stand: CollisionShape2D = $Hitbox/HitboxStand
@onready var hitbox_crouch: CollisionShape2D = $Hitbox/HitboxCrouch
@onready var visual: ColorRect = $Visual

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var is_crouching: bool = false
var is_dead: bool = false

func _ready() -> void:
	_set_crouch(false)

func reset() -> void:
	is_dead = false
	velocity = Vector2.ZERO
	global_position = Vector2(100, 0)
	_set_crouch(false)
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	velocity.y += gravity * delta

	if is_on_floor() and Input.is_action_just_pressed("jump") and not is_crouching:
		velocity.y = jump_velocity

	var wants_crouch := Input.is_action_pressed("crouch") and is_on_floor()
	if wants_crouch != is_crouching:
		_set_crouch(wants_crouch)

	velocity.x = run_speed
	move_and_slide()

	if global_position.y > fall_death_y:
		die()

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

func die() -> void:
	if is_dead:
		return
	is_dead = true
	velocity = Vector2.ZERO
	set_physics_process(false)
	died.emit()
	Game.end_run()

func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("deadly"):
		die()
	elif area.is_in_group("bonus") and area.has_method("collect"):
		area.collect()
