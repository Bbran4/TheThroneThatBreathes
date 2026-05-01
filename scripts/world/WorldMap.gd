extends Control
class_name WorldMap

# WorldMap is a purely decorative overlay.
# It shows the player where they are in the world.
# Clicking a location node shows flavour text — it does not navigate.
#
# To set up:
# - Add MapLocationNode children under $Locations
# - Each MapLocationNode has a location_scene reference and flavour_text
# - Call set_current_location() whenever the player moves

signal map_closed

@onready var locations_root: Control = $Locations
@onready var flavour_panel: PanelContainer = $FlavourPanel
@onready var flavour_title: Label = $FlavourPanel/MarginContainer/VBoxContainer/TitleLabel
@onready var flavour_text: RichTextLabel = $FlavourPanel/MarginContainer/VBoxContainer/FlavourText
@onready var close_button: Button = $CloseButton

var current_location_scene: PackedScene = null
var location_nodes: Array[MapLocationNode] = []


func _ready() -> void:
	flavour_panel.visible = false

	close_button.pressed.connect(func():
		map_closed.emit()
		visible = false
	)

	_register_location_nodes()


func _register_location_nodes() -> void:
	location_nodes.clear()

	for child in locations_root.get_children():
		if not child is MapLocationNode:
			continue

		var node := child as MapLocationNode
		location_nodes.append(node)

		node.clicked.connect(func():
			_on_location_node_clicked(node)
		)


func set_current_location(scene: PackedScene) -> void:
	current_location_scene = scene
	_refresh_highlights()


func _refresh_highlights() -> void:
	for node in location_nodes:
		node.set_highlighted(node.location_scene == current_location_scene)


func _on_location_node_clicked(node: MapLocationNode) -> void:
	flavour_panel.visible = true
	flavour_title.text = node.location_name
	flavour_text.text = node.flavour_text

	# Briefly flash the clicked node.
	var tween := node.create_tween()
	tween.tween_property(node, "modulate", Color(1.5, 1.5, 0.5), 0.08)
	tween.tween_property(node, "modulate", Color.WHITE, 0.18)


func open() -> void:
	visible = true
	flavour_panel.visible = false
