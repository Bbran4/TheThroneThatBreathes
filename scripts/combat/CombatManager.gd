extends Node
class_name CombatManager

# CombatManager controls the flow of combat.
#
# It should not store character stats.
# It should not define card data.
# It should not directly belong to the player or enemy.
#
# Its job is to coordinate:
# - turn order
# - drawing cards
# - rolling dice
# - resolving card effects
# - checking win/loss states

signal combat_started
signal player_turn_started
signal enemy_turn_started
signal combat_ended(winner: Combatant)
signal enemy_intent_prepared

@export var starting_hand_size: int = 5
@export var cards_drawn_per_turn: int = 5

var player: PlayerCombatant
var enemy: EnemyCombatant

var is_player_turn: bool = false
var combat_is_active: bool = false


func setup_combat(new_player: PlayerCombatant, new_enemy: EnemyCombatant) -> void:
	# The manager receives combatants that already exist in the scene.
	# This keeps CombatManager flexible and reusable.
	player = new_player
	enemy = new_enemy

	# Listen for death events so combat can end immediately.
	player.died.connect(_on_combatant_died)
	enemy.died.connect(_on_combatant_died)


func start_combat() -> void:
	if player == null or enemy == null:
		push_error("CombatManager cannot start combat without both player and enemy.")
		return

	combat_is_active = true
	combat_started.emit()

	_prepare_enemy_intent()
	start_player_turn()


func start_player_turn() -> void:
	if not combat_is_active:
		return

	is_player_turn = true

	player.reset_guard()
	player.roll_dice()
	player.draw_cards(cards_drawn_per_turn)

	player_turn_started.emit()


func end_player_turn() -> void:
	if not combat_is_active:
		return

	if not is_player_turn:
		return

	# Discard remaining player hand at end of turn.
	player.discard_hand()

	is_player_turn = false
	start_enemy_turn()


func start_enemy_turn() -> void:
	if not combat_is_active:
		return

	enemy_turn_started.emit()

	enemy.reset_guard()

	var selected_card := enemy.get_selected_card()
	var selected_dice := enemy.get_selected_dice()

	if selected_card != null:
		_try_enemy_play_prepared_card(selected_card, selected_dice)

	enemy.discard_hand()
	enemy.clear_selected_card()

	_check_combat_end()

	if combat_is_active:
		_prepare_enemy_intent()
		start_player_turn()

func play_player_card(card: CardData, assigned_dice: Array[DiceData]) -> bool:
	# This function will be called by UI later.
	#
	# The player selects a card, assigns dice, then confirms.
	# This function validates and resolves that action.

	if not combat_is_active:
		return false

	if not is_player_turn:
		return false

	if card == null:
		return false

	if not player.hand.has(card):
		return false

	if not card.can_use_with_dice(assigned_dice):
		return false

	# Make sure dice are actually available before using them.
	for die in assigned_dice:
		if not player.get_available_dice().has(die):
			return false

	# Assign dice so they cannot be reused.
	for die in assigned_dice:
		player.dice_pool.assign_die(die)

	_resolve_card(card, player, enemy)

	# Check for combat end immediately after resolving the card.
	_check_combat_end()

	# If combat ended, stop resolving extra cleanup logic.
	if not combat_is_active:
		return true

	player.discard_card(card)

	return true


func _try_enemy_play_card(card: CardData) -> bool:
	# Simple enemy card play logic.
	#
	# For now, enemy uses the first available dice that meet the card requirement.
	# Later, AI can become smarter.

	var assigned_dice: Array[DiceData] = []

	for die in enemy.get_available_dice():
		if card.can_use_with_die(die.current_value):
			assigned_dice.append(die)

			if assigned_dice.size() >= card.dice_required:
				break

	if not card.can_use_with_dice(assigned_dice):
		return false

	for die in assigned_dice:
		enemy.dice_pool.assign_die(die)

	_resolve_card(card, enemy, player)

	return true


func _resolve_card(card: CardData, user: Combatant, target: Combatant) -> void:
	# This is where card effects are applied.
	#
	# Right now we support:
	# - damage
	# - guard
	# - card draw
	#
	# Later this can expand into status effects, curses, relic triggers, etc.

	var damage_amount: int = card.get_final_damage(user)
	var guard_amount: int = card.get_final_guard(user)

	print("--- Resolving Card ---")
	print("Card: ", card.card_name)
	print("Base damage: ", card.base_damage)
	print("User power: ", user.get_power())
	print("Final damage: ", damage_amount)
	print("Can target enemy: ", card.can_target_enemy)
	print("Base guard: ", card.base_guard)
	print("Final guard: ", guard_amount)

	if damage_amount > 0 and card.can_target_enemy:
		print("Applying damage to target.")
		target.take_damage(damage_amount)
	else:
		print("No damage applied.")

	if guard_amount > 0:
		print("Applying guard to user.")
		user.gain_guard(guard_amount)

	if card.cards_to_draw > 0:
		user.draw_cards(card.cards_to_draw)


func _check_combat_end() -> void:
	if player.is_dead():
		_end_combat(enemy)
		return

	if enemy.is_dead():
		_end_combat(player)
		return


func _end_combat(winner: Combatant) -> void:
	if not combat_is_active:
		return

	combat_is_active = false
	is_player_turn = false

	combat_ended.emit(winner)


func _on_combatant_died(dead_combatant: Combatant) -> void:
	# If someone dies from damage, immediately check who won.
	_check_combat_end()

func _prepare_enemy_intent() -> void:
	# Enemy prepares its next action before the player acts.
	# This gives the player tactical information.

	enemy.roll_dice()
	enemy.draw_cards(cards_drawn_per_turn)
	enemy.prepare_intent()

	enemy_intent_prepared.emit()

func _try_enemy_play_prepared_card(card: CardData, assigned_dice: Array[DiceData]) -> bool:
	if card == null:
		return false

	if not enemy.hand.has(card):
		return false

	if not card.can_use_with_dice(assigned_dice):
		return false

	for die in assigned_dice:
		if not enemy.get_available_dice().has(die):
			return false

	for die in assigned_dice:
		enemy.dice_pool.assign_die(die)

	_resolve_card(card, enemy, player)

	return true
