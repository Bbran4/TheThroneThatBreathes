extends Resource
class_name InteractableOutcome

# InteractableOutcome defines what happens when a player selects
# a choice from an interactable, or triggers a single-outcome interactable.
#
# If an interactable has one outcome, it fires directly.
# If it has multiple outcomes, the player is shown a choice panel.

# The label shown as a button when this is one of multiple choices.
# e.g. "Go East", "Search the bag", "Rest here"
@export var label: String = "Continue"

# Flavour text shown in the result panel after the choice is made.
@export_multiline var result_text: String = ""

# --- Navigation ---
# If set, transitions the player to a new SideViewLocation scene.
@export var next_location: PackedScene = null

# If set, launches a combat encounter.
# The PackedScene should be a CombatScene.tscn instance
# with enemy_team and background already configured.
@export var combat_scene: PackedScene = null

# --- Rewards ---
@export var card_reward: CardData = null
@export var heal_amount: int = 0

# --- Permanent run stat modifiers ---
# Positive values are buffs, negative are curses.
@export var max_hp_modifier: int = 0
@export var power_modifier: int = 0
@export var guard_modifier: int = 0
@export var control_modifier: int = 0
@export var luck_modifier: int = 0
@export var dice_count_modifier: int = 0

func has_navigation() -> bool:
	return next_location != null or combat_scene != null

func has_reward() -> bool:
	return card_reward != null or heal_amount > 0

func has_stat_changes() -> bool:
	return (
		max_hp_modifier != 0 or
		power_modifier != 0 or
		guard_modifier != 0 or
		control_modifier != 0 or
		luck_modifier != 0 or
		dice_count_modifier != 0
	)

func apply_to_run_state(run_state: RunState) -> void:
	if run_state == null:
		return

	if heal_amount > 0:
		run_state.heal(heal_amount)

	if card_reward != null:
		run_state.add_card(card_reward)

	run_state.max_hp_modifier += max_hp_modifier
	run_state.power_modifier += power_modifier
	run_state.guard_modifier += guard_modifier
	run_state.control_modifier += control_modifier
	run_state.luck_modifier += luck_modifier
	run_state.dice_count_modifier += dice_count_modifier
