extends Control
class_name InteractionResultView

# InteractionResultView handles two modes:
#
# 1. show_result()  — displays flavour text + reward after an outcome fires.
#                     A "Continue" button calls the provided callback.
#
# 2. show_choices() — displays 2-4 outcome buttons for the player to pick from.
#                     Selecting one calls the callback with the chosen outcome.

const CARD_VIEW_SCENE: PackedScene = preload("res://scenes/ui/CardView.tscn")

@onready var dark_overlay: ColorRect = $DarkOverlay
@onready var panel: PanelContainer = $Panel
@onready var title_label: Label = $Panel/MarginContainer/VBoxContainer/TitleLabel
@onready var result_text_label: RichTextLabel = $Panel/MarginContainer/VBoxContainer/ResultTextLabel
@onready var reward_container: Control = $Panel/MarginContainer/VBoxContainer/RewardContainer
@onready var buttons_container: VBoxContainer = $Panel/MarginContainer/VBoxContainer/ButtonsContainer

var _continue_callback: Callable
var _choice_callback: Callable


func _ready() -> void:
	if reward_container != null:
		reward_container.visible = false


# --- Single result mode ---

func show_result(outcome: InteractableOutcome, on_continue: Callable) -> void:
	_continue_callback = on_continue
	visible = true

	title_label.text = _get_result_title(outcome)
	result_text_label.text = outcome.result_text
	result_text_label.visible = outcome.result_text != ""

	_clear_buttons()
	_show_reward_if_any(outcome)
	_add_continue_button("Continue", func():
		_continue_callback.call()
	)


# --- Multi-choice mode ---

func show_choices(outcomes: Array[InteractableOutcome], on_chosen: Callable) -> void:
	_choice_callback = on_chosen
	visible = true

	title_label.text = "What do you do?"
	result_text_label.visible = false

	if reward_container != null:
		reward_container.visible = false

	_clear_buttons()

	for outcome in outcomes:
		var label_text := outcome.label if outcome.label != "" else "Continue"
		var captured := outcome

		var button := _make_button(label_text)
		button.pressed.connect(func():
			_choice_callback.call(captured)
		)
		buttons_container.add_child(button)


# --- Helpers ---

func _get_result_title(outcome: InteractableOutcome) -> String:
	if outcome.card_reward != null:
		return "You found: " + outcome.card_reward.card_name

	if outcome.heal_amount > 0:
		return "You rest."

	if outcome.has_stat_changes():
		return "Something changes."

	return ""


func _show_reward_if_any(outcome: InteractableOutcome) -> void:
	if reward_container == null:
		return

	reward_container.visible = false
	_clear_children(reward_container)

	if outcome.card_reward == null:
		return

	if CARD_VIEW_SCENE == null:
		return

	reward_container.visible = true

	var card_view: CardView = CARD_VIEW_SCENE.instantiate()
	reward_container.add_child(card_view)
	card_view.call_deferred("setup", outcome.card_reward, false)

	# Animate in.
	card_view.modulate.a = 0.0
	card_view.scale = Vector2(0.7, 0.7)
	var tween := card_view.create_tween()
	tween.set_parallel(true)
	tween.tween_property(card_view, "modulate:a", 1.0, 0.18)
	tween.tween_property(card_view, "scale", Vector2.ONE, 0.32).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _add_continue_button(label_text: String, callback: Callable) -> void:
	var button := _make_button(label_text)
	button.pressed.connect(callback)
	buttons_container.add_child(button)


func _make_button(label_text: String) -> Button:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(320, 44)
	button.focus_mode = Control.FOCUS_NONE
	return button


func _clear_buttons() -> void:
	_clear_children(buttons_container)


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()
