extends Area2D
class_name LocationInteractable

signal interaction_requested(interactable: LocationInteractable)
signal player_entered_interactable(interactable: LocationInteractable)
signal player_exited_interactable(interactable: LocationInteractable)

@export var interaction_name: String = "Interact"
@export var prompt_text: String = "Press E"
@export var linked_choice: RunChoiceData

var player_inside: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func can_interact() -> bool:
	return player_inside and linked_choice != null


func interact() -> void:
	if not can_interact():
		return

	interaction_requested.emit(self)


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
