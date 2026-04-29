extends Node
class_name RunTest

@export var player_data: CombatantData
@export var run_nodes: Array[RunNodeData] = []

@export var combat_test_scene: PackedScene

@export var starting_location: LocationData
@export var route_locations: Array[LocationData] = []
@export var location_view_scene: PackedScene

var current_location: LocationData
var active_location_view: LocationView
var pending_choice: RunChoiceData

var run_state: RunState

var current_node_index: int = -1

var route_ui: Control
var route_title: Label
var route_status: Label
var node_button_container: VBoxContainer

var active_combat_root: Node


func _ready() -> void:
	_build_route_ui()

	run_state = RunState.new()
	add_child(run_state)
	run_state.setup_from_player_data(player_data)

	if starting_location != null:
		current_location = starting_location

	_show_location_route_screen()

func _show_location_route_screen() -> void:
	_cleanup_active_combat()

	route_ui.visible = true
	route_title.text = "The Road Ahead"

	_clear_children(node_button_container)

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
	route_ui.visible = false

	_open_location_view(location, location.entry_node)

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
	if active_location_view != null:
		active_location_view.visible = false

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

	node_button_container = VBoxContainer.new()
	vbox.add_child(node_button_container)


func _show_route_screen() -> void:
	_cleanup_active_combat()
	_cleanup_location_view()

	route_ui.visible = true
	route_title.text = "The Road Ahead"

	route_status.text = "HP: %s / %s\nCompleted Locations: %s / %s" % [
		run_state.current_hp,
		run_state.max_hp,
		run_state.completed_nodes,
		route_locations.size()
	]

	_clear_children(node_button_container)

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

func _on_run_combat_finished(player_won: bool, surviving_player: PlayerCombatant) -> void:
	if player_won and surviving_player != null:
		run_state.save_from_player_combatant(surviving_player)

		await get_tree().create_timer(0.8).timeout
		_show_reward_after_combat()
	else:
		run_state.current_hp = 0

		await get_tree().create_timer(0.8).timeout
		_show_route_screen()

func _show_reward_after_combat() -> void:
	_cleanup_active_combat()

	route_ui.visible = true
	route_title.text = "Spoils of the Road"

	_clear_children(node_button_container)

	var node_data := run_nodes[current_node_index]

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

	for card in node_data.reward_cards:
		var button := Button.new()
		button.text = "+ " + card.card_name
		button.pressed.connect(func():
			run_state.add_card(card)
			_complete_current_node()
		)
		node_button_container.add_child(button)

	var skip_button := Button.new()
	skip_button.text = "Skip"
	skip_button.pressed.connect(func():
		_complete_current_node()
	)
	node_button_container.add_child(skip_button)

func _complete_current_node() -> void:
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
