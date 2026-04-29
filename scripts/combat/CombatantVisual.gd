extends Node2D
class_name CombatantVisual

signal death_animation_finished
signal action_animation_finished

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

@export var default_animation: String = "idle"
@export var hit_flash_duration: float = 0.10
@export var shake_distance: float = 8.0

var original_position: Vector2
var is_dying: bool = false
var is_playing_action: bool = false
var current_target_state: String = "normal"


func _ready() -> void:
	original_position = position

	if animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation(default_animation):
		animated_sprite.play(default_animation)


func play_idle() -> void:
	if is_dying:
		return

	is_playing_action = false

	if animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation(default_animation):
		animated_sprite.play(default_animation)


func play_attack(animation_name: String = "attack_1") -> void:
	if is_dying:
		return

	await _play_one_shot_animation(animation_name)
	play_idle()


func play_defend() -> void:
	if is_dying:
		return

	await _play_one_shot_animation("defend")
	play_idle()


func play_protect() -> void:
	if is_dying:
		return

	await _play_one_shot_animation("protect")
	play_idle()


func play_hit_reaction() -> void:
	if is_dying:
		return

	var previous_animation := animated_sprite.animation

	if animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation("hurt"):
		animated_sprite.play("hurt")

	position = original_position

	var tween := create_tween()
	tween.tween_property(animated_sprite, "modulate", Color(1, 0.4, 0.4), hit_flash_duration)
	tween.tween_property(self, "position", original_position + Vector2(shake_distance, 0), 0.05)
	tween.tween_property(self, "position", original_position - Vector2(shake_distance, 0), 0.05)
	tween.tween_property(self, "position", original_position, 0.05)
	tween.tween_property(animated_sprite, "modulate", _get_modulate_for_state(), hit_flash_duration)

	await tween.finished

	if not is_dying and not is_playing_action:
		if previous_animation != "":
			animated_sprite.play(previous_animation)
		else:
			play_idle()


func play_guard_reaction() -> void:
	if is_dying:
		return

	if animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation("defend"):
		animated_sprite.play("defend")

	var tween := create_tween()
	tween.tween_property(animated_sprite, "modulate", Color(0.5, 0.7, 1.0), 0.12)
	tween.tween_property(animated_sprite, "modulate", _get_modulate_for_state(), 0.12)

	await tween.finished

	if not is_dying and not is_playing_action:
		play_idle()


func play_death_reaction() -> void:
	if is_dying:
		return

	is_dying = true

	if animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation("dead"):
		animated_sprite.play("dead")
		await animated_sprite.animation_finished
	else:
		var tween := create_tween()
		tween.tween_property(animated_sprite, "modulate:a", 0.0, 0.45)
		await tween.finished

	death_animation_finished.emit()
	queue_free()


func set_target_state(state: String) -> void:
	current_target_state = state

	if is_dying:
		return

	animated_sprite.modulate = _get_modulate_for_state()


func _get_modulate_for_state() -> Color:
	match current_target_state:
		"normal":
			return Color.WHITE

		"valid":
			return Color(0.75, 1.0, 0.75)

		"invalid":
			return Color(0.45, 0.45, 0.45)

		"selected":
			return Color(1.0, 0.85, 0.35)

		"cleave":
			return Color(1.0, 0.55, 0.25)

	return Color.WHITE


func _play_one_shot_animation(animation_name: String) -> void:
	if animated_sprite.sprite_frames == null:
		return

	if not animated_sprite.sprite_frames.has_animation(animation_name):
		return

	is_playing_action = true
	animated_sprite.play(animation_name)

	await animated_sprite.animation_finished

	is_playing_action = false
	action_animation_finished.emit()
