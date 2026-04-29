extends Control
class_name InteractionResultView

signal continue_pressed

@onready var title_label: Label = $Panel/MarginContainer/HBoxContainer/VBoxContainer/TitleLabel
@onready var result_text_label: RichTextLabel = $Panel/MarginContainer/HBoxContainer/VBoxContainer/ResultTextLabel
@onready var reward_card_panel: PanelContainer = $Panel/MarginContainer/HBoxContainer/VBoxContainer/RewardCardPanel
@onready var reward_card_label: Label = $Panel/MarginContainer/HBoxContainer/VBoxContainer/RewardCardPanel/RewardCardLabel
@onready var continue_button: Button = $Panel/MarginContainer/HBoxContainer/VBoxContainer/ContinueButton


func _ready() -> void:
	continue_button.pressed.connect(func():
		continue_pressed.emit()
	)


func show_result(title_text: String, result_text: String, reward_card: CardData = null) -> void:
	visible = true

	title_label.text = title_text
	result_text_label.text = result_text

	if reward_card != null:
		reward_card_panel.visible = true
		reward_card_label.text = reward_card.card_name + "\n\n" + reward_card.description
	else:
		reward_card_panel.visible = false
		reward_card_label.text = ""
