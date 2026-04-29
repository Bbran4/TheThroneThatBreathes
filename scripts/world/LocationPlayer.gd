extends CharacterBody2D
class_name LocationPlayer

@export var move_speed: float = 180.0
@export var gravity: float = 1200.0
@export var jump_velocity: float = -360.0
@export var allow_jump: bool = false

@onready var visual: AnimatedSprite2D = $AnimatedSprite2D

var facing_direction: int = 1


func _physics_process(delta: float) -> void:
	var input_x := Input.get_axis("left", "right")

	velocity.x = input_x * move_speed

	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0.0

	if allow_jump and is_on_floor() and Input.is_action_just_pressed("ui_accept"):
		velocity.y = jump_velocity

	move_and_slide()

	_update_visual(input_x)


func _update_visual(input_x: float) -> void:
	if visual == null:
		return

	if input_x != 0:
		facing_direction = sign(input_x)
		visual.flip_h = facing_direction < 0

		if visual.sprite_frames != null and visual.sprite_frames.has_animation("run"):
			if visual.animation != "run":
				visual.play("run")
	else:
		if visual.sprite_frames != null and visual.sprite_frames.has_animation("idle"):
			if visual.animation != "idle":
				visual.play("idle")
