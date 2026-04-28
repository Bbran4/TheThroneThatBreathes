extends Combatant
class_name PlayerCombatant

var selected_card: CardData = null

func select_card(card: CardData) -> void:
	if card == null:
		selected_card = null
		return

	if not hand.has(card):
		selected_card = null
		return

	selected_card = card

func clear_selected_card() -> void:
	selected_card = null

func get_selected_card() -> CardData:
	return selected_card
