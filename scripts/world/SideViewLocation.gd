extends Node2D
class_name SideViewLocation

signal choice_selected(choice: RunChoiceData)
signal location_exit_requested
signal choice_result_finished_with_next_node(node_data: RunNodeData)
signal choice_result_finished_without_next_node

@export var interactable_scene: PackedScene

@onready var player: LocationPlayer = $Player
@onready var player_spawn: Marker2D = $PlayerSpawn
@onready var interactables_root: Node2D = $Interactables
@onready var location_title_label: Label = $CanvasLayer/UI/LocationTitleLabel
@onready var subtitle_label: RichTextLabel = $CanvasLayer/UI/SubtitleLabel
@onready var prompt_label: Label = $CanvasLayer/UI/PromptLabel

@export var interaction_result_view_scene: PackedScene

var run_state: RunState
var current_location: LocationData
var current_node: RunNodeData
var nearby_interactable: LocationInteractable
var active_result_view: InteractionResultView
var current_result_choice: RunChoiceData
var current_result_interactable: LocationInteractable



func _ready() -> void:
	prompt_label.visible = false

	if location_title_label != null:
		location_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if subtitle_label != null:
		subtitle_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if prompt_label != null:
		prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if has_node("CanvasLayer/UI"):
		$CanvasLayer/UI.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if player_spawn != null and player != null:
		player.global_position = player_spawn.global_position


func setup(location: LocationData, node_data: RunNodeData, new_run_state: RunState) -> void:
	current_location = location
	current_node = node_data
	run_state = new_run_state

	if location_title_label != null:
		if current_location != null:
			location_title_label.text = current_location.location_name
		else:
			location_title_label.text = ""

	if subtitle_label != null:
		if current_node != null:
			subtitle_label.text = current_node.scene_text
		elif current_location != null:
			subtitle_label.text = current_location.description
		else:
			subtitle_label.text = ""

	_setup_manual_interactables()

func set_location_title(title_text: String) -> void:
	if location_title_label != null:
		location_title_label.text = title_text


func set_subtitle(text_value: String) -> void:
	if subtitle_label != null:
		subtitle_label.text = text_value

func _setup_manual_interactables() -> void:
	for child in interactables_root.get_children():
		if child is LocationInteractable:
			var interactable := child as LocationInteractable

			if run_state != null:
				interactable.setup_used_state(run_state.has_used_interactable(interactable.interactable_id))

			if not interactable.interaction_requested.is_connected(_on_interactable_requested):
				interactable.interaction_requested.connect(_on_interactable_requested)

			if not interactable.player_entered_interactable.is_connected(_on_player_entered_interactable):
				interactable.player_entered_interactable.connect(_on_player_entered_interactable)

			if not interactable.player_exited_interactable.is_connected(_on_player_exited_interactable):
				interactable.player_exited_interactable.connect(_on_player_exited_interactable)

func _on_player_entered_interactable(interactable: LocationInteractable) -> void:
	nearby_interactable = interactable
	_show_prompt_for_interactable(interactable)


func _on_player_exited_interactable(interactable: LocationInteractable) -> void:
	if nearby_interactable == interactable:
		nearby_interactable = null
		_hide_prompt()

func _show_prompt_for_interactable(interactable: LocationInteractable) -> void:
	if prompt_label == null:
		return

	prompt_label.visible = true
	prompt_label.text = interactable.get_current_prompt_text()
	prompt_label.global_position = interactable.get_prompt_position()


func _hide_prompt() -> void:
	if prompt_label == null:
		return

	prompt_label.visible = false



func _process(_delta: float) -> void:
	if nearby_interactable != null:
		if is_instance_valid(nearby_interactable):
			prompt_label.global_position = nearby_interactable.get_prompt_position()

	if Input.is_action_just_pressed("interact"):
		if nearby_interactable != null:
			nearby_interactable.interact()


func show_result_text(title_text: String, result_text: String) -> void:
	if subtitle_label != null:
		subtitle_label.text = "[b]%s[/b]\n%s\n\nPress E to continue." % [
			title_text,
			result_text
		]

	_clear_interactables()

	var continue_choice := RunChoiceData.new()
	continue_choice.choice_text = "Continue"

	var continue_interactable := _create_placeholder_interactable(
		"Continue",
		Vector2(900, 360),
		continue_choice
	)

	continue_interactable.interaction_requested.connect(func(_interactable: LocationInteractable):
		location_exit_requested.emit()
	)


