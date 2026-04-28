extends Node
class_name DicePool

# DicePool manages all dice rolled by one combatant.
#
# It does not decide what cards to play.
# It only handles:
# - creating dice
# - rolling dice
# - assigning dice
# - clearing dice

signal dice_rolled(dice: Array[DiceData])
signal dice_changed(dice: Array[DiceData])

var dice: Array[DiceData] = []

func create_dice_pool(dice_count: int) -> void:
	# Clears any old dice before creating the new pool
	dice.clear()
	
	# Create the number of dice this combatant should roll.
	for i in dice_count:
		var new_die := DiceData.new()
		dice.append(new_die)
	
	dice_changed.emit(dice)

func roll_all() -> void:
	# Roll every die in pool.
	for die in dice:
		die.roll()
	
	dice_rolled.emit(dice)
	dice_changed.emit(dice)

func get_available_dice() -> Array[DiceData]:
	# Returns only dice that have not been assigned yet.
	var available_dice: Array[DiceData] = []
	
	for die in dice:
		if die.can_be_used():
			available_dice.append(die)
	
	return available_dice

func assign_die(die: DiceData) -> bool:
	# Attempts to assign a die.
	# Returns true if successful.
	if die == null:
		return false

	if not dice.has(die):
		return false

	if not die.can_be_used():
		return false

	die.assign()
	dice_changed.emit(dice)

	return true

func unassign_die(die: DiceData) -> void:
	if die == null:
		return

	if not dice.has(die):
		return

	die.unassign()
	dice_changed.emit(dice)

func clear_assignments() -> void:
	# Makes all dice available again.
	for die in dice:
		die.unassign()
	
	dice_changed.emit(dice)	

func clear_dice() -> void:
	# Removes all dice from the pool.
	dice.clear()
	dice_changed.emit(dice)

func has_enough_available_dice(amount: int) -> bool:
	return get_available_dice().size() >= amount
