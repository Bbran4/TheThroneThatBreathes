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

# Camera bounds.
# Set these per sideview scene in the Inspector.
# Example for your current wide scenes:
#   left  = 0
#   right = 1155 or 1521, depending on the scene width
@export var camera_limit_left: int = 0
@export var camera_limit_right: int = 11520
@export var camera_limit_top: int = -10000000
@export var camera_limit_bottom: int = 10000000
@export var camera_position_smoothing: bool = true
@export var camera_smoothing_speed: float = 6.0
@export var camera_offset: Vector2 = Vector2(0, -60)

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

var sideview_camera: Camera2D = null


func _ready() -> void:
	prompt_label.visible = false

	_set_mouse_ignore($CanvasLayer/UI)

	if player_spawn != null and player != null:
		player.global_position = player_spawn.global_position

	_setup_camera()

	if location_title_label != null:
		location_title_label.text = location_name

	if subtitle_label != null:
		subtitle_label.text = location_description


func setup(new_run_state: RunState) -> void:
	run_state = new_run_state
	_register_interactables()


func _setup_camera() -> void:
	if player == null:
		push_warning("SideViewLocation: cannot setup camera because Player is missing.")
		return

	sideview_camera = player.get_node_or_null("SideViewCamera") as Camera2D

	if sideview_camera == null:
		sideview_camera = Camera2D.new()
		sideview_camera.name = "SideViewCamera"
		player.add_child(sideview_camera)

	sideview_camera.position = camera_offset
	sideview_camera.enabled = true
	sideview_camera.make_current()

	sideview_camera.limit_left = camera_limit_left
	sideview_camera.limit_right = camera_limit_right
	sideview_camera.limit_top = camera_limit_top
	sideview_camera.limit_bottom = camera_limit_bottom

	sideview_camera.position_smoothing_enabled = camera_position_smoothing
	sideview_camera.position_smoothing_speed = camera_smoothing_speed

	# Keeps the camera from dragging outside the limits at the edges.
	sideview_camera.limit_smoothed = true


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

	if run_state != null:
		outcome.apply_to_run_state(run_state)

	if interactable.becomes_used_after_interaction:
		interactable.mark_used()
		if run_state != null:
			run_state.mark_interactable_used(interactable.interactable_id)

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
