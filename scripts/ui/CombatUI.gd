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
@onready var dice_container: HBoxContainer = $Container/DiceContainer
@onready var hand_container: HBoxContainer = $Container/HandContainer
@onready var end_turn_button: Button = $EndTurnButton
@export var card_view_scene: PackedScene

var combat_manager: CombatManager
var player: PlayerCombatant
var enemy: EnemyCombatant

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
	
	hand_container.alignment = BoxContainer.ALIGNMENT_CENTER
	hand_container.add_theme_constant_override("separation", -55)
	
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

func _can_selected_dice_play_card(card: CardData) -> bool:
	if selected_dice.size() < card.dice_required:
		return false

	return card.can_use_with_dice(selected_dice)


func _can_any_card_use_die(die: DiceData) -> bool:
	if die == null:
		return false

	if die.is_assigned:
		return false

	for card in player.hand:
		if card.can_use_with_die(die.current_value):
			return true

	return false


func _clear_invalid_selected_dice() -> void:
	# Removes dice from selection if they are no longer usable.
	# This protects against stale selections after cards are played.
	var valid_selection: Array[DiceData] = []

	for die in selected_dice:
		if die != null and not die.is_assigned and _can_any_card_use_die(die):
			valid_selection.append(die)

	selected_dice = valid_selection

func _refresh_hand() -> void:
	_clear_children(hand_container)

	if card_view_scene == null:
		push_error("CombatUI is missing card_view_scene.")
		return

	for card in player.hand:
		var card_view: CardView = card_view_scene.instantiate()
		hand_container.add_child(card_view)

		var is_playable := _can_selected_dice_play_card(card)

		card_view.setup(card, is_playable)

		card_view.card_selected.connect(func(selected_card: CardData):
			_on_card_pressed(selected_card)
		)

func _refresh_dice() -> void:
	_clear_invalid_selected_dice()
	_clear_children(dice_container)

	for die in player.get_dice():
		var button := Button.new()
		button.custom_minimum_size = Vector2(60, 60)

		if selected_dice.has(die):
			button.text = "[" + str(die.current_value) + "]"
		else:
			button.text = str(die.current_value)

		# Disable dice that are already spent.
		if die.is_assigned:
			button.disabled = true

		# Disable dice if no card in hand could use it.
		elif not _can_any_card_use_die(die):
			button.disabled = true

		button.pressed.connect(func():
			_on_die_pressed(die)
		)

		dice_container.add_child(button)

func _on_card_pressed(card: CardData) -> void:
	# Cards resolve immediately when clicked.
	# The player must already have selected enough valid dice.

	if selected_dice.size() < card.dice_required:
		print("Not enough dice selected for ", card.card_name)
		return

	if not card.can_use_with_dice(selected_dice):
		print("Selected dice cannot be used for ", card.card_name)
		return

	var success := combat_manager.play_player_card(card, selected_dice)

	if success:
		print("Played card: ", card.card_name)

		# Clear dice selection after spending dice.
		selected_dice.clear()

		# Refresh UI immediately after card resolution.
		_refresh_hand()
		_refresh_dice()
		_update_all()
	else:
		print("Could not play card: ", card.card_name)

func _on_die_pressed(die: DiceData) -> void:
	if die.is_assigned:
		return

	if not _can_any_card_use_die(die):
		return

	if selected_dice.has(die):
		selected_dice.erase(die)
		print("Unselected die: ", die.current_value)
	else:
		selected_dice.append(die)
		print("Selected die: ", die.current_value)

	_clear_invalid_selected_dice()
	_refresh_dice()
	_refresh_hand()


func _on_end_turn_pressed() -> void:
	selected_dice.clear()
	combat_manager.end_player_turn()

func _on_player_turn_started() -> void:
	end_turn_button.disabled = false
	selected_dice.clear()

	_refresh_hand()
	_refresh_dice()
	_update_all()


func _on_enemy_turn_started() -> void:
	end_turn_button.disabled = true
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
