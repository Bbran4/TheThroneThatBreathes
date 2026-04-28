extends Button
class_name CardView

# CardView is the visual representation of one card.
#
# It does not resolve card effects.
# It only displays card data and notifies the UI when clicked.

signal card_selected(card: CardData)
signal card_hovered(card: CardData)
signal card_unhovered

@onready var name_label: Label = $MarginContainer/VBoxContainer/Header/NameLabel
@onready var art_texture: TextureRect = $MarginContainer/VBoxContainer/ArtTexture
@onready var description_label: Label = $MarginContainer/VBoxContainer/DescriptionLabel
@onready var dice_requirement_label: Label = $MarginContainer/VBoxContainer/Header/DiceRequirementLabel

var card_data: CardData

var hover_lift_amount = 180.0
var normal_position: Vector2
var normal_scale: Vector2 = Vector2.ONE
var hover_scale: Vector2 = Vector2(1.15, 1.15)
var hover_tween: Tween


func _ready() -> void:
	pressed.connect(_on_pressed)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

	custom_minimum_size = Vector2(180, 270)
	_create_card_styles()

	name_label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.55))
	description_label.add_theme_color_override("font_color", Color(0.86, 0.82, 0.72))
	dice_requirement_label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.55))


func setup(card: CardData, is_playable: bool) -> void:
	card_data = card

	name_label.text = card.card_name
	name_label.add_theme_font_size_override("font_size", 13)
	description_label.text = card.description
	description_label.visible = true
	description_label.custom_minimum_size = Vector2(130, 55)
	description_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.clip_text = true
	description_label.add_theme_font_size_override("font_size", 11)
	dice_requirement_label.text = _get_dice_requirement_icon_text(card)
	dice_requirement_label.add_theme_font_size_override("font_size", 13)
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.clip_text = true
	description_label.add_theme_font_size_override("font_size", 11)

	if card.card_art != null:
		art_texture.texture = card.card_art
	else:
		art_texture.texture = null

	disabled = not is_playable


func _on_pressed() -> void:
	if card_data == null:
		return

	card_selected.emit(card_data)


func _on_mouse_entered() -> void:
	if hover_tween != null:
		hover_tween.kill()

	normal_position = position
	normal_scale = scale
	z_index = 100

	hover_tween = create_tween()
	hover_tween.set_parallel(true)
	hover_tween.tween_property(self, "position:y", normal_position.y - hover_lift_amount, 0.10)
	hover_tween.tween_property(self, "scale", hover_scale, 0.10)

	if card_data != null:
		card_hovered.emit(card_data)


func _on_mouse_exited() -> void:
	if hover_tween != null:
		hover_tween.kill()

	z_index = 0

	hover_tween = create_tween()
	hover_tween.set_parallel(true)
	hover_tween.tween_property(self, "position:y", normal_position.y, 0.08)
	hover_tween.tween_property(self, "scale", normal_scale, 0.08)

	card_unhovered.emit()


func _create_card_styles() -> void:
	# Normal card border.
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0.10, 0.085, 0.075)
	normal_style.border_color = Color(0.72, 0.56, 0.28)
	normal_style.set_border_width_all(4)
	normal_style.set_corner_radius_all(10)

	normal_style.content_margin_left = 8
	normal_style.content_margin_right = 8
	normal_style.content_margin_top = 8
	normal_style.content_margin_bottom = 8

	# Adds subtle card depth.
	normal_style.shadow_color = Color(0, 0, 0, 0.65)
	normal_style.shadow_size = 8
	normal_style.shadow_offset = Vector2(3, 4)

	# Hovered / playable-feeling card border.
	var hover_style := normal_style.duplicate()
	hover_style.bg_color = Color(0.14, 0.11, 0.085)
	hover_style.border_color = Color(1.0, 0.82, 0.32)
	hover_style.set_border_width_all(5)
	hover_style.shadow_size = 14
	hover_style.shadow_offset = Vector2(4, 6)

	# Pressed card.
	var pressed_style := normal_style.duplicate()
	pressed_style.bg_color = Color(0.07, 0.055, 0.05)
	pressed_style.border_color = Color(0.95, 0.68, 0.25)
	pressed_style.set_border_width_all(5)

	# Disabled / unplayable card.
	var disabled_style := normal_style.duplicate()
	disabled_style.bg_color = Color(0.045, 0.045, 0.045)
	disabled_style.border_color = Color(0.22, 0.22, 0.22)
	disabled_style.shadow_size = 3

	add_theme_stylebox_override("normal", normal_style)
	add_theme_stylebox_override("hover", hover_style)
	add_theme_stylebox_override("pressed", pressed_style)
	add_theme_stylebox_override("disabled", disabled_style)

func _get_dice_requirement_icon_text(card: CardData) -> String:
	match card.dice_requirement_type:
		CardData.DiceRequirementType.ANY:
			return "🎲x" + str(card.dice_required)

		CardData.DiceRequirementType.MINIMUM_VALUE:
			return "🎲" + str(card.required_die_value) + "+"

		CardData.DiceRequirementType.MAXIMUM_VALUE:
			return "🎲≤" + str(card.required_die_value)

		CardData.DiceRequirementType.EXACT_VALUE:
			return "🎲" + str(card.required_die_value)

		CardData.DiceRequirementType.EVEN:
			return "🎲E"

		CardData.DiceRequirementType.ODD:
			return "🎲O"

	return "🎲?"