func _spawn_interactables_for_node(node_data: RunNodeData) -> void:
	if node_data == null:
		return

	if node_data.choices.is_empty():
		var exit_choice := RunChoiceData.new()
		exit_choice.choice_text = "Continue"

		var exit_interactable := _create_placeholder_interactable(
			"Continue",
			Vector2(900, 560),
			exit_choice
		)

		exit_interactable.interaction_requested.connect(func(_interactable: LocationInteractable):
			location_exit_requested.emit()
		)

		return

	var start_x := 260.0
	var spacing_x := 280.0
	var y := 560.0

	for i in node_data.choices.size():
		var choice: RunChoiceData = node_data.choices[i]
		var interactable_position := Vector2(start_x + spacing_x * i, y)

		var interactable := _create_placeholder_interactable(
			choice.choice_text,
			interactable_position,
			choice
		)

		interactable.interaction_requested.connect(_on_interactable_requested)

func _create_placeholder_interactable(label_text: String, local_position: Vector2, choice: RunChoiceData) -> LocationInteractable:
	var interactable: LocationInteractable

	if interactable_scene != null:
		interactable = interactable_scene.instantiate() as LocationInteractable
	else:
		interactable = LocationInteractable.new()

		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(120, 120)
		shape.shape = rect
		interactable.add_child(shape)

		var marker := ColorRect.new()
		marker.color = Color(0.8, 0.7, 0.25, 0.45)
		marker.size = Vector2(120, 120)
		marker.position = Vector2(-60, -60)
		interactable.add_child(marker)

		var label := Label.new()
		label.text = label_text
		label.position = Vector2(-70, -95)
		label.size = Vector2(160, 40)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		interactable.add_child(label)

	interactable.name = label_text.replace(" ", "_") + "_Interactable"
	interactable.position = local_position
	interactable.interaction_name = label_text
	interactable.prompt_text = "Press E: " + label_text
	interactable.linked_choice = choice

	interactables_root.add_child(interactable)

	return interactable


func _on_interactable_requested(interactable: LocationInteractable) -> void:
	if interactable == null:
		return

	if interactable.is_used:
		_show_used_interactable_result(interactable)
		return

	if interactable.linked_choice == null:
		return

	choice_selected.emit(interactable.linked_choice)

func show_choice_result(interactable: LocationInteractable, choice: RunChoiceData) -> void:
	current_result_choice = choice
	current_result_interactable = interactable

	var reward_card: CardData = null
	if choice != null:
		reward_card = choice.card_reward

	_show_result_overlay(
		choice.choice_text,
		choice.result_text,
		reward_card
	)

func _show_used_interactable_result(interactable: LocationInteractable) -> void:
	current_result_choice = null
	current_result_interactable = null

	_show_result_overlay(
		interactable.interaction_name,
		interactable.used_result_text,
		null
	)

func _show_result_overlay(title_text: String, result_text: String, reward_card: CardData) -> void:
	if interaction_result_view_scene == null:
		push_error("SideViewLocation missing interaction_result_view_scene.")
		return

	set_subtitle("")

	if active_result_view != null and is_instance_valid(active_result_view):
		active_result_view.queue_free()

	active_result_view = interaction_result_view_scene.instantiate() as InteractionResultView
	$CanvasLayer.add_child(active_result_view)

	active_result_view.show_result(title_text, result_text, reward_card)

	active_result_view.continue_pressed.connect(func():
		_on_result_continue_pressed()
	)

func _on_result_continue_pressed() -> void:
	if active_result_view != null and is_instance_valid(active_result_view):
		active_result_view.queue_free()

	active_result_view = null

	if current_node != null:
		set_subtitle(current_node.scene_text)

	if current_result_interactable != null:
		if current_result_interactable.becomes_used_after_interaction:
			current_result_interactable.is_used = true

			if run_state != null:
				run_state.mark_interactable_used(current_result_interactable.interactable_id)

	current_result_interactable = null

	if current_result_choice != null:
		var choice := current_result_choice
		current_result_choice = null

		if choice.next_node != null:
			choice_result_finished_with_next_node.emit(choice.next_node)
			return

	choice_result_finished_without_next_node.emit()

func _update_nearby_interactable() -> void:
	nearby_interactable = null

	var best_distance := INF

	for child in interactables_root.get_children():
		if child is LocationInteractable:
			var interactable := child as LocationInteractable

			if not interactable.player_inside:
				continue

			var distance := player.global_position.distance_to(interactable.global_position)

			if distance < best_distance:
				best_distance = distance
				nearby_interactable = interactable

	if nearby_interactable != null:
		prompt_label.visible = true
		prompt_label.text = nearby_interactable.prompt_text
	else:
		prompt_label.visible = false


func _clear_interactables() -> void:
	nearby_interactable = null

	if prompt_label != null:
		prompt_label.visible = false

	for child in interactables_root.get_children():
		child.queue_free()
