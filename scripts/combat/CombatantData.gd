extends Resource
class_name CombatantData

# CombatantData defines a playable character or enemy setup.
#
# It connects:
# - name
# - stats
# - starting deck
#
# This means characters and enemies can be created from data,
# instead of manually assigning stats and decks separately.

@export var display_name: String = "Unnamed Combatant"
@export var stats: CharacterStats
@export var starting_deck: Array[CardData] = []
@export var combat_sprite: Texture2D
