extends Resource
class_name RunNodeData

enum RunNodeType {
	COMBAT,
	EVENT,
	ELITE,
	BOSS
}

@export var node_name: String = "Unknown Node"
@export var node_type: RunNodeType = RunNodeType.COMBAT
@export_multiline var description: String = ""

@export var enemy_team_data: Array[CombatantData] = []

@export var reward_cards: Array[CardData] = []
@export var heal_amount: int = 0
