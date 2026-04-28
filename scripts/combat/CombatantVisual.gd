extends Node2D
class_name CombatantVisual

signal death_animation_finished

@export var idle_texture: Texture2D
@export var hit_flash_duration: float = 0.12
@export var shake_distance: float = 8.0
@export var death_duration: float = 0.45
@export var death_sink_distance: float = 26.0

var sprite: Sprite2D
var original_position: Vector2
var is_dying: bool = false


func _ready() -> void:
	original_position = position

	sprite = Sprite2D.new()
	sprite.name = "Sprite"
	sprite.centered = true
	add_child(sprite)

	if idle_texture != null:
		sprite.texture = idle_texture


func play_hit_reaction() -> void:
	if is_dying:
		return

	position = original_position

	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(1, 0.4, 0.4), hit_flash_duration)
	tween.tween_property(self, "position", original_position + Vector2(shake_distance, 0), 0.05)
	tween.tween_property(self, "position", original_position - Vector2(shake_distance, 0), 0.05)
	tween.tween_property(self, "position", original_position, 0.05)
	tween.tween_property(sprite, "modulate", Color.WHITE, hit_flash_duration)


func play_guard_reaction() -> void:
	if is_dying:
		return

	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(0.5, 0.7, 1.0), 0.12)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.12)


func set_targeted(is_targeted: bool) -> void:
	if is_dying or sprite == null:
		return

	sprite.modulate = Color(1.0, 0.85, 0.35) if is_targeted else Color.WHITE

func set_target_state(state: String) -> void:
	if is_dying or sprite == null:
		return

	match state:
		"normal":
			sprite.modulate = Color.WHITE

		"valid":
			sprite.modulate = Color(0.75, 1.0, 0.75)

		"invalid":
			sprite.modulate = Color(0.45, 0.45, 0.45)

		"selected":
			sprite.modulate = Color(1.0, 0.85, 0.35)

		"cleave":
			sprite.modulate = Color(1.0, 0.55, 0.25)

func play_death_reaction() -> void:
	if is_dying:
		return

	is_dying = true

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "modulate:a", 0.0, death_duration)
	tween.tween_property(self, "position", original_position + Vector2(0, death_sink_distance), death_duration)
	tween.tween_property(self, "scale", scale * 0.92, death_duration)

	await tween.finished

	death_animation_finished.emit()
	queue_free()
