extends Resource
class_name CardData

# A card should describe:
# - what it is called
# - what it does
# - what kind of die it needs

enum CardType {
	ATTACK,
	GUARD,
	SKILL,
	SPELL
}

enum DiceRequirementType {
	ANY,
	MINIMUM_VALUE,
	EXACT_VALUE,
	EVEN,
	ODD
}

enum CardEffectType {
	NORMAL,
	REROLL_DIE
}

@export var card_art: Texture2D

@export var card_name: String = "Unnamed Card"

@export_multiline var description: String = ""

@export var flavor_text: String = ""

@export var card_type: CardType = CardType.ATTACK

# How many dic must be assigned to this card.
# Most simple cards will need 1 die
@export var dice_required: int = 1

# Defines what kind of die value this card accepts.
@export var dice_requirement_type: DiceRequirementType = DiceRequirementType.ANY

# Used when a card requires a minimum value or exact value.
@export var required_die_value: int = 1
@export var effect_type: CardEffectType = CardEffectType.NORMAL
# Base combat values.
@export var base_damage: int = 0
@export var base_guard: int = 0
@export var cards_to_draw: int = 0

# Optional flags for future design.
@export var exhausts_after_use: bool = false
@export var can_target_enemy: bool = false
@export var can_target_self: bool = false

func can_use_with_die(die_value: int) -> bool:
	# Checks whether a single die is valid for a card.
	
	match dice_requirement_type:
		DiceRequirementType.ANY:
			return true
		
		DiceRequirementType.MINIMUM_VALUE:
			return die_value >= required_die_value
		
		DiceRequirementType.EXACT_VALUE:
			return die_value == required_die_value
		
		DiceRequirementType.EVEN:
			return die_value % 2 == 0
		
		DiceRequirementType.ODD:
			return die_value % 2 != 0
	
	return false

func can_use_with_dice(assigned_dice: Array[DiceData]) -> bool:
	# First check if the card received enough dice.
	if assigned_dice.size() < dice_required:
		return false

	# Every assigned die must satisfy this card's requirement.
	for die in assigned_dice:
		if die == null:
			return false

		if not can_use_with_die(die.current_value):
			return false

	return true

func get_final_damage(user: Combatant) -> int:
	# Only cards with base damage should scale with Power.
	# This prevents non-attack cards like Guard from becoming damage cards.
	if base_damage <= 0:
		return 0

	return base_damage + user.get_power()

func get_final_guard(user: Combatant) -> int:
	return base_guard + user.get_guard_bonus()

func get_display_text() -> String:
	return card_name + "\n" + description

func _to_string() -> String:
	return card_name
