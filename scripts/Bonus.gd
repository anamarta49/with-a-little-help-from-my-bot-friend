extends Area2D
## Camouflaged bonus pickup: looks exactly like a hazard but rewards points
## and plays a cute animation when the player touches it, instead of killing them.

@export var points: int = 100

var _collected: bool = false

func collect() -> void:
	if _collected:
		return
	_collected = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	Game.add_hallucination(points)
	_play_pickup_animation()

func _play_pickup_animation() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.6, 1.6), 0.15) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "rotation", TAU, 0.3)
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.tween_callback(queue_free)
