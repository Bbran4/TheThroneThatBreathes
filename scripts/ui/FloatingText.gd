extends Label
class_name FloatingText

# FloatingText is a temporary visual feedback label.
# It appears, rises upward, fades out, then removes itself.

@export var rise_distance: float = 40.0
@export var duration: float = 0.8


func play(text_value: String, start_position: Vector2) -> void:
	text = text_value
	global_position = start_position

	var end_position := start_position + Vector2(0, -rise_distance)

	var tween := create_tween()
	tween.set_parallel(true)

	tween.tween_property(self, "global_position", end_position, duration)
	tween.tween_property(self, "modulate:a", 0.0, duration)

	await tween.finished
	queue_free()
