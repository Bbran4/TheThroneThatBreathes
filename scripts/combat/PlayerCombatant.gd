extends Combatant
class_name PlayerCombatant

# This class is only for player-specific decision-making.
# - selecting cards
# - assigning dice
# - confirming actions

var selected_card = null

func select_card(card) -> void:
	# The player can only select cards currently in hand.
	if not hand.has(card):
		selected_card = null
		return
	
	selected_card = null

func clear_selected_card() -> void:
	selected_card = null

func get_selected_card():
	return selected_card
