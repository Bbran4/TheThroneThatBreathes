extends Area2D
class_name LocationInteractable

# LocationInteractable is placed directly in a SideViewLocation scene.
# It owns all its outcome data — no separate RunNodeData or RunChoiceData needed.
#
# If outcomes has 1 entry  → triggers directly on interact.
# If outcomes has 2+ entries → shows a choice panel for the player to pick.

signal interaction_triggered(interactable: LocationInteractable)
signal player_entered(interactable: LocationInteractable)
signal player_exited(interactable: LocationInteractable)

# Unique ID used to track whether this interactable has been used this run.
# Set this in the Inspector. e.g. "corpse_road_cart", "shrine_altar"
@export var interactable_id: String = ""

# Text shown above the interactable when player is nearby.
@export var prompt_text: String = "Press E to interact"

# Text shown if the player returns after already using this interactable.
@export var used_prompt_text: String = "Nothing left here."

# Whether interacting marks this as used and prevents future interaction.
@export var becomes_used_after_interaction: bool = true

# The outcomes. 
# 1 outcome = fires directly.
# 2+ outcomes = player is shown a choice panel.
@export var outcomes: Array[InteractableOutcome] = []

var is_used: bool = false
var player_inside: bool = false


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

	interaction_triggered.emit(self)


func get_prompt() -> String:
	if is_used:
		return used_prompt_text
	return prompt_text


func get_prompt_world_position() -> Vector2:
	return global_position + Vector2(0, -80)


func mark_used() -> void:
	if becomes_used_after_interaction:
		is_used = true


func _on_body_entered(body: Node) -> void:
	if body is LocationPlayer:
		player_inside = true
		player_entered.emit(self)


func _on_body_exited(body: Node) -> void:
	if body is LocationPlayer:
		player_inside = false
		player_exited.emit(self)
