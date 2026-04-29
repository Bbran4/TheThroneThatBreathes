extends Resource
class_name RunChoiceData

enum ChoiceEffectType {
	NONE,
	HEAL,
	ADD_CARD,
	ADD_CURSE_STAT,
	COMBAT,
	GO_TO_NODE
}

@export var choice_text: String = "Continue"
@export_multiline var result_text: String = ""

@export var effect_type: ChoiceEffectType = ChoiceEffectType.NONE

@export var heal_amount: int = 0

@export var card_reward: CardData

# Permanent stat changes for the run.
@export var max_hp_modifier: int = 0
@export var power_modifier: int = 0
@export var guard_modifier: int = 0
@export var control_modifier: int = 0
@export var luck_modifier: int = 0
@export var dice_count_modifier: int = 0

# Optional next node.
# If empty, RunTest proceeds to the next node in sequence.
@export var next_node: RunNodeData
