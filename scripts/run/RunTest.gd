extends Node
class_name RunTest

@export var player_data: CombatantData
@export var run_nodes: Array[RunNodeData] = []

@export var combat_test_scene: PackedScene
@export var card_view_scene: PackedScene
@export var starting_location: LocationData
@export var route_locations: Array[LocationData] = []
@export var location_view_scene: PackedScene
@export var side_view_location_scene: PackedScene

var current_location: LocationData
var active_location_view: LocationView
var pending_choice: RunChoiceData
var active_side_view_location: SideViewLocation
var pending_location_choice: RunChoiceData
var run_state: RunState
var current_node_index: int = -1

var route_ui: Control
var route_title: Label
var route_status: Label
var node_button_container: VBoxContainer
var reward_card_container: HBoxContainer
var reward_card_tweens: Dictionary = {}
var active_combat_root: Node
var current_combat_node: RunNodeData = null

const REWARD_CARD_WIDTH := 180.0
const REWARD_CARD_HEIGHT := 270.0
const REWARD_CARD_HOVER_LIFT := 34.0
const REWARD_CARD_HOVER_SCALE := Vector2(1.10, 1.10)
const REWARD_CARD_SPACING := 28
const REWARD_SELECT_BUTTON_HEIGHT := 38.0

func _ready() -> void:
	_build_route_ui()

	run_state = RunState.new()
	add_child(run_state)
	run_state.setup_from_player_data(player_data)

	if starting_location != null:
		current_location = starting_location
		route_ui.visible = false
		_enter_location(starting_location)
		return

	_show_location_route_screen()

func _show_location_route_screen() -> void:
	_cleanup_active_combat()

	route_ui.visible = true
	route_title.text = "The Road Ahead"

	_clear_children(node_button_container)
	_clear_children(reward_card_container)
	reward_card_container.visible = false
	node_button_container.visible = true
	
	route_status.text = "HP: %s / %s\nChoose your path." % [
		run_state.current_hp,
		run_state.max_hp
	]

	if run_state.is_dead():
		var dead_label := Label.new()
		dead_label.text = "You died on the road."
		node_button_container.add_child(dead_label)
		return

	if route_locations.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No locations assigned."
		node_button_container.add_child(empty_label)
		return

	for location in route_locations:
		var button := Button.new()
		button.text = location.location_name
		button.pressed.connect(func():
			_enter_location(location)
		)
		node_button_container.add_child(button)

func _enter_location(location: LocationData) -> void:
	if location == null:
		return

	if location.entry_node == null:
		push_error("Location has no entry node: " + location.location_name)
		return

	current_location = location

	if route_ui != null:
		route_ui.visible = false

	_open_side_view_location(location, location.entry_node)

func _open_side_view_location(location: LocationData, node_data: RunNodeData) -> void:
	_cleanup_side_view_location()

	var scene_to_load: PackedScene = null

	if location != null and location.side_view_scene != null:
		scene_to_load = location.side_view_scene
	else:
		scene_to_load = side_view_location_scene

	if scene_to_load == null:
		push_error("No side view scene assigned.")
		return

	active_side_view_location = scene_to_load.instantiate() as SideViewLocation
	add_child(active_side_view_location)

	active_side_view_location.choice_selected.connect(_on_side_view_choice_selected)
	active_side_view_location.location_exit_requested.connect(_on_side_view_location_exit_requested)
	active_side_view_location.choice_result_finished_with_next_node.connect(_on_side_view_choice_result_next_node)
	active_side_view_location.choice_result_finished_without_next_node.connect(_on_side_view_choice_result_no_next_node)

	active_side_view_location.setup(location, node_data, run_state)

func _on_side_view_choice_selected(choice: RunChoiceData) -> void:
	if choice == null:
		return

	run_state.apply_choice(choice)

	var interactable := active_side_view_location.nearby_interactable
	active_side_view_location.show_choice_result(interactable, choice)

func _on_side_view_choice_result_next_node(node_data: RunNodeData) -> void:
	_start_side_view_node(node_data)

func _on_side_view_choice_result_no_next_node() -> void:
	# Stay in the same location.
	# The used interactable has already been marked.
	pass

func _on_side_view_location_exit_requested() -> void:
	if pending_location_choice != null:
		_resolve_side_view_choice_continuation(pending_location_choice)
	else:
		_complete_current_node()

