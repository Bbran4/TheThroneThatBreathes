extends Control
class_name MapLocationNode

# A single clickable point on the WorldMap.
# Place these as children of WorldMap/Locations.
# Position them in the Inspector to match your map art.

signal clicked

@export var location_name: String = "Unknown"
@export_multiline var flavour_text: String = ""

# The PackedScene this node represents.
# Used by WorldMap to know which node to highlight as current.
@export var location_scene: PackedScene = null

# Visual customisation.
@export var normal_color: Color = Color(0.7, 0.6, 0.4)
@export var highlight_color: Color = Color(1.0, 0.85, 0.3)
@export var current_scale: Vector2 = Vector2(1.3, 1.3)

@onready var icon: TextureRect = $Icon
@onready var name_label: Label = $NameLabel
@onready var click_area: Button = $ClickArea

var _is_highlighted: bool = false


func _ready() -> void:
	click_area.pressed.connect(func():
		clicked.emit()
	)

	modulate = normal_color
	scale = Vector2.ONE

	if name_label != null:
		name_label.text = location_name


func set_highlighted(is_current: bool) -> void:
	_is_highlighted = is_current

	var tween := create_tween()
	tween.set_parallel(true)

	if is_current:
		tween.tween_property(self, "modulate", highlight_color, 0.22)
		tween.tween_property(self, "scale", current_scale, 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	else:
		tween.tween_property(self, "modulate", normal_color, 0.18)
		tween.tween_property(self, "scale", Vector2.ONE, 0.18)
