extends Control
class_name InteractionResultView

signal continue_pressed

const CARD_VIEW_SCENE: PackedScene = preload("res://scenes/ui/CardView.tscn")

@onready var title_label: Label = $Panel/MarginContainer/HBoxContainer/VBoxContainer/TitleLabel
@onready var result_text_label: RichTextLabel = $Panel/MarginContainer/HBoxContainer/VBoxContainer/ResultTextLabel
@onready var reward_card_panel: PanelContainer = $Panel/MarginContainer/HBoxContainer/VBoxContainer/RewardCardPanel
@onready var reward_card_label: Label = $Panel/MarginContainer/HBoxContainer/VBoxContainer/RewardCardPanel/RewardCardLabel
@onready var continue_button: Button = $Panel/MarginContainer/HBoxContainer/VBoxContainer/ContinueButton

var reward_card_holder: Control = null
var reward_card_visual: CardView = null
var reward_card_glint: ColorRect = null
var reward_card_reveal_overlay: ColorRect = null
var reward_card_rest_position: Vector2 = Vector2.ZERO
var reward_card_hover_tween: Tween = null
var reward_card_follow_mouse: bool = false

const REWARD_CARD_SIZE := Vector2(180, 270)
const REWARD_CARD_PANEL_SIZE := Vector2(260, 340)
const REWARD_CARD_HOVER_LIFT := 24.0
const REWARD_CARD_HOVER_SCALE := Vector2(1.10, 1.10)
const REWARD_CARD_MOUSE_TILT := 8.0
const REWARD_CARD_MOUSE_OFFSET := 10.0
const REWARD_CARD_REVEAL_TIME := 0.55


func _ready() -> void:
	continue_button.pressed.connect(func():
		continue_pressed.emit()
	)

	if reward_card_label != null:
		reward_card_label.visible = false


func _process(_delta: float) -> void:
	if not reward_card_follow_mouse:
		return

	if reward_card_visual == null or not is_instance_valid(reward_card_visual):
		return

	var local_mouse := reward_card_visual.get_local_mouse_position()
	var half_size := REWARD_CARD_SIZE * 0.5
	var normalized := Vector2(
		clampf((local_mouse.x - half_size.x) / half_size.x, -1.0, 1.0),
		clampf((local_mouse.y - half_size.y) / half_size.y, -1.0, 1.0)
	)

	reward_card_visual.rotation_degrees = normalized.x * REWARD_CARD_MOUSE_TILT
	reward_card_visual.position = reward_card_rest_position + Vector2(
		normalized.x * REWARD_CARD_MOUSE_OFFSET,
		-REWARD_CARD_HOVER_LIFT + normalized.y * REWARD_CARD_MOUSE_OFFSET * 0.45
	)

func show_result(title_text: String, result_text: String, reward_card: CardData = null) -> void:
	visible = true

	title_label.text = title_text
	result_text_label.text = result_text

	if reward_card != null:
		reward_card_panel.visible = true
		_show_reward_card_visual(reward_card)
	else:
		reward_card_panel.visible = false
		_clear_reward_card_visual()