func _resolve_side_view_choice_continuation(choice: RunChoiceData) -> void:
	if choice == null:
		_complete_current_node()
		return

	pending_location_choice = null

	if choice.next_node != null:
		_start_side_view_node(choice.next_node)
	else:
		_complete_current_node()

func _start_side_view_node(node_data: RunNodeData) -> void:
	if node_data == null:
		_complete_current_node()
		return

	match node_data.node_type:
		RunNodeData.RunNodeType.STORY:
			if active_side_view_location != null:
				active_side_view_location.setup(current_location, node_data, run_state)

		RunNodeData.RunNodeType.CHOICE:
			if active_side_view_location != null:
				active_side_view_location.setup(current_location, node_data, run_state)

		RunNodeData.RunNodeType.COMBAT:
			_start_combat_from_side_view(node_data)

		RunNodeData.RunNodeType.ELITE:
			_start_combat_from_side_view(node_data)

		RunNodeData.RunNodeType.BOSS:
			_start_combat_from_side_view(node_data)

func _start_combat_from_side_view(node_data: RunNodeData) -> void:
	_cleanup_side_view_location()
	_start_combat_node(node_data)

func _open_location_view(location: LocationData, node_data: RunNodeData) -> void:
	_cleanup_location_view()

	if location_view_scene == null:
		push_error("RunTest missing location_view_scene.")
		return

	active_location_view = location_view_scene.instantiate() as LocationView
	add_child(active_location_view)

	active_location_view.choice_selected.connect(_on_location_choice_selected)
	active_location_view.continue_requested.connect(_on_location_continue_requested)
	active_location_view.leave_location_requested.connect(_on_location_leave_requested)

	active_location_view.show_location(location, node_data)

func _cleanup_location_view() -> void:
	if active_location_view != null and is_instance_valid(active_location_view):
		active_location_view.queue_free()

	active_location_view = null
	pending_choice = null

func _cleanup_side_view_location() -> void:
	if active_side_view_location != null and is_instance_valid(active_side_view_location):
		active_side_view_location.queue_free()

	active_side_view_location = null
	pending_location_choice = null

func _on_location_choice_selected(choice: RunChoiceData) -> void:
	if choice == null:
		return

	pending_choice = choice

	run_state.apply_choice(choice)

	if choice.result_text != "":
		active_location_view.show_result_text(choice.choice_text, choice.result_text, "Continue")
	else:
		_resolve_choice_continuation(choice)

func _on_location_continue_requested() -> void:
	if pending_choice != null:
		_resolve_choice_continuation(pending_choice)
		return

	active_location_view.show_location_complete()

func _resolve_choice_continuation(choice: RunChoiceData) -> void:
	if choice == null:
		active_location_view.show_location_complete()
		return

	pending_choice = null

	if choice.next_node != null:
		_start_location_node(choice.next_node)
	else:
		active_location_view.show_location_complete()

func _start_location_node(node_data: RunNodeData) -> void:
	if node_data == null:
		active_location_view.show_location_complete()
		return

	match node_data.node_type:
		RunNodeData.RunNodeType.STORY:
			active_location_view.show_node(node_data)

		RunNodeData.RunNodeType.CHOICE:
			active_location_view.show_node(node_data)

		RunNodeData.RunNodeType.COMBAT:
			_start_combat_from_location(node_data)

		RunNodeData.RunNodeType.ELITE:
			_start_combat_from_location(node_data)

		RunNodeData.RunNodeType.BOSS:
			_start_combat_from_location(node_data)

func _on_location_leave_requested() -> void:
	_complete_current_node()

func _start_combat_from_location(node_data: RunNodeData) -> void:
	_cleanup_location_view()
	_start_combat_node(node_data)

func _build_route_ui() -> void:
	route_ui = Control.new()
	route_ui.name = "RouteUI"
	route_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(route_ui)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 360)
	panel.position = Vector2(60, 80)
	route_ui.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	margin.add_child(vbox)

	route_title = Label.new()
	route_title.text = "The Road Ahead"
	route_title.add_theme_font_size_override("font_size", 28)
	vbox.add_child(route_title)

	route_status = Label.new()
	route_status.text = ""
	vbox.add_child(route_status)

	reward_card_container = HBoxContainer.new()
	reward_card_container.name = "RewardCardContainer"
	reward_card_container.alignment = BoxContainer.ALIGNMENT_CENTER
	reward_card_container.add_theme_constant_override("separation", REWARD_CARD_SPACING)
	reward_card_container.visible = false
	vbox.add_child(reward_card_container)

	node_button_container = VBoxContainer.new()
	vbox.add_child(node_button_container)


