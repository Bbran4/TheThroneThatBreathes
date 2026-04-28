extends Node

@export var player_team_data: Array[CombatantData] = []
@export var enemy_team_data: Array[CombatantData] = []

@export var player_combatant_scene: PackedScene
@export var enemy_combatant_scene: PackedScene
@export var combatant_visual_scene: PackedScene
@export var click_size: Vector2 = Vector2(700, 900)

@onready var combat_manager: CombatManager = $CombatManager
@onready var combat_ui: CombatUI = $CanvasLayer/CombatUI
@onready var player_slots: Node2D = $Battlefield/PlayerSlots
@onready var enemy_slots: Node2D = $Battlefield/EnemySlots
@export var combatant_status_ui_scene: PackedScene

var players: Array[PlayerCombatant] = []
var enemies: Array[EnemyCombatant] = []
var combatant_visuals: Dictionary = {}
var combatant_status_uis: Dictionary = {}

func _ready() -> void:
	if not _validate_team_data(player_team_data, "Player team"):
		return

	if not _validate_team_data(enemy_team_data, "Enemy team"):
		return

	_spawn_player_team()
	_spawn_enemy_team()

	combat_manager.setup_combat(players, enemies)
	combat_ui.setup_ui(combat_manager, players, enemies)
	combat_ui.setup_target_buttons(combatant_visuals)

	combat_ui.target_selected.connect(func(_target: Combatant):
		_update_target_visuals()
	)
	combat_ui.pending_card_changed.connect(func(_card: CardData):
		_update_target_visuals()
	)
	combat_manager.combat_started.connect(_on_combat_started)
	combat_manager.player_turn_started.connect(_on_player_turn_started)
	combat_manager.enemy_turn_started.connect(_on_enemy_turn_started)
	combat_manager.combat_ended.connect(_on_combat_ended)
	combat_manager.combat_log.connect(_on_combat_log)

	for combatant in players + enemies:
		combatant.died.connect(_on_combatant_died)

		combatant.damage_taken.connect(func(
			_changed_combatant: Combatant,
			_incoming_damage: int,
			_blocked_damage: int,
			hp_damage: int,
			_guard_before: int,
			_guard_after: int,
			_hp_before: int,
			_hp_after: int
		):
			if hp_damage > 0:
				_on_combatant_visual_hp_changed(combatant)
		)

		combatant.guard_gained.connect(func(
			_changed_combatant: Combatant,
			_amount: int,
			_guard_before: int,
			_guard_after: int
		):
			_on_combatant_visual_guard_changed(combatant)
		)

	combat_manager.start_combat()

func _process(_delta: float) -> void:
	if combat_ui != null:
		combat_ui.refresh_target_buttons(combatant_visuals)

	var dead_entries: Array[Combatant] = []

	for combatant in combatant_status_uis.keys():
		var entry: Dictionary = combatant_status_uis[combatant]
		var status_ui: Control = entry["ui"]
		var visual: Node2D = entry["visual"]

		if combatant == null or not is_instance_valid(combatant):
			dead_entries.append(combatant)
			continue

		if status_ui == null or not is_instance_valid(status_ui):
			dead_entries.append(combatant)
			continue

		if visual == null or not is_instance_valid(visual):
			dead_entries.append(combatant)
			continue

		if combatant.is_dead():
			status_ui.visible = false
			dead_entries.append(combatant)
			continue

		var screen_pos := visual.get_global_transform_with_canvas().origin
		var sprite_half_height := 90.0

		status_ui.global_position = screen_pos + Vector2(-100, sprite_half_height)
		status_ui.visible = true

	for combatant in dead_entries:
		if combatant_status_uis.has(combatant):
			combatant_status_uis.erase(combatant)

func _on_combat_log(message: String) -> void:
	print(message)


func _on_combatant_visual_hp_changed(combatant: Combatant) -> void:
	if combatant_visuals.has(combatant):
		combatant_visuals[combatant].play_hit_reaction()


func _on_combatant_visual_guard_changed(combatant: Combatant) -> void:
	if combatant_visuals.has(combatant):
		combatant_visuals[combatant].play_guard_reaction()


func _validate_team_data(team_data: Array[CombatantData], label: String) -> bool:
	if team_data.is_empty():
		push_error(label + " is empty.")
		return false

	for data in team_data:
		if data == null:
			push_error(label + " contains null CombatantData.")
			return false

		if data.stats == null:
			push_error(data.display_name + " is missing stats.")
			return false

		if data.starting_deck.is_empty():
			push_error(data.display_name + " is missing starting deck.")
			return false

	return true


func _spawn_player_team() -> void:
	players.clear()

	for i in player_team_data.size():
		var data := player_team_data[i]

		var combatant: PlayerCombatant = PlayerCombatant.new()
		add_child(combatant)
		combatant.name = "PlayerCombatant_%s" % i
		combatant.setup(data.stats, data.starting_deck)

		players.append(combatant)
		_spawn_visual_for_combatant(combatant, data, player_slots, i)


