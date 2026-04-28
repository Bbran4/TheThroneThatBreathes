extends Resource
class_name DiceData

# Represents a single die during combat.
# For now, dice are simple, 1 to 6.
# They can be assigned to cards.

@export var sides: int = 6

var current_value: int = 1
var is_assigned: bool = false

func roll() -> int:
	# Roll random number between 1 and the number of sides
	current_value = randi_range(1, sides)
	
	# A newly rolled die should be available for use
	is_assigned = false
	
	return current_value

func assign() -> void:
	# Marks this die to be used by a card.
	is_assigned = true

func unassigned() -> void:
	# Marks this die available again.
	is_assigned = false

func can_be_used() -> bool:
	# A die can only be used if it has not already been assigned.
	return not is_assigned

func get_display_text() -> String:
	return str(current_value)
