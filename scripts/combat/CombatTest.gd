extends Node

# CombatTest is a temporary scene controller.
#
# Its job is to create a playable test combat quickly.
# Later, this will be replaced by proper scene loading,
# character selection, enemy spawning, and UI.

@export var player_stats: CharacterStats
@export var enemy_stats: CharacterStats

@export var player_deck: Array[CardData]
@export var enemy_deck: Array[CardData]

@onready var combat_manager: CombatManager = $CombatManager
@onready var player: PlayerCombatant = $PlayerCombatant
@onready var enemy: EnemyCombatant = $EnemyCombatant
@onready var combat_ui: CombatUI = $CanvasLayer/CombatUI

func _ready() -> void:
	# Validate exported data before starting combat.
	# This helps catch missing resources early.
	if player_stats == null:
		push_error("CombatTest is missing player_stats.")
		return

	if enemy_stats == null:
		push_error("CombatTest is missing enemy_stats.")
		return

	if player_deck.is_empty():
		push_error("CombatTest is missing player_deck.")
		return

	if enemy_deck.is_empty():
		push_error("CombatTest is missing enemy_deck.")
		return

	# Setup combatants first.
	player.setup(player_stats, player_deck)
	enemy.setup_enemy("Rot Wolf", enemy_stats, enemy_deck)

	# Then setup the manager.
	combat_manager.setup_combat(player, enemy)
	combat_ui.setup_ui(combat_manager, player, enemy)
	
	# Connect useful debug signals.
	combat_manager.combat_started.connect(_on_combat_started)
	combat_manager.player_turn_started.connect(_on_player_turn_started)
	combat_manager.enemy_turn_started.connect(_on_enemy_turn_started)
	combat_manager.combat_ended.connect(_on_combat_ended)

	player.hp_changed.connect(_on_player_hp_changed)
	enemy.hp_changed.connect(_on_enemy_hp_changed)

	player.hand_changed.connect(_on_player_hand_changed)
	player.dice_pool.dice_rolled.connect(_on_player_dice_rolled)

	# Start the test combat.
	combat_manager.start_combat()


func _on_combat_started() -> void:
	print("Combat started.")


func _on_player_turn_started() -> void:
	print("--- Player Turn ---")
	print("Player HP: ", player.current_hp)
	print("Enemy HP: ", enemy.current_hp)
	print("Player hand: ", player.hand)
	print("Player dice: ", _dice_values_to_text(player.get_dice()))


func _on_enemy_turn_started() -> void:
	print("--- Enemy Turn ---")


func _on_combat_ended(winner: Combatant) -> void:
	if winner == player:
		print("Combat ended. Player wins.")
	else:
		print("Combat ended. Enemy wins.")


func _on_player_hp_changed(current_hp: int, max_hp: int) -> void:
	print("Player HP changed: ", current_hp, "/", max_hp)


func _on_enemy_hp_changed(current_hp: int, max_hp: int) -> void:
	print("Enemy HP changed: ", current_hp, "/", max_hp)


func _on_player_hand_changed(hand: Array) -> void:
	print("Player hand size: ", hand.size())


func _on_player_dice_rolled(dice: Array[DiceData]) -> void:
	print("Player rolled: ", _dice_values_to_text(dice))


func _dice_values_to_text(dice: Array[DiceData]) -> String:
	var values: Array[String] = []

	for die in dice:
		values.append(str(die.current_value))

	return ", ".join(values)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_play_card"):
		_try_play_first_card()
		return

	if event.is_action_pressed("debug_end_turn"):
		combat_manager.end_player_turn()
		return


func _try_play_first_card() -> void:
	if not combat_manager.is_player_turn:
		print("Cannot play card. It is not the player's turn.")
		return

	if player.hand.is_empty():
		print("No cards in hand.")
		return

	var card: CardData = player.hand[0]
	var assigned_dice: Array[DiceData] = []

	for die in player.get_available_dice():
		if card.can_use_with_die(die.current_value):
			assigned_dice.append(die)

			if assigned_dice.size() >= card.dice_required:
				break

	print("Trying to play: ", card.card_name)
	print("Assigned dice: ", _dice_values_to_text(assigned_dice))

	var success := combat_manager.play_player_card(card, assigned_dice)

	if success:
		print("Played card: ", card.card_name)
		print("Enemy HP now: ", enemy.current_hp)
	else:
		print("Could not play card: ", card.card_name)
