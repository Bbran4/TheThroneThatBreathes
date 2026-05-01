extends Node2D
class_name SideViewLocation

# SideViewLocation is the core exploration scene.
# It manages the player, interactables, the result overlay,
# and signals upward when a navigation or combat transition is needed.
#
# This script does NOT know about RunTest or the broader run flow.
# It only signals what should happen next — the parent handles it.

signal location_combat_requested(combat_scene: PackedScene)
signal location_travel_requested(next_location: PackedScene)
signal location_exit_requested

@export var location_name: String = "Unknown"
@export_multiline var location_description: String = ""
@export var map_flavour_text: String = ""

# Scene refs
@export var interaction_result_view_scene: PackedScene

@onready var player: LocationPlayer = $Player
@onready var player_spawn: Marker2D = $PlayerSpawn
@onready var interactables_root: Node2D = $Interactables
@onready var location_title_label: Label = $CanvasLayer/UI/LocationTitleLabel
@onready var subtitle_label: RichTextLabel = $CanvasLayer/UI/SubtitleLabel
@onready var prompt_label: Label = $CanvasLayer/UI/PromptLabel

var run_state: RunState
var nearby_interactable: LocationInteractable = null
var active_result_view: Control = null
var pending_outcome: InteractableOutcome = null


func _ready() -> void:
	prompt_label.visible = false

	_set_mouse_ignore($CanvasLayer/UI)

	if player_spawn != null and player != null:
		player.global_position = player_spawn.global_position

	if location_title_label != null:
		location_title_label.text = location_name

	if subtitle_label != null:
		subtitle_label.text = location_description


func setup(new_run_state: RunState) -> void:
	run_state = new_run_state
	_register_interactables()


func _register_interactables() -> void:
	for child in interactables_root.get_children():
		if not child is LocationInteractable:
			continue

		var interactable := child as LocationInteractable

		if run_state != null:
			interactable.setup_used_state(
				run_state.has_used_interactable(interactable.interactable_id)
			)

		interactable.interaction_triggered.connect(_on_interaction_triggered)
		interactable.player_entered.connect(_on_player_entered_interactable)
		interactable.player_exited.connect(_on_player_exited_interactable)


func _process(_delta: float) -> void:
	if nearby_interactable != null and is_instance_valid(nearby_interactable):
		prompt_label.global_position = nearby_interactable.get_prompt_world_position()

	if Input.is_action_just_pressed("interact"):
		if nearby_interactable != null and not nearby_interactable.is_used:
			nearby_interactable.interact()


# --- Interactable events ---

func _on_player_entered_interactable(interactable: LocationInteractable) -> void:
	nearby_interactable = interactable
	prompt_label.visible = true
	prompt_label.text = interactable.get_prompt()


func _on_player_exited_interactable(interactable: LocationInteractable) -> void:
	if nearby_interactable == interactable:
		nearby_interactable = null
		prompt_label.visible = false


func _on_interaction_triggered(interactable: LocationInteractable) -> void:
	if interactable.outcomes.is_empty():
		return

	if interactable.outcomes.size() == 1:
		_trigger_outcome(interactable, interactable.outcomes[0])
	else:
		_show_choice_panel(interactable)


func _show_choice_panel(interactable: LocationInteractable) -> void:
	# Show the result view with multiple choice buttons.
	if interaction_result_view_scene == null:
		push_error("SideViewLocation: missing interaction_result_view_scene.")
		return

	_clear_result_view()

	active_result_view = interaction_result_view_scene.instantiate()
	$CanvasLayer.add_child(active_result_view)

	var result_view := active_result_view as InteractionResultView
	if result_view == null:
		return

	result_view.show_choices(interactable.outcomes, func(chosen: InteractableOutcome):
		_clear_result_view()
		_trigger_outcome(interactable, chosen)
	)


func _trigger_outcome(interactable: LocationInteractable, outcome: InteractableOutcome) -> void:
	pending_outcome = outcome

	# Apply run state changes immediately (heal, card, stat modifiers).
	if run_state != null:
		outcome.apply_to_run_state(run_state)

	# Mark the interactable used.
	if interactable.becomes_used_after_interaction:
		interactable.mark_used()
		if run_state != null:
			run_state.mark_interactable_used(interactable.interactable_id)

	# If there's result text or a reward, show the result view first.
	if outcome.result_text != "" or outcome.has_reward() or outcome.has_stat_changes():
		_show_result_view(outcome)
	else:
		_resolve_navigation(outcome)


func _show_result_view(outcome: InteractableOutcome) -> void:
	if interaction_result_view_scene == null:
		push_error("SideViewLocation: missing interaction_result_view_scene.")
		return

	_clear_result_view()

	active_result_view = interaction_result_view_scene.instantiate()
	$CanvasLayer.add_child(active_result_view)

	var result_view := active_result_view as InteractionResultView
	if result_view == null:
		return

	result_view.show_result(outcome, func():
		_clear_result_view()
		_resolve_navigation(outcome)
	)


func _resolve_navigation(outcome: InteractableOutcome) -> void:
	pending_outcome = null

	if outcome.combat_scene != null:
		location_combat_requested.emit(outcome.combat_scene)
		return

	if outcome.next_location != null:
		location_travel_requested.emit(outcome.next_location)
		return

	# No navigation — stay in this location.
	# Update nearby prompt in case used state changed.
	if nearby_interactable != null:
		prompt_label.text = nearby_interactable.get_prompt()


func _clear_result_view() -> void:
	if active_result_view != null and is_instance_valid(active_result_view):
		active_result_view.queue_free()
	active_result_view = null


func _set_mouse_ignore(node: Control) -> void:
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		if child is Control:
			_set_mouse_ignore(child)
