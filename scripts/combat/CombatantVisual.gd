extends Sprite2D
class_name CombatantVisual

# CombatantVisual handles the on-screen representation of a combatant.
#
# It does not contain combat logic.
# It only reacts visually to combat events.

@export var idle_texture: Texture2D
@export var hit_flash_duration: float = 0.12
@export var shake_distance: float = 8.0

var original_position: Vector2


func _ready() -> void:
	original_position = position

	if idle_texture != null:
		texture = idle_texture


func play_hit_reaction() -> void:
	# Small shake + flash when damaged.
	position = original_position

	var tween := create_tween()

	tween.tween_property(self, "modulate", Color(1, 0.4, 0.4), hit_flash_duration)
	tween.tween_property(self, "position", original_position + Vector2(shake_distance, 0), 0.05)
	tween.tween_property(self, "position", original_position - Vector2(shake_distance, 0), 0.05)
	tween.tween_property(self, "position", original_position, 0.05)
	tween.tween_property(self, "modulate", Color.WHITE, hit_flash_duration)


func play_guard_reaction() -> void:
	# Small glow when guard is gained.
	var tween := create_tween()

	tween.tween_property(self, "modulate", Color(0.5, 0.7, 1.0), 0.12)
	tween.tween_property(self, "modulate", Color.WHITE, 0.12)
