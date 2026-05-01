extends Node
class_name RunState

# RunState persists player progression across locations and combat.
# It is created once by RunManager and passed into every location and combat scene.

var player_data: CombatantData
var current_hp: int = 0
var max_hp: int = 0
var deck: Array[CardData] = []
var used_interactable_ids: Dictionary = {}
var completed_nodes: int = 0

# Permanent run modifiers — accumulate over the run.
var max_hp_modifier: int = 0
var power_modifier: int = 0
var guard_modifier: int = 0
var control_modifier: int = 0
var luck_modifier: int = 0
var dice_count_modifier: int = 0


func setup_from_player_data(data: CombatantData) -> void:
	player_data = data

	if player_data == null:
		push_error("RunState: missing player data.")
		return

	if player_data.stats == null:
		push_error("RunState: player data is missing stats.")
		return

	max_hp = player_data.stats.max_hp
	current_hp = max_hp
	deck.clear()

	for card in player_data.starting_deck:
		deck.append(card)


func apply_to_player_combatant(player: PlayerCombatant) -> void:
	if player == null:
		return

	player.stats.max_hp += max_hp_modifier
	player.stats.power += power_modifier
	player.stats.guard += guard_modifier
	player.stats.control += control_modifier
	player.stats.luck += luck_modifier
	player.stats.dice_count += dice_count_modifier

	player.stats.max_hp = max(player.stats.max_hp, 1)
	player.stats.dice_count = max(player.stats.dice_count, 1)

	current_hp = min(current_hp, player.stats.max_hp)
	player.current_hp = clamp(current_hp, 0, player.stats.max_hp)
	player.hp_changed.emit(player.current_hp, player.stats.max_hp)


func save_from_player_combatant(player: PlayerCombatant) -> void:
	if player == null:
		return

	current_hp = player.current_hp
	max_hp = player.stats.max_hp


func add_card(card: CardData) -> void:
	if card == null:
		return
	deck.append(card)
	print("RunState: added card '%s'. Deck size: %s" % [card.card_name, deck.size()])


func heal(amount: int) -> void:
	current_hp = min(current_hp + max(amount, 0), max_hp)
	print("RunState: healed %s. HP now %s / %s" % [amount, current_hp, max_hp])


func has_used_interactable(interactable_id: String) -> bool:
	if interactable_id == "":
		return false
	return used_interactable_ids.has(interactable_id)


func mark_interactable_used(interactable_id: String) -> void:
	if interactable_id == "":
		return
	used_interactable_ids[interactable_id] = true


func is_dead() -> bool:
	return current_hp <= 0
