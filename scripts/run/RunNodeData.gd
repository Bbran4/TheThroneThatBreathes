extends Resource
class_name RunNodeData

enum RunNodeType {
	STORY,
	CHOICE,
	COMBAT,
	ELITE,
	BOSS
}

@export var node_name: String = "Unknown Node"
@export var node_type: RunNodeType = RunNodeType.CHOICE

@export_multiline var scene_text: String = ""

# Optional combat for this node.
@export var enemy_team_data: Array[CombatantData] = []

# Choices shown to the player.
@export var choices: Array[RunChoiceData] = []

# Combat rewards if this node is combat.
@export var reward_cards: Array[CardData] = []