func _spawn_enemy_team() -> void:
	enemies.clear()

	for i in enemy_team_data.size():
		var data := enemy_team_data[i]

		var combatant: EnemyCombatant = EnemyCombatant.new()
		add_child(combatant)
		combatant.name = "EnemyCombatant_%s" % i
		combatant.setup_enemy(data.display_name, data.stats, data.starting_deck)

		enemies.append(combatant)
		_spawn_visual_for_combatant(combatant, data, enemy_slots, i)


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


func _spawn_visual_for_combatant(combatant: Combatant, data: CombatantData, slot_parent: Node2D, index: int) -> void:
	if index >= slot_parent.get_child_count():
		push_error("Not enough visual slots for combatants.")
		return

	var slot := slot_parent.get_child(index)

	var visual := CombatantVisual.new()
	visual.name = combatant.get_display_name() + "_Visual"
	visual.scale = Vector2(0.15, 0.15)
	visual.idle_texture = data.combat_sprite

	slot.add_child(visual)

	combatant_visuals[combatant] = visual
	_spawn_status_ui_for_combatant(combatant, visual)

func _spawn_status_ui_for_combatant(combatant: Combatant, visual: CombatantVisual) -> void:
	if combatant_status_ui_scene == null:
		return

	var status_ui: CombatantStatusUI = combatant_status_ui_scene.instantiate()
	combat_ui.add_child(status_ui)
	status_ui.setup(combatant)

	combatant_status_uis[combatant] = {
		"ui": status_ui,
		"visual": visual
	}

func _update_target_visuals() -> void:
	for combatant in combatant_visuals.keys():
		var visual: CombatantVisual = combatant_visuals[combatant]

		if combatant.is_dead():
			continue

		if combat_ui.pending_card == null:
			if combatant == combat_ui.selected_target:
				visual.set_target_state("selected")
			else:
				visual.set_target_state("normal")
			continue

		var card := combat_ui.pending_card

		match card.target_mode:
			CardData.TargetMode.SINGLE_ENEMY:
				if combatant is EnemyCombatant:
					visual.set_target_state("valid")
				else:
					visual.set_target_state("invalid")

			CardData.TargetMode.SINGLE_ALLY:
				if combatant is PlayerCombatant:
					visual.set_target_state("valid")
				else:
					visual.set_target_state("invalid")

			CardData.TargetMode.SLOT_1_AND_RANDOM_OTHER:
				if combatant is EnemyCombatant:
					visual.set_target_state("cleave")
				else:
					visual.set_target_state("invalid")

			_:
				visual.set_target_state("normal")

func _on_combat_started() -> void:
	print("Combat started.")


func _on_player_turn_started() -> void:
	var active_player := combat_manager.active_player

	print("--- Player Turn ---")

	if active_player != null:
		print("Active Player HP: ", active_player.current_hp)
		print("Active Player hand: ", active_player.hand)
		print("Active Player dice: ", _dice_values_to_text(active_player.get_dice()))

	print("Living enemies: ", combat_manager.get_living_enemies().size())


func _on_enemy_turn_started() -> void:
	print("--- Enemy Turn ---")


func _on_combat_ended(winner: Combatant) -> void:
	if _is_player_combatant(winner):
		print("Combat ended. Player team wins.")
	elif _is_enemy_combatant(winner):
		print("Combat ended. Enemy team wins.")
	else:
		print("Combat ended.")

func _is_player_combatant(combatant: Combatant) -> bool:
	for p in players:
		if p == combatant:
			return true
	return false


func _is_enemy_combatant(combatant: Combatant) -> bool:
	for e in enemies:
		if e == combatant:
			return true
	return false

func _on_player_hand_changed(hand: Array) -> void:
	print("Player hand size: ", hand.size())


func _on_player_dice_rolled(dice: Array[DiceData]) -> void:
	print("Player rolled: ", _dice_values_to_text(dice))


func _dice_values_to_text(dice: Array[DiceData]) -> String:
	var values: Array[String] = []

	for die in dice:
		values.append(str(die.current_value))

	return ", ".join(values)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_play_card"):
		_try_play_first_card()
		return

	if event.is_action_pressed("debug_end_turn"):
		combat_manager.end_player_turn()
		return


func _try_play_first_card() -> void:
	if not combat_manager.is_player_turn:
		print("Cannot play card. It is not the player's turn.")
		return

	var active_player := combat_manager.active_player

	if active_player == null:
		print("No active player.")
		return

	if active_player.hand.is_empty():
		print("No cards in hand.")
		return

	var target := combat_manager._get_first_living_enemy()

	if target == null:
		print("No living enemy target.")
		return

	var card: CardData = active_player.hand[0]
	var assigned_dice: Array[DiceData] = []

	for die in active_player.get_available_dice():
		if card.can_use_with_die(die.current_value):
			assigned_dice.append(die)

			if assigned_dice.size() >= card.dice_required:
				break

	print("Trying to play: ", card.card_name)
	print("Assigned dice: ", _dice_values_to_text(assigned_dice))

	var success := combat_manager.play_player_card(card, assigned_dice, target)

	if success:
		print("Played card: ", card.card_name)
		print("Target HP now: ", target.current_hp)
	else:
		print("Could not play card: ", card.card_name)
