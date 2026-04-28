extends Node
class_name CombatManager

signal combat_started
signal player_turn_started
signal enemy_turn_started
signal combat_ended(winner: Combatant)
signal enemy_intent_prepared

# New polish signals.
signal combat_log(message: String)
signal card_resolved(card: CardData, user: Combatant, target: Combatant, damage_amount: int, guard_amount: int)
signal enemy_action_started(enemy: EnemyCombatant, card: CardData, target: Combatant)

@export var starting_hand_size: int = 5
@export var cards_drawn_per_turn: int = 1
@export var action_delay: float = 0.35
@export var enemy_action_delay: float = 0.55
var players: Array[PlayerCombatant] = []
var enemies: Array[EnemyCombatant] = []

var active_player: PlayerCombatant

var is_player_turn: bool = false
var combat_is_active: bool = false
var has_started_first_player_turn: bool = false

func setup_combat(new_players: Array[PlayerCombatant], new_enemies: Array[EnemyCombatant]) -> void:
	players = new_players
	enemies = new_enemies

	active_player = _get_first_living_player()

	for combatant in players + enemies:
		if not combatant.died.is_connected(_on_combatant_died):
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

func get_enemy_slot_targets_for_cleave() -> Array[Combatant]:
	return _get_slot_1_and_random_other(enemies)


func get_player_slot_targets_for_cleave() -> Array[Combatant]:
	return _get_slot_1_and_random_other(players)


func _get_slot_1_and_random_other(team: Array) -> Array[Combatant]:
	var targets: Array[Combatant] = []

	# Slot 1 means index 0.
	if team.size() > 0:
		var slot_1 = team[0]
		if slot_1 != null and not slot_1.is_dead():
			targets.append(slot_1)

	var other_slots: Array[Combatant] = []

	for i in range(1, team.size()):
		var combatant = team[i]
		if combatant != null and not combatant.is_dead():
			other_slots.append(combatant)

	if not other_slots.is_empty():
		other_slots.shuffle()
		targets.append(other_slots[0])

	return targets

func start_combat() -> void:
	if players.is_empty() or enemies.is_empty():
		push_error("CombatManager cannot start combat without both teams.")
		return
		
	combat_is_active = true
	combat_started.emit()
	combat_log.emit("Combat started.")
	has_started_first_player_turn = false
	
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

		if has_started_first_player_turn:
			p.draw_cards(cards_drawn_per_turn)

	has_started_first_player_turn = true

	combat_log.emit("--- Player Turn ---")
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

	combat_log.emit("--- Enemy Turn ---")
	enemy_turn_started.emit()

	for e in get_living_enemies():
		if e == null or e.is_dead():
			continue

		e.reset_guard()

		await get_tree().create_timer(enemy_action_delay).timeout

		var selected_card := e.get_selected_card()
		var selected_dice := e.get_selected_dice()
		var target := _get_enemy_target_for_card(selected_card)

		if selected_card != null:
			enemy_action_started.emit(e, selected_card, target)
			_try_enemy_play_prepared_card(e, selected_card, selected_dice, target)

		e.clear_selected_card()

		_check_combat_end()

		if not combat_is_active:
			return

	if combat_is_active:
		await get_tree().create_timer(action_delay).timeout
		_prepare_enemy_intents()
		start_player_turn()
func _get_enemy_target_for_card(card: CardData) -> Combatant:
	if card == null:
		return null

	match card.target_mode:
		CardData.TargetMode.SINGLE_ENEMY:
			return _get_first_living_player()

		CardData.TargetMode.SINGLE_ALLY:
			return null

		CardData.TargetMode.NONE:
			return null

		CardData.TargetMode.SLOT_1_AND_RANDOM_OTHER:
			return null

	return null

func play_player_card(card: CardData, assigned_dice: Array[DiceData], target: Combatant = null) -> bool:
	if not combat_is_active:
		return false

	if not is_player_turn:
		return false

	if card == null:
		return false

	if active_player == null:
		return false

	if active_player.is_dead():
		return false

	if not active_player.hand.has(card):
		return false

	var dice_to_spend : Variant = _get_valid_dice_to_spend(active_player, card, assigned_dice)
	if dice_to_spend == null:
		return false

	if not _is_valid_player_target_for_card(card, target):
		return false

	for die in dice_to_spend:
		active_player.dice_pool.assign_die(die)

	_resolve_player_card_by_target_mode(card, active_player, target)

	if active_player.hand.has(card):
		active_player.discard_card(card)

	_check_combat_end()

	return true

func _get_valid_dice_to_spend(user: Combatant, card: CardData, assigned_dice: Array[DiceData]) -> Variant:
	var dice_to_spend: Array[DiceData] = []

	if card.dice_required <= 0:
		return dice_to_spend

	for die in assigned_dice:
		if dice_to_spend.size() >= card.dice_required:
			break

		if die != null and user.get_available_dice().has(die):
			dice_to_spend.append(die)

	if not card.can_use_with_dice(dice_to_spend):
		return null

	return dice_to_spend


