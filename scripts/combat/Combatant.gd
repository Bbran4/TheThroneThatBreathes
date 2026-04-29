extends Node
class_name Combatant

signal hp_changed(current_hp: int, max_hp: int)
signal guard_changed(current_guard: int)
signal hand_changed(hand: Array)
signal deck_changed(deck_count: int, discard_count: int)
signal died(combatant: Combatant)

signal damage_taken(
	combatant: Combatant,
	incoming_damage: int,
	blocked_damage: int,
	hp_damage: int,
	guard_before: int,
	guard_after: int,
	hp_before: int,
	hp_after: int
)

signal guard_gained(
	combatant: Combatant,
	amount: int,
	guard_before: int,
	guard_after: int
)

signal guard_reset(
	combatant: Combatant,
	guard_before: int,
	guard_after: int
)

var stats: CharacterStats

var current_hp: int = 0
var current_guard: int = 0
var has_emitted_death: bool = false

var dice_pool: DicePool

var deck: Array = []
var hand: Array = []
var discard_pile: Array = []


func setup(new_stats: CharacterStats, starting_deck: Array) -> void:
	stats = new_stats.duplicate_stats()

	current_hp = stats.max_hp
	current_guard = get_base_guard()
	has_emitted_death = false

	deck = starting_deck.duplicate()
	deck.shuffle()

	hand.clear()
	discard_pile.clear()

	_create_dice_pool()

	_emit_all_state_changes()

func take_damage(amount: int) -> void:
	if is_dead():
		return

	var incoming_damage: int = max(amount, 0)

	var guard_before := current_guard
	var hp_before := current_hp

	var effective_guard : Variant = max(current_guard, 0)
	var blocked_damage: int = min(effective_guard, incoming_damage)

	current_guard -= blocked_damage
	var remaining_damage: int = incoming_damage - blocked_damage

	current_hp = max(current_hp - remaining_damage, 0)

	var guard_after := current_guard
	var hp_after := current_hp

	print("%s takes damage." % get_display_name())
	print("  Guard before: ", guard_before)
	print("  Incoming damage: ", incoming_damage)
	print("  Blocked damage: ", blocked_damage)
	print("  HP damage: ", remaining_damage)
	print("  Guard after: ", guard_after)
	print("  HP: %s -> %s" % [hp_before, hp_after])

	if guard_before != guard_after:
		guard_changed.emit(current_guard)

	if hp_before != hp_after:
		hp_changed.emit(current_hp, stats.max_hp)

	damage_taken.emit(
		self,
		incoming_damage,
		blocked_damage,
		remaining_damage,
		guard_before,
		guard_after,
		hp_before,
		hp_after
	)

	if is_dead() and not has_emitted_death:
		has_emitted_death = true
		died.emit(self)

func gain_guard(amount: int) -> void:
	if is_dead():
		return

	var guard_to_add: int = max(amount, 0)
	if guard_to_add <= 0:
		return

	var guard_before := current_guard
	current_guard += guard_to_add
	var guard_after := current_guard

	print("%s gains guard: %s -> %s" % [get_display_name(), guard_before, guard_after])

	guard_changed.emit(current_guard)
	guard_gained.emit(self, guard_to_add, guard_before, guard_after)

func heal(amount: int) -> void:
	if is_dead():
		return

	var heal_amount: int = max(amount, 0)
	if heal_amount <= 0:
		return

	current_hp = min(current_hp + heal_amount, stats.max_hp)
	hp_changed.emit(current_hp, stats.max_hp)

func reset_guard() -> void:
	var guard_before := current_guard

	current_guard = get_base_guard()

	if guard_before != current_guard:
		print("%s guard reset: %s -> %s" % [get_display_name(), guard_before, current_guard])

	guard_changed.emit(current_guard)
	guard_reset.emit(self, guard_before, current_guard)

func draw_cards(amount: int) -> void:
	for i in amount:
		if deck.is_empty():
			reshuffle_discard_into_deck()

		if deck.is_empty():
			break

		var drawn_card = deck.pop_front()
		hand.append(drawn_card)

	hand_changed.emit(hand)
	deck_changed.emit(deck.size(), discard_pile.size())

func discard_card(card) -> void:
	if not hand.has(card):
		return

	hand.erase(card)
	discard_pile.append(card)

	hand_changed.emit(hand)
	deck_changed.emit(deck.size(), discard_pile.size())

func discard_hand() -> void:
	for card in hand:
		discard_pile.append(card)

	hand.clear()

	hand_changed.emit(hand)
	deck_changed.emit(deck.size(), discard_pile.size())

func reshuffle_discard_into_deck() -> void:
	if discard_pile.is_empty():
		return

	deck = discard_pile.duplicate()
	discard_pile.clear()
	deck.shuffle()

	deck_changed.emit(deck.size(), discard_pile.size())

func is_dead() -> bool:
	return current_hp <= 0

func get_display_name() -> String:
	if self is EnemyCombatant:
		return (self as EnemyCombatant).enemy_name

	if self is PlayerCombatant:
		return "Player"

	return name

func get_power() -> int:
	return stats.power

func get_base_guard() -> int:
	if stats == null:
		return 0

	return stats.guard

func get_guard_bonus() -> int:
	return stats.guard

func get_dice_count() -> int:
	return stats.dice_count

func get_control() -> int:
	return stats.control

func get_luck() -> int:
	return stats.luck

func _create_dice_pool() -> void:
	dice_pool = DicePool.new()
	add_child(dice_pool)

	dice_pool.create_dice_pool(get_dice_count())

func roll_dice() -> void:
	if dice_pool == null:
		_create_dice_pool()

	dice_pool.roll_all()

func get_dice() -> Array[DiceData]:
	if dice_pool == null:
		return []

	return dice_pool.dice

func get_available_dice() -> Array[DiceData]:
	if dice_pool == null:
		return []

	return dice_pool.get_available_dice()

func _emit_all_state_changes() -> void:
	hp_changed.emit(current_hp, stats.max_hp)
	guard_changed.emit(current_guard)
	hand_changed.emit(hand)
	deck_changed.emit(deck.size(), discard_pile.size())
