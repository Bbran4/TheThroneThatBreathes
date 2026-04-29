extends Node
class_name RunState

var player_data: CombatantData
var current_hp: int = 0
var max_hp: int = 0
var deck: Array[CardData] = []

var completed_nodes: int = 0


func setup_from_player_data(data: CombatantData) -> void:
	player_data = data

	if player_data == null:
		push_error("RunState setup failed: missing player data.")
		return

	if player_data.stats == null:
		push_error("RunState setup failed: player data is missing stats.")
		return

	max_hp = player_data.stats.max_hp
	current_hp = max_hp
	deck.clear()

	for card in player_data.starting_deck:
		deck.append(card)


func apply_to_player_combatant(player: PlayerCombatant) -> void:
	if player == null:
		return

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


func heal(amount: int) -> void:
	current_hp = min(current_hp + max(amount, 0), max_hp)


func is_dead() -> bool:
	return current_hp <= 0
