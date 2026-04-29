extends Control
class_name LocationView

signal choice_selected(choice: RunChoiceData)
signal continue_requested
signal leave_location_requested

@onready var background: TextureRect = $Background
@onready var location_title_label: Label = $ContentPanel/MarginContainer/VBoxContainer/LocationTitleLabel
@onready var location_description_label: Label = $ContentPanel/MarginContainer/VBoxContainer/LocationDescriptionLabel
@onready var node_title_label: Label = $ContentPanel/MarginContainer/VBoxContainer/NodeTitleLabel
@onready var scene_text_label: RichTextLabel = $ContentPanel/MarginContainer/VBoxContainer/SceneTextLabel
@onready var choices_container: VBoxContainer = $ContentPanel/MarginContainer/VBoxContainer/ChoicesContainer

var current_location: LocationData
var current_node: RunNodeData


func show_location(location: LocationData, node_data: RunNodeData) -> void:
	current_location = location
	current_node = node_data

	visible = true

	if current_location != null:
		location_title_label.text = current_location.location_name
		location_description_label.text = current_location.description

		if current_location.background_art != null:
			background.texture = current_location.background_art
		else:
			background.texture = null
	else:
		location_title_label.text = ""
		location_description_label.text = ""
		background.texture = null

	_show_node(node_data)


func show_node(node_data: RunNodeData) -> void:
	current_node = node_data
	_show_node(node_data)


func show_result_text(title_text: String, result_text: String, button_text: String = "Continue") -> void:
	node_title_label.text = title_text
	scene_text_label.text = result_text

	_clear_choices()

	var continue_button := Button.new()
	continue_button.text = button_text
	continue_button.custom_minimum_size = Vector2(420, 42)
	continue_button.pressed.connect(func():
		continue_requested.emit()
	)

	choices_container.add_child(continue_button)


func show_location_complete() -> void:
	node_title_label.text = "The road waits."
	scene_text_label.text = "You leave this place behind."

	_clear_choices()

	var leave_button := Button.new()
	leave_button.text = "Return to the road"
	leave_button.custom_minimum_size = Vector2(420, 42)
	leave_button.pressed.connect(func():
		leave_location_requested.emit()
	)

	choices_container.add_child(leave_button)


func _show_node(node_data: RunNodeData) -> void:
	_clear_choices()

	if node_data == null:
		node_title_label.text = ""
		scene_text_label.text = "There is nothing here."

		var continue_button := Button.new()
		continue_button.text = "Return"
		continue_button.pressed.connect(func():
			leave_location_requested.emit()
		)
		choices_container.add_child(continue_button)
		return

	node_title_label.text = node_data.node_name
	scene_text_label.text = node_data.scene_text

	if node_data.choices.is_empty():
		var continue_button := Button.new()
		continue_button.text = "Continue"
		continue_button.custom_minimum_size = Vector2(420, 42)
		continue_button.pressed.connect(func():
			continue_requested.emit()
		)
		choices_container.add_child(continue_button)
		return

	for choice in node_data.choices:
		var button := Button.new()
		button.text = choice.choice_text
		button.custom_minimum_size = Vector2(420, 42)
		button.pressed.connect(func():
			choice_selected.emit(choice)
		)
		choices_container.add_child(button)


func _clear_choices() -> void:
	for child in choices_container.get_children():
		child.queue_free()
