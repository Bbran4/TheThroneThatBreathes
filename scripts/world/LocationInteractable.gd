extends Area2D
class_name LocationInteractable

signal interaction_requested(interactable: LocationInteractable)
signal player_entered_interactable(interactable: LocationInteractable)
signal player_exited_interactable(interactable: LocationInteractable)

@export var interactable_id: String = ""

@export var interaction_name: String = "Interact"
@export var prompt_text: String = "Press E"

@export var linked_choice: RunChoiceData

@export var becomes_used_after_interaction: bool = true
@export var used_prompt_text: String = "Press E: Inspect"
@export_multiline var used_result_text: String = "There is nothing else here."

var player_inside: bool = false
var is_used: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func setup_used_state(was_used: bool) -> void:
	is_used = was_used


func can_interact() -> bool:
	return player_inside


func interact() -> void:
	if not can_interact():
		return

	interaction_requested.emit(self)


func get_current_prompt_text() -> String:
	if is_used:
		return used_prompt_text

	return prompt_text


func get_prompt_position() -> Vector2:
	return global_position + Vector2(0, -80)


func _on_body_entered(body: Node) -> void:
	if body is LocationPlayer:
		player_inside = true
		player_entered_interactable.emit(self)


func _on_body_exited(body: Node) -> void:
	if body is LocationPlayer:
		player_inside = false
		player_exited_interactable.emit(self)
