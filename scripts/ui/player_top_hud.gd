extends Control
class_name PlayerTopHUD

signal end_turn_pressed

@onready var player_name_label: Label = $HBoxContainer/PlayerNameLabel
@onready var health_bar: ProgressBar = $HBoxContainer/HealthBar
@onready var guard_label: Label = $HBoxContainer/GuardLabel
@onready var status_label: Label = $HBoxContainer/StatusLabel
@onready var end_turn_button: Button = $HBoxContainer/EndTurnButton

var player: PlayerCombatant


func _ready() -> void:
	end_turn_button.pressed.connect(func():
		end_turn_pressed.emit()
	)


func setup(new_player: PlayerCombatant, display_name: String = "Exiled Knight") -> void:
	player = new_player

	player_name_label.text = display_name

	if player == null:
		_clear()
		return

	player.hp_changed.connect(_on_hp_changed)
	player.guard_changed.connect(_on_guard_changed)
	player.died.connect(_on_player_died)

	_refresh_all()


func set_player(new_player: PlayerCombatant, display_name: String = "Exiled Knight") -> void:
	if player == new_player:
		_refresh_all()
		return

	player = new_player
	player_name_label.text = display_name

	if player == null:
		_clear()
		return

	if not player.hp_changed.is_connected(_on_hp_changed):
		player.hp_changed.connect(_on_hp_changed)

	if not player.guard_changed.is_connected(_on_guard_changed):
		player.guard_changed.connect(_on_guard_changed)

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

	health_bar.max_value = player.stats.max_hp
	health_bar.value = player.current_hp
	guard_label.text = "🛡 " + str(player.current_guard)

	if status_label.text == "":
		status_label.text = ""


func _on_hp_changed(current_hp: int, max_hp: int) -> void:
	health_bar.max_value = max_hp
	health_bar.value = current_hp


func _on_guard_changed(current_guard: int) -> void:
	guard_label.text = "🛡 " + str(current_guard)


func _on_player_died(_combatant: Combatant) -> void:
	set_status_text("DEAD")
	set_end_turn_enabled(false)


func _clear() -> void:
	player_name_label.text = ""
	health_bar.max_value = 1
	health_bar.value = 0
	guard_label.text = "🛡 0"
	status_label.text = ""
	set_end_turn_enabled(false)
