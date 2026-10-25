extends Area2D
## Camouflaged bonus pickup: looks exactly like a hazard but rewards points
## and plays a cute animation when the player touches it, instead of killing them.

const SparkleScene := preload("res://scenes/Sparkle.tscn")

@export var points: int = 100

var _collected: bool = false

func is_collected() -> bool:
	return _collected

func collect() -> void:
	if _collected:
		return
	_collected = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	Game.add_hallucination(points)
	_spawn_sparkles()
	_play_pickup_animation()

func _spawn_sparkles() -> void:
	var sparkle: GPUParticles2D = SparkleScene.instantiate()
	get_parent().add_child(sparkle)
	sparkle.global_position = global_position
	sparkle.emitting = true
	sparkle.restart()
	get_tree().create_timer(sparkle.lifetime + 0.1).timeout.connect(sparkle.queue_free)

func _play_pickup_animation() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.6, 1.6), 0.15) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "rotation", TAU, 0.3)
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.tween_callback(queue_free)