func _show_reward_card_visual(card: CardData) -> void:
	_clear_reward_card_visual()

	if reward_card_label != null:
		reward_card_label.visible = false
		reward_card_label.text = ""

	reward_card_panel.custom_minimum_size = REWARD_CARD_PANEL_SIZE
	reward_card_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	reward_card_holder = Control.new()
	reward_card_holder.name = "RewardCardHolder"
	reward_card_holder.custom_minimum_size = REWARD_CARD_PANEL_SIZE
	reward_card_holder.size = REWARD_CARD_PANEL_SIZE
	reward_card_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reward_card_panel.add_child(reward_card_holder)

	reward_card_visual = CARD_VIEW_SCENE.instantiate() as CardView
	reward_card_holder.add_child(reward_card_visual)

	reward_card_visual.setup(card, false)
	reward_card_visual.disabled = true
	reward_card_visual.mouse_filter = Control.MOUSE_FILTER_STOP
	reward_card_visual.custom_minimum_size = REWARD_CARD_SIZE
	reward_card_visual.size = REWARD_CARD_SIZE

	reward_card_rest_position = (REWARD_CARD_PANEL_SIZE - REWARD_CARD_SIZE) * 0.5
	reward_card_visual.position = reward_card_rest_position + Vector2(0, 34)
	reward_card_visual.pivot_offset = REWARD_CARD_SIZE * 0.5
	reward_card_visual.scale = Vector2(0.28, 0.28)
	reward_card_visual.rotation_degrees = -10.0
	reward_card_visual.modulate.a = 0.0

	_create_reward_card_reveal_fx()

	var reveal_tween := reward_card_visual.create_tween()
	reveal_tween.set_parallel(true)
	reveal_tween.tween_property(reward_card_visual, "modulate:a", 1.0, 0.16).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	reveal_tween.tween_property(reward_card_visual, "scale", Vector2(1.13, 1.13), REWARD_CARD_REVEAL_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	reveal_tween.tween_property(reward_card_visual, "position", reward_card_rest_position, REWARD_CARD_REVEAL_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	reveal_tween.tween_property(reward_card_visual, "rotation_degrees", 0.0, REWARD_CARD_REVEAL_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	reveal_tween.chain().tween_property(reward_card_visual, "scale", Vector2.ONE, 0.12).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)

	if reward_card_reveal_overlay != null and is_instance_valid(reward_card_reveal_overlay):
		var overlay_tween := reward_card_reveal_overlay.create_tween()
		overlay_tween.tween_property(reward_card_reveal_overlay, "modulate:a", 0.0, 0.35).set_delay(0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	_play_reward_card_glint_sweep(0.16)

	reward_card_visual.mouse_entered.connect(func():
		_on_reward_card_mouse_entered()
	)

	reward_card_visual.mouse_exited.connect(func():
		_on_reward_card_mouse_exited()
	)

func _create_reward_card_reveal_fx() -> void:
	if reward_card_visual == null or not is_instance_valid(reward_card_visual):
		return

	reward_card_visual.clip_contents = true

	reward_card_glint = ColorRect.new()
	reward_card_glint.name = "RewardCardGlint"
	reward_card_glint.color = Color(1.0, 0.92, 0.58, 1.0)
	reward_card_glint.size = Vector2(30, 360)
	reward_card_glint.position = Vector2(-70, -45)
	reward_card_glint.rotation_degrees = -20.0
	reward_card_glint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reward_card_glint.modulate.a = 0.0
	reward_card_visual.add_child(reward_card_glint)
	reward_card_glint.z_index = 50

	reward_card_reveal_overlay = ColorRect.new()
	reward_card_reveal_overlay.name = "RewardCardRevealOverlay"
	reward_card_reveal_overlay.color = Color(1.0, 0.86, 0.42, 1.0)
	reward_card_reveal_overlay.size = REWARD_CARD_SIZE
	reward_card_reveal_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reward_card_reveal_overlay.modulate.a = 0.16
	reward_card_visual.add_child(reward_card_reveal_overlay)
	reward_card_reveal_overlay.z_index = 49

func _play_reward_card_glint_sweep(delay: float = 0.0) -> void:
	if reward_card_glint == null or not is_instance_valid(reward_card_glint):
		return

	reward_card_glint.position = Vector2(-70, -45)
	reward_card_glint.rotation_degrees = -20.0
	reward_card_glint.modulate.a = 0.0

	var glint_tween := reward_card_glint.create_tween()
	glint_tween.set_parallel(true)
	glint_tween.tween_property(reward_card_glint, "position:x", REWARD_CARD_SIZE.x + 45.0, 0.42).set_delay(delay).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	glint_tween.tween_property(reward_card_glint, "modulate:a", 0.22, 0.12).set_delay(delay)
	glint_tween.chain().tween_property(reward_card_glint, "modulate:a", 0.0, 0.12)

func _create_reward_card_visual(card: CardData) -> Control:
	var card_root := PanelContainer.new()
	card_root.name = "RewardCardVisual"
	card_root.custom_minimum_size = REWARD_CARD_SIZE
	card_root.size = REWARD_CARD_SIZE
	card_root.clip_contents = true
	card_root.mouse_filter = Control.MOUSE_FILTER_STOP

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.065, 0.055, 0.98)
	style.border_color = Color(1.0, 0.78, 0.34, 1.0)
	style.set_border_width_all(4)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	style.shadow_size = 18
	style.shadow_offset = Vector2(0, 8)
	card_root.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	card_root.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.name = "Content"
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(vbox)

	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.text = card.card_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", 22)
	vbox.add_child(name_label)

	var divider_top := HSeparator.new()
	vbox.add_child(divider_top)

	var art_frame := PanelContainer.new()
	art_frame.name = "ArtFrame"
	art_frame.custom_minimum_size = Vector2(180, 102)
	art_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(art_frame)

	var art_style := StyleBoxFlat.new()
	art_style.bg_color = Color(0.18, 0.12, 0.11, 1.0)
	art_style.border_color = Color(0.75, 0.46, 0.20, 1.0)
	art_style.set_border_width_all(2)
	art_style.corner_radius_top_left = 9
	art_style.corner_radius_top_right = 9
	art_style.corner_radius_bottom_left = 9
	art_style.corner_radius_bottom_right = 9
	art_frame.add_theme_stylebox_override("panel", art_style)

	var art_label := Label.new()
	art_label.text = _get_reward_card_icon_text(card)
	art_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	art_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	art_label.add_theme_font_size_override("font_size", 42)
	art_frame.add_child(art_label)

	var divider_bottom := HSeparator.new()
	vbox.add_child(divider_bottom)

	var description_label := RichTextLabel.new()
	description_label.name = "DescriptionLabel"
	description_label.bbcode_enabled = true
	description_label.fit_content = false
	description_label.scroll_active = false
	description_label.custom_minimum_size = Vector2(180, 82)
	description_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	description_label.text = _get_reward_card_rules_text(card)
	vbox.add_child(description_label)

	if card.flavor_text != "":
		var flavor_label := RichTextLabel.new()
		flavor_label.name = "FlavorLabel"
		flavor_label.bbcode_enabled = true
		flavor_label.fit_content = false
		flavor_label.scroll_active = false
		flavor_label.custom_minimum_size = Vector2(180, 38)
		flavor_label.text = "[i]\"" + card.flavor_text + "\"[/i]"
		vbox.add_child(flavor_label)

	reward_card_glint = ColorRect.new()
	reward_card_glint.name = "RewardCardGlint"
	reward_card_glint.color = Color(1.0, 0.92, 0.58, 1.0)
	reward_card_glint.size = Vector2(44, 430)
	reward_card_glint.position = Vector2(-80, -60)
	reward_card_glint.rotation_degrees = -22.0
	reward_card_glint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reward_card_glint.modulate.a = 0.0
	card_root.add_child(reward_card_glint)

	reward_card_reveal_overlay = ColorRect.new()
	reward_card_reveal_overlay.name = "RewardCardRevealOverlay"
	reward_card_reveal_overlay.color = Color(1.0, 0.86, 0.42, 1.0)
	reward_card_reveal_overlay.size = REWARD_CARD_SIZE
	reward_card_reveal_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reward_card_reveal_overlay.modulate.a = 0.22
	card_root.add_child(reward_card_reveal_overlay)

	return card_root

func _get_reward_card_rules_text(card: CardData) -> String:
	var lines: Array[String] = []

	if card.description != "":
		lines.append(card.description)

	if card.dice_required > 0:
		lines.append("")
		lines.append("[center]Dice required: " + str(card.dice_required) + "[/center]")

	if card.base_damage > 0:
		lines.append("[center]Damage: " + str(card.base_damage) + "[/center]")

	if card.base_guard > 0:
		lines.append("[center]Guard: " + str(card.guard_amount) + "[/center]")

	return "\n".join(lines)


func _get_reward_card_icon_text(card: CardData) -> String:
	if card == null:
		return "✦"

	if card.base_damage > 0:
		return "⚔"

	if card.guard_amount > 0:
		return "🛡"

	return "✦"


func _on_reward_card_mouse_entered() -> void:
	if reward_card_visual == null or not is_instance_valid(reward_card_visual):
		return

	reward_card_follow_mouse = true

	if reward_card_hover_tween != null:
		reward_card_hover_tween.kill()

	reward_card_hover_tween = reward_card_visual.create_tween()
	reward_card_hover_tween.set_parallel(true)
	reward_card_hover_tween.tween_property(reward_card_visual, "scale", REWARD_CARD_HOVER_SCALE, 0.14).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	reward_card_hover_tween.tween_property(reward_card_visual, "position", reward_card_rest_position + Vector2(0, -REWARD_CARD_HOVER_LIFT), 0.14).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	_play_reward_card_glint_sweep()

func _on_reward_card_mouse_exited() -> void:
	if reward_card_visual == null or not is_instance_valid(reward_card_visual):
		return

	reward_card_follow_mouse = false

	if reward_card_hover_tween != null:
		reward_card_hover_tween.kill()

	reward_card_hover_tween = reward_card_visual.create_tween()
	reward_card_hover_tween.set_parallel(true)
	reward_card_hover_tween.tween_property(reward_card_visual, "position", reward_card_rest_position, 0.14).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
	reward_card_hover_tween.tween_property(reward_card_visual, "rotation_degrees", 0.0, 0.14).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
	reward_card_hover_tween.tween_property(reward_card_visual, "scale", Vector2.ONE, 0.14).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)

	if reward_card_glint != null and is_instance_valid(reward_card_glint):
		reward_card_glint.modulate.a = 0.0

func _clear_reward_card_visual() -> void:
	reward_card_follow_mouse = false

	if reward_card_hover_tween != null:
		reward_card_hover_tween.kill()
		reward_card_hover_tween = null

	if reward_card_holder != null and is_instance_valid(reward_card_holder):
		reward_card_holder.queue_free()

	reward_card_holder = null
	reward_card_visual = null
	reward_card_glint = null
	reward_card_reveal_overlay = null

	if reward_card_label != null:
		reward_card_label.text = ""
		reward_card_label.visible = false