func _show_route_screen() -> void:
	_cleanup_active_combat()
	_cleanup_location_view()
	_cleanup_side_view_location()

	route_ui.visible = true
	route_title.text = "The Road Ahead"

	route_status.text = "HP: %s / %s\nCompleted Locations: %s / %s" % [
		run_state.current_hp,
		run_state.max_hp,
		run_state.completed_nodes,
		route_locations.size()
	]

	_clear_children(node_button_container)
	_clear_children(reward_card_container)
	reward_card_container.visible = false
	node_button_container.visible = true
	
	if run_state.is_dead():
		var dead_label := Label.new()
		dead_label.text = "You died on the road."
		node_button_container.add_child(dead_label)
		return

	if route_locations.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No locations assigned."
		node_button_container.add_child(empty_label)
		return

	if run_state.completed_nodes >= route_locations.size():
		var complete_label := Label.new()
		complete_label.text = "Run complete. The road continues..."
		node_button_container.add_child(complete_label)
		return

	for i in route_locations.size():
		var location := route_locations[i]
		var button := Button.new()

		var prefix := "✓ " if i < run_state.completed_nodes else ""
		button.text = "%s%s" % [
			prefix,
			location.location_name
		]

		button.disabled = i != run_state.completed_nodes

		button.pressed.connect(func():
			_enter_location(location)
		)

		node_button_container.add_child(button)


func _start_node(index: int) -> void:
	if index < 0 or index >= run_nodes.size():
		return

	current_node_index = index
	var node_data := run_nodes[index]

	match node_data.node_type:
		RunNodeData.RunNodeType.COMBAT:
			_start_combat_node(node_data)

		RunNodeData.RunNodeType.ELITE:
			_start_combat_node(node_data)

		RunNodeData.RunNodeType.BOSS:
			_start_combat_node(node_data)

		RunNodeData.RunNodeType.STORY:
			_start_event_node(node_data)

		RunNodeData.RunNodeType.CHOICE:
			_start_event_node(node_data)


func _start_event_node(node_data: RunNodeData) -> void:
	print("Starting run node: ", node_data.node_name)
	print("Node type: ", node_data.node_type)
	print("Choices count: ", node_data.choices.size())

	_clear_children(node_button_container)
	_clear_children(reward_card_container)
	reward_card_container.visible = false
	node_button_container.visible = true
	
	route_ui.visible = true
	route_title.text = node_data.node_name
	route_status.text = node_data.scene_text

	if node_data.choices.is_empty():
		var continue_button := Button.new()
		continue_button.text = "Continue"
		continue_button.pressed.connect(func():
			_complete_current_node()
		)
		node_button_container.add_child(continue_button)
		return

	for choice in node_data.choices:
		var button := Button.new()
		button.text = choice.choice_text
		button.pressed.connect(func():
			_apply_run_choice(choice)
		)
		node_button_container.add_child(button)

func _apply_run_choice(choice: RunChoiceData) -> void:
	_clear_children(node_button_container)

	print("Applying run choice: ", choice.choice_text)

	if choice.card_reward != null:
		print("Choice has reward card: ", choice.card_reward.card_name)
	else:
		print("Choice has no reward card.")

	print("Choice guard modifier: ", choice.guard_modifier)

	run_state.apply_choice(choice)

	if choice.result_text != "":
		route_status.text = choice.result_text

	var continue_button := Button.new()
	continue_button.text = "Continue"

	continue_button.pressed.connect(func():
		if choice.next_node != null:
			print("Going to next linked node: ", choice.next_node.node_name)
			_start_dynamic_node(choice.next_node)
		else:
			print("No linked node. Completing current route node.")
			_complete_current_node()
	)

	node_button_container.add_child(continue_button)

func _start_dynamic_node(node_data: RunNodeData) -> void:
	match node_data.node_type:
		RunNodeData.RunNodeType.STORY:
			_start_event_node(node_data)

		RunNodeData.RunNodeType.CHOICE:
			_start_event_node(node_data)

		RunNodeData.RunNodeType.COMBAT:
			_start_combat_node(node_data)

		RunNodeData.RunNodeType.ELITE:
			_start_combat_node(node_data)

		RunNodeData.RunNodeType.BOSS:
			_start_combat_node(node_data)

