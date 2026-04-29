extends Node
class_name RunState

var player_data: CombatantData
var current_hp: int = 0
var max_hp: int = 0
var deck: Array[CardData] = []

var completed_nodes: int = 0

var max_hp_modifier: int = 0
var power_modifier: int = 0
var guard_modifier: int = 0
var control_modifier: int = 0
var luck_modifier: int = 0
var dice_count_modifier: int = 0


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

func apply_choice(choice: RunChoiceData) -> void:
	if choice == null:
		print("Tried to apply null choice.")
		return

	print("Applying run choice: ", choice.choice_text)

	if choice.heal_amount > 0:
		print("Healing: ", choice.heal_amount)
		heal(choice.heal_amount)

	if choice.card_reward != null:
		print("Reward card from choice: ", choice.card_reward.card_name)
		add_card(choice.card_reward)

	max_hp_modifier += choice.max_hp_modifier
	power_modifier += choice.power_modifier
	guard_modifier += choice.guard_modifier
	control_modifier += choice.control_modifier
	luck_modifier += choice.luck_modifier
	dice_count_modifier += choice.dice_count_modifier

	print("Run modifiers now: Guard ", guard_modifier, " Power ", power_modifier)
	print("Run deck size now: ", deck.size())


func add_card(card: CardData) -> void:
	if card == null:
		print("Tried to add null card.")
		return

	print("Added card to run deck: ", card.card_name)
	deck.append(card)

func heal(amount: int) -> void:
	current_hp = min(current_hp + max(amount, 0), max_hp)


func is_dead() -> bool:
	return current_hp <= 0
