extends Control
class_name PlayerTopHUD

signal end_turn_pressed

@onready var status_label: Label = $HBoxContainer/StatusLabel
@onready var end_turn_button: Button = $HBoxContainer/EndTurnButton



var player: PlayerCombatant


func _ready() -> void:
	end_turn_button.pressed.connect(func():
		end_turn_pressed.emit()
	)


func setup(new_player: PlayerCombatant, display_name: String = "Exiled Knight") -> void:
	player = new_player

	if player == null:
		_clear()
		return

	player.died.connect(_on_player_died)

	_refresh_all()


func set_player(new_player: PlayerCombatant, display_name: String = "Exiled Knight") -> void:
	if player == new_player:
		_refresh_all()
		return

	player = new_player

	if player == null:
		_clear()
		return

	if not player.died.is_connected(_on_player_died):
		player.died.connect(_on_player_died)

	_refresh_all()


func set_end_turn_enabled(is_enabled: bool) -> void:
	end_turn_button.disabled = not is_enabled


func set_status_text(text_value: String) -> void:
	status_label.text = text_value

func _refresh_all() -> void:
	if player == null:
		_clear()
		return

	if status_label.text == "":
		status_label.text = ""


func _on_player_died(_combatant: Combatant) -> void:
	set_status_text("DEAD")
	set_end_turn_enabled(false)


func _clear() -> void:
	status_label.text = ""
	set_end_turn_enabled(false)
