extends Resource
class_name LocationData

enum LocationType {
	ROAD,
	RUIN,
	CAVE,
	VILLAGE,
	SHRINE,
	GATE
}

@export var location_name: String = "Unknown Location"
@export var location_type: LocationType = LocationType.ROAD

@export_multiline var description: String = ""

@export var background_art: Texture2D
@export var entry_node: RunNodeData

@export var side_view_scene: PackedScene

@export var connected_locations: Array[LocationData] = []

@export var entry_roll_difficulty: int = 0
@export var rot_pressure: int = 0
