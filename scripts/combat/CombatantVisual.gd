extends Sprite2D
class_name CombatantVisual

signal death_animation_finished

@export var idle_texture: Texture2D
@export var hit_flash_duration: float = 0.12
@export var shake_distance: float = 8.0
@export var death_duration: float = 0.45
@export var death_sink_distance: float = 26.0

var original_position: Vector2
var is_dying: bool = false


func _ready() -> void:
	original_position = position

	if idle_texture != null:
		texture = idle_texture


func play_hit_reaction() -> void:
	if is_dying:
		return

	position = original_position

	var tween := create_tween()

	tween.tween_property(self, "modulate", Color(1, 0.4, 0.4), hit_flash_duration)
	tween.tween_property(self, "position", original_position + Vector2(shake_distance, 0), 0.05)
	tween.tween_property(self, "position", original_position - Vector2(shake_distance, 0), 0.05)
	tween.tween_property(self, "position", original_position, 0.05)
	tween.tween_property(self, "modulate", Color.WHITE, hit_flash_duration)


func play_guard_reaction() -> void:
	if is_dying:
		return

	var tween := create_tween()

	tween.tween_property(self, "modulate", Color(0.5, 0.7, 1.0), 0.12)
	tween.tween_property(self, "modulate", Color.WHITE, 0.12)


func play_death_reaction() -> void:
	if is_dying:
		return

	is_dying = true

	var tween := create_tween()
	tween.set_parallel(true)

	tween.tween_property(self, "modulate:a", 0.0, death_duration)
	tween.tween_property(self, "position", original_position + Vector2(0, death_sink_distance), death_duration)
	tween.tween_property(self, "scale", scale * 0.92, death_duration)

	await tween.finished

	death_animation_finished.emit()
	queue_free()
