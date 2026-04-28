extends Node
class_name Combatant

# Base class for players and enemies.
# Both inherit from this.

# Handles combat logic:
# - HP
# - Guard
# - Taking Damage
# - Healing
# - Death Checks
# - Deck
# - Hand
# - Discard Pile

signal hp_changed(current_hp: int, max_hp: int)
signal guard_changed(current_guard: int)
signal hand_changed(hand: Array)
signal deck_changed(deck_count: int, discard_count: int)
signal died(combatant: Combatant)

var stats: CharacterStats

var current_hp: int = 0
var current_guard: int = 0

var dice_pool: DicePool

var deck: Array = []
var hand: Array = []
var discard_pile: Array = []

func setup(new_stats: CharacterStats, starting_deck: Array) -> void:
	# Duplicate stats so combatant owns its own copy.
	stats = new_stats.duplicate_stats()
	
	current_hp = stats.max_hp
	current_guard = 0
	
	# Duplicate the deck so we do not edit the original card list
	deck = starting_deck.duplicate()
	deck.shuffle()	
	
	hand.clear()
	discard_pile.clear()
	
	_create_dice_pool()
	
	_emit_all_state_changes()

func take_damage(amount: int) -> void:
	# Damage should never be negative.
	var incoming_damage: int = max(amount, 0)
	
	var blocked_damage: int = min(current_guard, incoming_damage)
	
	current_guard -= blocked_damage
	var remaining_damage: int = incoming_damage - blocked_damage
	
	current_hp = max(current_hp - remaining_damage, 0)
	
	if is_dead():
		died.emit(self)

func gain_guard(amount: int) -> void:
	# Guard gain should never be negative.
	var guard_to_add: int = max(amount, 0)
	
	current_guard += guard_to_add
	guard_changed.emit(current_guard)

func heal(amount: int) -> void:
	# Healing should never be negative.
	var heal_amount: int = max(amount, 0)
	
	current_hp = min(current_hp + heal_amount, stats.max_hp)
	hp_changed.emit(current_hp, stats.max_hp)

func reset_guard() -> void:
	# Guard usually resets at the start or end of turns.
	current_guard = 0
	guard_changed.emit(current_guard)

func draw_cards(amount: int) -> void:
	# Draws one card at a time.
	# If the deck is empty, reshuffle the discard pile into the deck.
	for i in amount:
		if deck.is_empty():
			reshuffle_discard_into_deck()
		
		# If both deck and discard are empty, stop drawing.
		if deck.is_empty():
			break
		
		var drawn_card = deck.pop_front()
		hand.append(drawn_card)
	
	hand_changed.emit(hand)
	deck_changed.emit(deck.size(), discard_pile.size())

func discard_card(card) -> void:
	# Move card from hand to discard pile.
	if not hand.has(card):
		return
	
	hand.erase(card)
	discard_pile.append(card)
	
	hand_changed.emit(hand)
	deck_changed.emit(deck.size(), discard_pile.size())

func discard_hand() -> void:
	# Move full hand to discard pile.
	for card in hand:
		discard_pile.append(card)
	
	hand.clear()
	
	hand_changed.emit(hand)
	deck_changed.emit(deck.size(), discard_pile.size())

func reshuffle_discard_into_deck() -> void:
	# Move all discard cards back into the deck, then shuffle.
	if discard_pile.is_empty():
		return
	
	deck = discard_pile.duplicate()
	discard_pile.clear()
	deck.shuffle()
	
	deck_changed.emit(deck.size(), discard_pile.size())

func is_dead() -> bool:
	return current_hp <= 0

func get_power() -> int:
	return stats.power

func get_guard_bonus() -> int:
	return stats.guard

func get_dice_count() -> int:
	return stats.dice_count

func get_control() -> int:
	return stats.control

func get_luck() -> int:
	return stats.luck

func _create_dice_pool() -> void:
	# Creates a DicePool node owned by this combatant.
	dice_pool = DicePool.new()
	add_child(dice_pool)
	
	dice_pool.create_dice_pool(get_dice_count())

func roll_dice() -> void:
	# Rolls all dice owned by this combatant.
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
	# Helper function used after setup so UI can refresh everything.
	hp_changed.emit(current_hp, stats.max_hp)
	guard_changed.emit(current_guard)
	hand_changed.emit(hand)
	deck_changed.emit(deck.size(), discard_pile.size())