func _is_valid_player_target_for_card(card: CardData, target: Combatant) -> bool:
	match card.target_mode:
		CardData.TargetMode.NONE:
			return true

		CardData.TargetMode.SLOT_1_AND_RANDOM_OTHER:
			return true

		CardData.TargetMode.SINGLE_ENEMY:
			return target != null and not target.is_dead() and _is_enemy_combatant(target)

		CardData.TargetMode.SINGLE_ALLY:
			return target != null and not target.is_dead() and _is_player_combatant(target)

	return false


func _is_player_combatant(combatant: Combatant) -> bool:
	for p in players:
		if p == combatant:
			return true
	return false


func _is_enemy_combatant(combatant: Combatant) -> bool:
	for e in enemies:
		if e == combatant:
			return true
	return false

func _resolve_player_card_by_target_mode(card: CardData, user: Combatant, target: Combatant) -> void:
	match card.target_mode:
		CardData.TargetMode.NONE:
			_resolve_card(card, user, user)

		CardData.TargetMode.SINGLE_ENEMY:
			_resolve_card(card, user, target)

		CardData.TargetMode.SINGLE_ALLY:
			_resolve_card(card, user, target)

		CardData.TargetMode.SLOT_1_AND_RANDOM_OTHER:
			var targets := get_enemy_slot_targets_for_cleave()

			if targets.is_empty():
				combat_log.emit("%s finds no targets for %s." % [
					user.get_display_name(),
					card.card_name
				])
				return

			for cleave_target in targets:
				_resolve_card(card, user, cleave_target)

func _resolve_card(card: CardData, user: Combatant, target: Combatant) -> void:
	var damage_amount: int = card.get_final_damage(user)
	var guard_amount: int = card.get_final_guard(user)

	print("--- Resolving Card ---")
	print("User: ", user.get_display_name())
	print("Card: ", card.card_name)
	print("Base damage: ", card.base_damage)
	print("User power: ", user.get_power())
	print("Final damage: ", damage_amount)
	print("Can target enemy: ", card.can_target_enemy)
	print("Target: ", target.get_display_name() if target != null else "None")
	print("Base guard: ", card.base_guard)
	print("User guard bonus: ", user.get_guard_bonus())
	print("Final guard: ", guard_amount)

	if damage_amount > 0 and card.can_target_enemy:
		if target != null and not target.is_dead():
			print("%s hits %s with %s for %s damage." % [
				user.get_display_name(),
				target.get_display_name(),
				card.card_name,
				damage_amount
			])
			target.take_damage(damage_amount)
		else:
			print("No valid target for damage.")
	else:
		print("No damage applied.")

	if guard_amount > 0:
		print("%s gains %s guard from %s." % [
			user.get_display_name(),
			guard_amount,
			card.card_name
		])
		user.gain_guard(guard_amount)

	if card.cards_to_draw > 0:
		print("%s draws %s cards." % [
			user.get_display_name(),
			card.cards_to_draw
		])
		user.draw_cards(card.cards_to_draw)

	if card.can_target_self and damage_amount > 0:
		print("%s damages themselves for %s." % [
			user.get_display_name(),
			damage_amount
		])
		user.take_damage(damage_amount)

	card_resolved.emit(card, user, target, damage_amount, guard_amount)


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
	combat_log.emit("%s dies." % dead_combatant.get_display_name())
	_check_combat_end()


func _prepare_enemy_intents() -> void:
	for e in get_living_enemies():
		e.roll_dice()
		e.draw_cards(cards_drawn_per_turn)
		e.prepare_intent()

	enemy_intent_prepared.emit()


func _try_enemy_play_prepared_card(enemy_actor: EnemyCombatant, card: CardData, assigned_dice: Array[DiceData], target: Combatant) -> bool:
	if enemy_actor == null or enemy_actor.is_dead():
		return false

	if card == null:
		return false

	if not enemy_actor.hand.has(card):
		return false

	var dice_to_spend : Variant = _get_valid_dice_to_spend(enemy_actor, card, assigned_dice)
	if dice_to_spend == null:
		return false

	for die in dice_to_spend:
		enemy_actor.dice_pool.assign_die(die)

	_resolve_enemy_card_by_target_mode(card, enemy_actor, target)

	if enemy_actor.hand.has(card):
		enemy_actor.discard_card(card)

	return true

func _resolve_enemy_card_by_target_mode(card: CardData, user: EnemyCombatant, target: Combatant) -> void:
	match card.target_mode:
		CardData.TargetMode.NONE:
			_resolve_card(card, user, user)

		CardData.TargetMode.SINGLE_ENEMY:
			if target != null:
				_resolve_card(card, user, target)

		CardData.TargetMode.SINGLE_ALLY:
			_resolve_card(card, user, user)

		CardData.TargetMode.SLOT_1_AND_RANDOM_OTHER:
			var targets := get_player_slot_targets_for_cleave()

			if targets.is_empty():
				combat_log.emit("%s finds no targets for %s." % [
					user.enemy_name,
					card.card_name
				])
				return

			for cleave_target in targets:
				_resolve_card(card, user, cleave_target)
