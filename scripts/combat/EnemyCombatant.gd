extends Combatant
class_name EnemyCombatant

# EnemyCombatant uses the same deck, hand, and discard systems
# as the player.
#
# The difference is that enemies choose cards using AI logic.

signal intent_changed(intent_text: String)

var enemy_name: String = "Enemy"
var selected_card = null

func setup_enemy(new_name: String, new_stats: CharacterStats, starting_deck: Array) -> void:
	enemy_name = new_name
	
	setup(new_stats, starting_deck)
	
	selected_card = null

func choose_card() -> void:
	# Simple enemy AI:
	# Choose the first card in hand.
	#
	# Later this can become smarter:
	# - pick highest damage card
	# - defend when low HP
	# - choose based on dice results
	# - follow enemy personality rules
	
	if hand.is_empty():
		selected_card = null
		intent_changed.emit("No action")
		return
	
	selected_card = hand[0]
	intent_changed.emit("Preparing " + str(selected_card))

func clear_selected_card() -> void:
	selected_card = null
	intent_changed.emit("")

func get_selected_card():
	return selected_card
