extends Control
class_name CombatUI

# CombatUI displays the current combat state.
#
# It does not own combat rules.
# It only:
# - reads combatant state
# - creates buttons for cards and dice
# - sends player actions to CombatManager

@onready var enemy_label: Label = $EnemyInfo/EnemyLabel
@onready var player_label: Label = $PlayerInfo/PlayerLabel
@onready var dice_container: HBoxContainer = $DiceContainer
@onready var hand_container: HBoxContainer = $HandContainer
@onready var end_turn_button: Button = $EndTurnButton

var combat_manager: CombatManager
var player: PlayerCombatant
var enemy: EnemyCombatant

var selected_card: CardData = null
var selected_dice: Array[DiceData] = []


func setup_ui(new_combat_manager: CombatManager, new_player: PlayerCombatant, new_enemy: EnemyCombatant) -> void:
	# Store references to the combat objects.
	combat_manager = new_combat_manager
	player = new_player
	enemy = new_enemy

	# Connect combatant signals so UI updates when data changes.
	player.hp_changed.connect(_on_player_hp_changed)
	player.guard_changed.connect(_on_player_guard_changed)
	player.hand_changed.connect(_on_player_hand_changed)
	player.dice_pool.dice_changed.connect(_on_player_dice_changed)

	enemy.hp_changed.connect(_on_enemy_hp_changed)
	enemy.guard_changed.connect(_on_enemy_guard_changed)

	combat_manager.player_turn_started.connect(_on_player_turn_started)
	combat_manager.enemy_turn_started.connect(_on_enemy_turn_started)
	combat_manager.combat_ended.connect(_on_combat_ended)

	end_turn_button.pressed.connect(_on_end_turn_pressed)

	_update_all()


func _update_all() -> void:
	_update_player_info()
	_update_enemy_info()


func _update_player_info() -> void:
	player_label.text = "Player HP: %s / %s\nGuard: %s" % [
		player.current_hp,
		player.stats.max_hp,
		player.current_guard
	]


func _update_enemy_info() -> void:
	enemy_label.text = "Enemy HP: %s / %s\nGuard: %s" % [
		enemy.current_hp,
		enemy.stats.max_hp,
		enemy.current_guard
	]


func _on_player_hp_changed(_current_hp: int, _max_hp: int) -> void:
	# We ignore the signal values for now and refresh the full UI.
	_update_all()


func _on_player_guard_changed(_current_guard: int) -> void:
	# Guard signal sends one value, so this wrapper receives it safely.
	_update_all()


func _on_enemy_hp_changed(_current_hp: int, _max_hp: int) -> void:
	_update_all()


func _on_enemy_guard_changed(_current_guard: int) -> void:
	_update_all()

func _on_player_hand_changed(hand: Array) -> void:
	_refresh_hand()


func _on_player_dice_changed(dice: Array[DiceData]) -> void:
	_refresh_dice()


func _refresh_hand() -> void:
	_clear_children(hand_container)

	for card in player.hand:
		var button := Button.new()
		button.text = _get_card_button_text(card)
		button.custom_minimum_size = Vector2(140, 90)

		button.pressed.connect(func():
			_on_card_pressed(card)
		)

		hand_container.add_child(button)


func _refresh_dice() -> void:
	_clear_children(dice_container)

	for die in player.get_dice():
		var button := Button.new()
		button.text = str(die.current_value)
		button.custom_minimum_size = Vector2(60, 60)

		if die.is_assigned:
			button.disabled = true

		button.pressed.connect(func():
			_on_die_pressed(die)
		)

		dice_container.add_child(button)


func _on_card_pressed(card: CardData) -> void:
	# Select the clicked card.
	selected_card = card
	selected_dice.clear()

	print("Selected card: ", card.card_name)


func _on_die_pressed(die: DiceData) -> void:
	if selected_card == null:
		print("Select a card first.")
		return

	if die.is_assigned:
		return

	if not selected_card.can_use_with_die(die.current_value):
		print("This die cannot be used for ", selected_card.card_name)
		return

	selected_dice.append(die)

	print("Selected die: ", die.current_value)

	if selected_dice.size() >= selected_card.dice_required:
		_try_play_selected_card()


func _try_play_selected_card() -> void:
	if selected_card == null:
		return

	var success := combat_manager.play_player_card(selected_card, selected_dice)

	if success:
		selected_card = null
		selected_dice.clear()
	else:
		print("Could not play selected card.")


func _on_end_turn_pressed() -> void:
	selected_card = null
	selected_dice.clear()

	combat_manager.end_player_turn()


func _on_player_turn_started() -> void:
	end_turn_button.disabled = false
	selected_card = null
	selected_dice.clear()

	_refresh_hand()
	_refresh_dice()
	_update_all()


func _on_enemy_turn_started() -> void:
	end_turn_button.disabled = true
	selected_card = null
	selected_dice.clear()

	_update_all()


func _on_combat_ended(winner: Combatant) -> void:
	end_turn_button.disabled = true

	if winner == player:
		player_label.text += "\nVictory."
	else:
		player_label.text += "\nDefeat."


func _get_card_button_text(card: CardData) -> String:
	return "%s\n%s" % [
		card.card_name,
		card.description
	]


func _clear_children(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()
