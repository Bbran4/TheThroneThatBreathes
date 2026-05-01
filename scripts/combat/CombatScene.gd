extends Node
class_name CombatScene

# CombatScene is the universal combat template.
# Every combat encounter uses this same scene/script.
# Configure each encounter by setting these exports in the Inspector
# (or by duplicating the scene and changing the values).
#
# enemy_team      — which enemies appear
# background      — the battlefield background texture
# player_slots    — how many player slots to show (future multi-character support)

signal combat_finished(player_won: bool, surviving_player: PlayerCombatant)

@export var enemy_team: Array[CombatantData] = []
@export var background_texture: Texture2D = null
@export var player_slot_count: int = 1

# Optionally override reward cards for this specific encounter.
# If empty, the run flow handles rewards.
@export var reward_cards: Array[CardData] = []

@onready var combat_manager: CombatManager = $CombatManager
@onready var combat_ui: CombatUI = $CanvasLayer/CombatUI
@onready var player_slots: Node2D = $Battlefield/PlayerSlots
@onready var enemy_slots: Node2D = $Battlefield/EnemySlots
@onready var background_sprite: Sprite2D = $Battlefield/Background
@export var combatant_status_ui_scene: PackedScene

@export var status_ui_y_offset: float = 90.0
@export var status_ui_x_offset: float = 0.0

var players: Array[PlayerCombatant] = []
var enemies: Array[EnemyCombatant] = []
var combatant_visuals: Dictionary = {}
var combatant_status_uis: Dictionary = {}

var run_state: RunState = null
var player_team_data: Array[CombatantData] = []


func _ready() -> void:
	if background_texture != null and background_sprite != null:
		background_sprite.texture = background_texture

	_enforce_slot_visibility()


func _enforce_slot_visibility() -> void:
	# Hide player slots beyond the configured count.
	for i in player_slots.get_child_count():
		var slot := player_slots.get_child(i)
		slot.visible = i < player_slot_count


# Called by RunManager before adding to the scene tree.
func setup(new_player_team: Array[CombatantData], new_run_state: RunState) -> void:
	player_team_data = new_player_team
	run_state = new_run_state


func start() -> void:
	if player_team_data.is_empty():
		push_error("CombatScene: no player team data set.")
		return

	if enemy_team.is_empty():
		push_error("CombatScene: no enemy team assigned in Inspector.")
		return

	_spawn_player_team()
	_spawn_enemy_team()

	combat_manager.setup_combat(players, enemies)
	combat_ui.setup_ui(combat_manager, players, enemies)
	combat_ui.show_builtin_result_panel = false
	combat_ui.setup_target_buttons(combatant_visuals)

	combat_ui.floating_text_requested.connect(_on_floating_text_requested)
	combat_ui.target_selected.connect(func(_t): _update_target_visuals())
	combat_ui.pending_card_changed.connect(func(_c): _update_target_visuals())

	combat_manager.combat_started.connect(_on_combat_started)
	combat_manager.player_turn_started.connect(_on_player_turn_started)
	combat_manager.enemy_turn_started.connect(_on_enemy_turn_started)
	combat_manager.combat_ended.connect(_on_combat_ended)
	combat_manager.combat_log.connect(func(msg): print(msg))
	combat_manager.card_resolved.connect(_on_card_resolved)

	for combatant in players + enemies:
		combatant.died.connect(_on_combatant_died)
		combatant.damage_taken.connect(_on_combatant_damage_taken)
		combatant.guard_gained.connect(_on_combatant_guard_gained)

	combat_manager.start_combat()


func _process(_delta: float) -> void:
	if combat_ui != null:
		combat_ui.refresh_target_buttons(combatant_visuals)

	_update_status_ui_positions()


func _update_status_ui_positions() -> void:
	var dead_entries: Array[Combatant] = []

	for combatant in combatant_status_uis.keys():
		var entry: Dictionary = combatant_status_uis[combatant]
		var status_ui: Control = entry["ui"]
		var visual: Node2D = entry["visual"]

		if not is_instance_valid(combatant) or not is_instance_valid(status_ui) or not is_instance_valid(visual):
			dead_entries.append(combatant)
			continue

		if combatant.is_dead():
			status_ui.visible = false
			dead_entries.append(combatant)
			continue

		var screen_pos := visual.get_global_transform_with_canvas().origin
		var status_width : Variant = max(status_ui.size.x, status_ui.custom_minimum_size.x)
		status_ui.global_position = screen_pos + Vector2(-status_width * 0.5 + status_ui_x_offset, status_ui_y_offset)
		status_ui.visible = true

	for c in dead_entries:
		combatant_status_uis.erase(c)


# --- Spawning ---

func _spawn_player_team() -> void:
	players.clear()

	for i in player_team_data.size():
		if i >= player_slots.get_child_count():
			break

		var data := player_team_data[i]
		var combatant := PlayerCombatant.new()
		add_child(combatant)
		combatant.name = "PlayerCombatant_%s" % i
		combatant.setup(data.stats, data.starting_deck)

		if run_state != null:
			_apply_run_state_to_player(combatant)

		players.append(combatant)
		_spawn_visual(combatant, data, player_slots, i)


func _apply_run_state_to_player(combatant: PlayerCombatant) -> void:
	if run_state.deck.size() > 0:
		var run_deck: Array[CardData] = []
		for card in run_state.deck:
			run_deck.append(card)
		combatant.deck = run_deck
		combatant.deck.shuffle()
		combatant.hand.clear()
		combatant.discard_pile.clear()
		combatant.hand_changed.emit(combatant.hand)
		combatant.deck_changed.emit(combatant.deck.size(), combatant.discard_pile.size())

	run_state.apply_to_player_combatant(combatant)