func _start_combat_node(node_data: RunNodeData) -> void:
	if combat_test_scene == null:
		push_error("RunTest missing combat_test_scene.")
		return

	if node_data.enemy_team_data.is_empty():
		push_error("Combat node has no enemy team: " + node_data.node_name)
		return

	current_combat_node = node_data

	route_ui.visible = false
	_cleanup_active_combat()

	active_combat_root = combat_test_scene.instantiate()

	if not active_combat_root.has_method("setup_from_run"):
		push_error("CombatTest scene is missing setup_from_run().")
		return

	var player_team_for_combat: Array[CombatantData] = []
	player_team_for_combat.append(player_data)

	active_combat_root.setup_from_run(player_team_for_combat, node_data.enemy_team_data)
	active_combat_root.apply_run_state(run_state)

	if active_combat_root.has_signal("combat_finished"):
		active_combat_root.combat_finished.connect(_on_run_combat_finished)
	else:
		push_error("CombatTest scene is missing combat_finished signal.")

	add_child(active_combat_root)

func _get_current_reward_node() -> RunNodeData:
	if current_combat_node != null:
		return current_combat_node

	if current_node_index >= 0 and current_node_index < run_nodes.size():
		return run_nodes[current_node_index]

	return null

func _on_run_combat_finished(player_won: bool, surviving_player: PlayerCombatant) -> void:
	if player_won and surviving_player != null:
		run_state.save_from_player_combatant(surviving_player)

		await get_tree().create_timer(0.8).timeout
		_show_reward_after_combat()
	else:
		run_state.current_hp = 0

		await get_tree().create_timer(0.8).timeout
		_show_route_screen()

func _create_reward_card_option(card: CardData, index: int) -> VBoxContainer:
	var option := VBoxContainer.new()
	option.name = "RewardOption_%s" % index
	option.custom_minimum_size = Vector2(REWARD_CARD_WIDTH, REWARD_CARD_HEIGHT + REWARD_SELECT_BUTTON_HEIGHT + 12.0)
	option.alignment = BoxContainer.ALIGNMENT_CENTER

	var card_view: CardView = card_view_scene.instantiate()
	option.add_child(card_view)

	card_view.custom_minimum_size = Vector2(REWARD_CARD_WIDTH, REWARD_CARD_HEIGHT)
	card_view.size = Vector2(REWARD_CARD_WIDTH, REWARD_CARD_HEIGHT)
	card_view.pivot_offset = Vector2(REWARD_CARD_WIDTH * 0.5, REWARD_CARD_HEIGHT * 0.5)
	card_view.focus_mode = Control.FOCUS_NONE
	card_view.mouse_filter = Control.MOUSE_FILTER_STOP
	card_view.set_meta("reward_rest_position", Vector2.ZERO)
	card_view.set_meta("reward_rest_z", index)

	card_view.modulate.a = 0.0
	card_view.scale = Vector2(0.72, 0.72)
	card_view.rotation_degrees = -5.0 + index * 5.0
	card_view.z_index = index

	card_view.mouse_entered.connect(func():
		_on_run_reward_card_mouse_entered(card_view)
	)

	card_view.mouse_exited.connect(func():
		_on_run_reward_card_mouse_exited(card_view)
	)

	# Important:
	# CardView.setup() depends on @onready label references.
	# Defer it until CardView has entered the scene tree.
	card_view.call_deferred("setup", card, true)

	var select_button := Button.new()
	select_button.text = "Select"
	select_button.custom_minimum_size = Vector2(REWARD_CARD_WIDTH, REWARD_SELECT_BUTTON_HEIGHT)
	select_button.mouse_filter = Control.MOUSE_FILTER_STOP
	select_button.pressed.connect(func():
		run_state.add_card(card)
		_complete_current_node()
	)
	option.add_child(select_button)

	var reveal_tween := card_view.create_tween()
	reveal_tween.set_parallel(true)
	reveal_tween.tween_property(card_view, "modulate:a", 1.0, 0.14).set_delay(index * 0.08)
	reveal_tween.tween_property(card_view, "scale", Vector2.ONE, 0.32).set_delay(index * 0.08).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	reveal_tween.tween_property(card_view, "rotation_degrees", 0.0, 0.32).set_delay(index * 0.08).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	return option

