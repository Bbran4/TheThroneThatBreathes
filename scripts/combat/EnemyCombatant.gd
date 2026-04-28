extends Combatant
class_name EnemyCombatant

signal intent_changed(intent_text: String)

var enemy_name: String = "Enemy"
var selected_card: CardData = null
var selected_dice: Array[DiceData] = []


func setup_enemy(new_name: String, new_stats: CharacterStats, starting_deck: Array) -> void:
	enemy_name = new_name
	setup(new_stats, starting_deck)

	selected_card = null
	selected_dice.clear()


func prepare_intent() -> void:
	# Enemy chooses what it wants to do next.
	# This does NOT resolve the card yet.

	selected_card = null
	selected_dice.clear()

	if hand.is_empty():
		intent_changed.emit("No action")
		return

	for card in hand:
		var usable_dice := _find_usable_dice_for_card(card)

		if card.can_use_with_dice(usable_dice):
			selected_card = card
			selected_dice = usable_dice
			intent_changed.emit(_get_intent_text(card))
			return

	intent_changed.emit("No playable card")


func get_selected_card() -> CardData:
	return selected_card


func get_selected_dice() -> Array[DiceData]:
	return selected_dice


func clear_selected_card() -> void:
	selected_card = null
	selected_dice.clear()
	intent_changed.emit("")


func _find_usable_dice_for_card(card: CardData) -> Array[DiceData]:
	var usable_dice: Array[DiceData] = []

	for die in get_available_dice():
		if card.can_use_with_die(die.current_value):
			usable_dice.append(die)

			if usable_dice.size() >= card.dice_required:
				break

	return usable_dice


func _get_intent_text(card: CardData) -> String:
	var damage_amount := card.get_final_damage(self)
	var guard_amount := card.get_final_guard(self)

	if damage_amount > 0 and card.can_target_enemy:
		return "Intent: Attack " + str(damage_amount)

	if guard_amount > 0:
		return "Intent: Guard " + str(guard_amount)

	return "Intent: " + card.card_name
