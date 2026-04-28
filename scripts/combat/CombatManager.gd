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
@export var cards_drawn_per_turn: int = 1

var players: Array[PlayerCombatant] = []
var enemies: Array[EnemyCombatant] = []

var active_player: PlayerCombatant

var is_player_turn: bool = false
var combat_is_active: bool = false


func setup_combat(new_players: Array[PlayerCombatant], new_enemies: Array[EnemyCombatant]) -> void:
	players = new_players
	enemies = new_enemies

	active_player = _get_first_living_player()

	for combatant in players + enemies:
		combatant.died.connect(_on_combatant_died)

func get_living_players() -> Array[PlayerCombatant]:
	return players.filter(func(p): return p != null and not p.is_dead())


func get_living_enemies() -> Array[EnemyCombatant]:
	return enemies.filter(func(e): return e != null and not e.is_dead())


func _get_first_living_player() -> PlayerCombatant:
	var living_players := get_living_players()
	if living_players.is_empty():
		return null

	return living_players[0]


func _get_first_living_enemy() -> EnemyCombatant:
	var living_enemies := get_living_enemies()
	if living_enemies.is_empty():
		return null

	return living_enemies[0]

func start_combat() -> void:
	if players.is_empty() or enemies.is_empty():
		push_error("CombatManager cannot start combat without both teams.")
		return

	combat_is_active = true
	combat_started.emit()

	for p in players:
		p.draw_cards(starting_hand_size)

	for e in enemies:
		e.draw_cards(starting_hand_size)

	_prepare_enemy_intents()
	start_player_turn()

func start_player_turn() -> void:
	if not combat_is_active:
		return

	active_player = _get_first_living_player()

	if active_player == null:
		_end_combat(_get_first_living_enemy())
		return

	is_player_turn = true

	for p in get_living_players():
		p.reset_guard()
		p.roll_dice()
		p.draw_cards(cards_drawn_per_turn)

	player_turn_started.emit()

func end_player_turn() -> void:
	if not combat_is_active:
		return

	if not is_player_turn:
		return

	if get_living_enemies().is_empty():
		_end_combat(_get_first_living_player())
		return

	is_player_turn = false
	start_enemy_turn()

func start_enemy_turn() -> void:
	if not combat_is_active:
		return

	if get_living_enemies().is_empty():
		_end_combat(_get_first_living_player())
		return

	enemy_turn_started.emit()

	for e in get_living_enemies():
		e.reset_guard()

		var selected_card := e.get_selected_card()
		var selected_dice := e.get_selected_dice()
		var target := _get_first_living_player()

		if selected_card != null and target != null:
			_try_enemy_play_prepared_card(e, selected_card, selected_dice, target)

		e.clear_selected_card()

	_check_combat_end()

	if combat_is_active:
		_prepare_enemy_intents()
		start_player_turn()
	
func play_player_card(card: CardData, assigned_dice: Array[DiceData], target: Combatant = null) -> bool:
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

	if active_player == null:
		return false

	if not card.can_use_with_dice(assigned_dice):
		return false

	# Make sure dice are actually available before using them.
	for die in assigned_dice:
		if not active_player.get_available_dice().has(die):
			return false

	# Assign dice so they cannot be reused.
	for die in assigned_dice:
		active_player.dice_pool.assign_die(die)

	if target == null and card.can_target_enemy:
		target = _get_first_living_enemy()

	_resolve_card(card, active_player, target)

	# Check for combat end immediately after resolving the card.
	_check_combat_end()

	# If combat ended, stop resolving extra cleanup logic.
	if not combat_is_active:
		return true

	active_player.discard_card(card)

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
		if target != null:
			print("Applying damage to target.")
			target.take_damage(damage_amount)
		else:
			print("No target for damage.")
	else:
		print("No damage applied.")

	if guard_amount > 0:
		print("Applying guard to user.")
		user.gain_guard(guard_amount)

	if card.cards_to_draw > 0:
		user.draw_cards(card.cards_to_draw)
	
	if card.can_target_self and damage_amount > 0:
		user.take_damage(damage_amount)

func _check_combat_end() -> void:
	if get_living_players().is_empty():
		_end_combat(_get_first_living_enemy())
		return

	if get_living_enemies().is_empty():
		_end_combat(_get_first_living_player())
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

func _prepare_enemy_intents() -> void:
	for e in get_living_enemies():
		e.roll_dice()
		e.draw_cards(cards_drawn_per_turn)
		e.prepare_intent()

	enemy_intent_prepared.emit()

func _try_enemy_play_prepared_card(enemy_actor: EnemyCombatant, card: CardData, assigned_dice: Array[DiceData], target: Combatant) -> bool:
	if card == null:
		return false

	if not enemy_actor.hand.has(card):
		return false

	if not card.can_use_with_dice(assigned_dice):
		return false

	for die in assigned_dice:
		if not enemy_actor.get_available_dice().has(die):
			return false

	for die in assigned_dice:
		enemy_actor.dice_pool.assign_die(die)

	_resolve_card(card, enemy_actor, target)

	enemy_actor.discard_card(card)

	return true