func _on_run_reward_card_mouse_entered(card_view: CardView) -> void:
	if card_view == null or not is_instance_valid(card_view):
		return

	if reward_card_tweens.has(card_view):
		var old_tween: Tween = reward_card_tweens[card_view]
		if old_tween != null:
			old_tween.kill()

	card_view.z_index = 100

	var tween := card_view.create_tween()
	reward_card_tweens[card_view] = tween
	tween.set_parallel(true)
	tween.tween_property(card_view, "position:y", -REWARD_CARD_HOVER_LIFT, 0.14).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(card_view, "scale", REWARD_CARD_HOVER_SCALE, 0.14).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(card_view, "rotation_degrees", 0.0, 0.14).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


func _on_run_reward_card_mouse_exited(card_view: CardView) -> void:
	if card_view == null or not is_instance_valid(card_view):
		return

	if reward_card_tweens.has(card_view):
		var old_tween: Tween = reward_card_tweens[card_view]
		if old_tween != null:
			old_tween.kill()

	var rest_z: int = card_view.get_meta("reward_rest_z", 0)
	card_view.z_index = rest_z

	var tween := card_view.create_tween()
	reward_card_tweens[card_view] = tween
	tween.set_parallel(true)
	tween.tween_property(card_view, "position:y", 0.0, 0.12).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(card_view, "scale", Vector2.ONE, 0.12).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(card_view, "rotation_degrees", 0.0, 0.12).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)

func _show_reward_after_combat() -> void:
	_cleanup_active_combat()
	_cleanup_location_view()
	_cleanup_side_view_location()

	route_ui.visible = true
	route_ui.move_to_front()
	route_title.text = "Spoils of the Road"

	_clear_children(node_button_container)
	_clear_children(reward_card_container)
	reward_card_container.visible = false
	node_button_container.visible = true

	var node_data: RunNodeData = _get_current_reward_node()

	if node_data == null:
		route_status.text = "HP: %s / %s\nNo reward data found." % [
			run_state.current_hp,
			run_state.max_hp
		]

		var continue_button := Button.new()
		continue_button.text = "Continue"
		continue_button.pressed.connect(func():
			_complete_current_node()
		)
		node_button_container.add_child(continue_button)
		return

	route_status.text = "HP: %s / %s\nChoose a reward." % [
		run_state.current_hp,
		run_state.max_hp
	]

	if node_data.reward_cards.is_empty():
		var continue_button := Button.new()
		continue_button.text = "Continue"
		continue_button.pressed.connect(func():
			_complete_current_node()
		)
		node_button_container.add_child(continue_button)
		return

	if card_view_scene == null:
		push_error("RunTest missing card_view_scene. Assign res://scenes/ui/CardView.tscn.")
		return

	node_button_container.visible = false
	reward_card_container.visible = true

	for i in node_data.reward_cards.size():
		var card: CardData = node_data.reward_cards[i]
		var option := _create_reward_card_option(card, i)
		reward_card_container.add_child(option)

	var skip_button := Button.new()
	skip_button.text = "Skip"
	skip_button.custom_minimum_size = Vector2(180, REWARD_SELECT_BUTTON_HEIGHT)
	skip_button.mouse_filter = Control.MOUSE_FILTER_STOP
	skip_button.pressed.connect(func():
		_complete_current_node()
	)

	var skip_wrapper := VBoxContainer.new()
	skip_wrapper.custom_minimum_size = Vector2(180, REWARD_CARD_HEIGHT + REWARD_SELECT_BUTTON_HEIGHT + 12.0)
	skip_wrapper.alignment = BoxContainer.ALIGNMENT_END
	skip_wrapper.add_child(skip_button)
	reward_card_container.add_child(skip_wrapper)

func _complete_current_node() -> void:
	current_combat_node = null
	run_state.completed_nodes += 1
	_show_route_screen()

func _cleanup_active_combat() -> void:
	if active_combat_root != null and is_instance_valid(active_combat_root):
		active_combat_root.queue_free()

	active_combat_root = null


func _clear_children(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()


func _get_node_type_text(node_type: RunNodeData.RunNodeType) -> String:
	match node_type:
		RunNodeData.RunNodeType.COMBAT:
			return "Combat"
		RunNodeData.RunNodeType.STORY:
			return "Story"
		RunNodeData.RunNodeType.CHOICE:
			return "Choice"
		RunNodeData.RunNodeType.ELITE:
			return "Elite"
		RunNodeData.RunNodeType.BOSS:
			return "Boss"

	return "Unknown"
