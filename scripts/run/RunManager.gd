extends Node
class_name RunManager

# RunManager is the top-level orchestrator.
# It owns the RunState and transitions between:
#   - SideViewLocation scenes (exploration)
#   - CombatScene (combat)
#   - WorldMap (decorative overlay)
#
# It does NOT contain game logic. It only swaps scenes and passes state.

@export var player_data: CombatantData
@export var starting_location: PackedScene
@export var combatant_status_ui_scene: PackedScene

# Map reference — always present in the scene tree, shown/hidden as needed.
@onready var world_map: WorldMap = $WorldMap

var run_state: RunState

var active_location: SideViewLocation = null
var active_combat: CombatScene = null

var post_combat_return_location: PackedScene = null


func _ready() -> void:
	if player_data == null:
		push_error("RunManager: player_data not assigned.")
		return

	run_state = RunState.new()
	add_child(run_state)
	run_state.setup_from_player_data(player_data)

	world_map.visible = false

	if starting_location != null:
		_enter_location(starting_location)


# --- Location ---

func _enter_location(location_scene: PackedScene) -> void:
	_cleanup_active_location()
	_cleanup_active_combat()

	if location_scene == null:
		push_error("RunManager: tried to enter a null location.")
		return

	active_location = location_scene.instantiate() as SideViewLocation

	if active_location == null:
		push_error("RunManager: location scene does not extend SideViewLocation.")
		return

	add_child(active_location)
	active_location.setup(run_state)

	active_location.location_travel_requested.connect(_on_travel_requested)
	active_location.location_combat_requested.connect(_on_combat_requested)
	active_location.location_exit_requested.connect(_on_location_exit_requested)

	# Update the map highlight.
	if world_map != null:
		world_map.set_current_location(location_scene)


func _cleanup_active_location() -> void:
	if active_location != null and is_instance_valid(active_location):
		active_location.queue_free()
	active_location = null


# --- Combat ---

func _enter_combat(combat_scene_packed: PackedScene, return_to: PackedScene) -> void:
	_cleanup_active_location()
	_cleanup_active_combat()

	post_combat_return_location = return_to

	active_combat = combat_scene_packed.instantiate() as CombatScene

	if active_combat == null:
		push_error("RunManager: combat scene does not extend CombatScene.")
		return

	var player_team: Array[CombatantData] = [player_data]
	active_combat.setup(player_team, run_state)
	active_combat.combatant_status_ui_scene = combatant_status_ui_scene

	add_child(active_combat)
	active_combat.start()

	active_combat.combat_finished.connect(_on_combat_finished)


func _cleanup_active_combat() -> void:
	if active_combat != null and is_instance_valid(active_combat):
		active_combat.queue_free()
	active_combat = null


# --- Signal handlers ---

func _on_travel_requested(next_location: PackedScene) -> void:
	_enter_location(next_location)


func _on_combat_requested(combat_scene: PackedScene) -> void:
	# Remember where to return after combat.
	var return_scene: PackedScene = null

	if active_location != null:
		# We need the packed scene reference of the current location.
		# Store it before cleanup.
		return_scene = _get_current_location_scene()

	_enter_combat(combat_scene, return_scene)


func _on_location_exit_requested() -> void:
	# The location itself decided the player should leave
	# but didn't specify a destination.
	# For now just reload the same location — extend this as needed.
	push_warning("RunManager: location_exit_requested but no destination set.")


func _on_combat_finished(player_won: bool, surviving_player: PlayerCombatant) -> void:
	if not player_won:
		_handle_player_death()
		return

	if surviving_player != null:
		run_state.save_from_player_combatant(surviving_player)

	# Show reward if the combat scene has reward cards.
	if active_combat != null and not active_combat.reward_cards.is_empty():
		_show_combat_reward(active_combat.reward_cards)
		return

	_return_from_combat()


func _return_from_combat() -> void:
	if post_combat_return_location != null:
		_enter_location(post_combat_return_location)
	else:
		push_warning("RunManager: no return location after combat.")


func _handle_player_death() -> void:
	run_state.current_hp = 0
	print("RunManager: player died. Handle game over here.")
	# Extend this: show game over screen, return to main menu, etc.


func _show_combat_reward(cards: Array[CardData]) -> void:
	# Extend this to show a reward selection UI.
	# For now, auto-grant the first card and return.
	print("RunManager: combat reward available. Implement reward UI here.")
	if cards.size() > 0:
		run_state.add_card(cards[0])
	_return_from_combat()


# --- Map ---

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("open_map"):
		_toggle_map()


func _toggle_map() -> void:
	if world_map == null:
		return

	if world_map.visible:
		world_map.visible = false
	else:
		world_map.open()


# --- Helpers ---

func _get_current_location_scene() -> PackedScene:
	# We store a reference on the location node itself at enter time.
	if active_location != null and active_location.has_meta("source_scene"):
		return active_location.get_meta("source_scene") as PackedScene
	return null
