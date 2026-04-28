extends Resource
class_name CharacterStats

@export var max_hp: int = 30

# Number of dice this character rolls each turn.
@export var dice_count: int = 3

# Increases damage dealt by cards and attacks.
@export var power: int = 0

# Improves defensive cards and guard gain.
@export var guard: int = 0

# Used later for rerolls, dice manipulation, and consistency.
@export var control: int = 0

# Used later for rare outcomes, event rolls, and loot chances.
@export var luck: int = 0

func duplicate_stats() -> CharacterStats:
	# Resources can be shared between multiple objects.
	# We duplicate stats so changing one combatant's runtime values
	# does no accidentally change another combatant.
	return duplicate(true)