func _spawn_enemy_team() -> void:
	enemies.clear()

	for i in enemy_team.size():
		if i >= enemy_slots.get_child_count():
			push_error("CombatScene: not enough enemy slots for enemy team size %s." % enemy_team.size())
			break

		var data := enemy_team[i]
		var combatant := EnemyCombatant.new()
		add_child(combatant)
		combatant.name = "EnemyCombatant_%s" % i
		combatant.setup_enemy(data.display_name, data.stats, data.starting_deck)

		enemies.append(combatant)
		_spawn_visual(combatant, data, enemy_slots, i)


func _spawn_visual(combatant: Combatant, data: CombatantData, slot_parent: Node2D, index: int) -> void:
	if index >= slot_parent.get_child_count():
		push_error("CombatScene: not enough slots in %s." % slot_parent.name)
		return

	var slot := slot_parent.get_child(index)
	var visual: CombatantVisual

	if data.combat_visual_scene != null:
		visual = data.combat_visual_scene.instantiate() as CombatantVisual
	else:
		push_error("CombatScene: %s has no combat_visual_scene." % data.display_name)
		return

	visual.name = combatant.get_display_name() + "_Visual"
	slot.add_child(visual)
	combatant_visuals[combatant] = visual

	_spawn_status_ui(combatant, visual)


func _spawn_status_ui(combatant: Combatant, visual: CombatantVisual) -> void:
	if combatant_status_ui_scene == null:
		return

	var status_ui: CombatantStatusUI = combatant_status_ui_scene.instantiate()
	combat_ui.add_child(status_ui)
	status_ui.setup(combatant)

	combatant_status_uis[combatant] = { "ui": status_ui, "visual": visual }


# --- Combat event handlers ---

func _on_combat_started() -> void:
	print("CombatScene: combat started.")


func _on_player_turn_started() -> void:
	print("CombatScene: player turn.")


func _on_enemy_turn_started() -> void:
	print("CombatScene: enemy turn.")


func _on_combat_ended(winner: Combatant) -> void:
	var player_won := _is_player(winner)

	if player_won:
		print("CombatScene: player wins.")
	else:
		print("CombatScene: enemy wins.")

	var surviving_player: PlayerCombatant = null
	for p in players:
		if p != null and not p.is_dead():
			surviving_player = p
			break

	if surviving_player != null and run_state != null:
		run_state.save_from_player_combatant(surviving_player)

	combat_finished.emit(player_won, surviving_player)


func _on_combatant_died(combatant: Combatant) -> void:
	if combat_ui.selected_target == combatant:
		combat_ui.clear_target()

	if combatant_status_uis.has(combatant):
		var entry: Dictionary = combatant_status_uis[combatant]
		var status_ui: Control = entry["ui"]
		combatant_status_uis.erase(combatant)
		if is_instance_valid(status_ui):
			status_ui.queue_free()

	if combatant_visuals.has(combatant):
		var visual: CombatantVisual = combatant_visuals[combatant]
		combatant_visuals.erase(combatant)
		if is_instance_valid(visual):
			visual.play_death_reaction()

	_update_target_visuals()


func _on_card_resolved(card: CardData, user: Combatant, _target: Combatant, damage_amount: int, guard_amount: int) -> void:
	if not combatant_visuals.has(user):
		return

	var visual: CombatantVisual = combatant_visuals[user]
	if not is_instance_valid(visual):
		return

	if damage_amount > 0 and card.can_target_enemy:
		visual.play_attack(card.animation_name if card.animation_name != "" else "attack_1")
	elif guard_amount > 0:
		visual.play_defend()


func _on_combatant_damage_taken(combatant: Combatant, _incoming: int, _blocked: int, hp_damage: int, _gb: int, _ga: int, _hb: int, _ha: int) -> void:
	if hp_damage > 0 and combatant_visuals.has(combatant):
		combatant_visuals[combatant].play_hit_reaction()


func _on_combatant_guard_gained(combatant: Combatant, _amount: int, _gb: int, _ga: int) -> void:
	if combatant_visuals.has(combatant):
		combatant_visuals[combatant].play_guard_reaction()


func _update_target_visuals() -> void:
	for combatant in combatant_visuals.keys():
		var visual: CombatantVisual = combatant_visuals[combatant]

		if combatant.is_dead():
			continue

		if combat_ui.pending_card == null:
			visual.set_target_state("selected" if combatant == combat_ui.selected_target else "normal")
			continue

		var card := combat_ui.pending_card
		match card.target_mode:
			CardData.TargetMode.SINGLE_ENEMY:
				visual.set_target_state("valid" if combatant is EnemyCombatant else "invalid")
			CardData.TargetMode.SINGLE_ALLY:
				visual.set_target_state("valid" if combatant is PlayerCombatant else "invalid")
			CardData.TargetMode.SLOT_1_AND_RANDOM_OTHER:
				visual.set_target_state("cleave" if combatant is EnemyCombatant else "invalid")
			_:
				visual.set_target_state("normal")


func _on_floating_text_requested(combatant: Combatant, text_value: String, text_kind: String) -> void:
	var spawn_position := Vector2.ZERO

	if combatant_status_uis.has(combatant):
		var entry: Dictionary = combatant_status_uis[combatant]
		var status_ui: CombatantStatusUI = entry["ui"]

		if is_instance_valid(status_ui):
			match text_kind:
				"health":
					spawn_position = status_ui.get_health_floating_text_position()
				"guard":
					spawn_position = status_ui.get_guard_floating_text_position()
				_:
					spawn_position = status_ui.global_position
	else:
		spawn_position = combat_ui.global_position + Vector2(300, 300)

	combat_ui._spawn_floating_text(text_value, spawn_position)


func _is_player(combatant: Combatant) -> bool:
	for p in players:
		if p == combatant:
			return true
	return false
