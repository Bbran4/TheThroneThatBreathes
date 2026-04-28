extends Control
class_name CombatUI

# CombatUI displays the current combat state.
#
# It does not own combat rules.
# It only:
# - reads combatant state
# - creates buttons for cards and dice
# - sends player actions to CombatManager

@onready var enemy_label: Label = $EnemyInfo/EnemyLabel
@onready var player_label: Label = $PlayerInfo/PlayerLabel
@onready var dice_container: HBoxContainer = $Container/DiceContainer
@onready var hand_container: HBoxContainer = $Container/HandContainer
@onready var end_turn_button: Button = $EndTurnButton
@export var card_view_scene: PackedScene
@onready var enemy_intent_label: Label = $EnemyIntentLabel
@export var floating_text_scene: PackedScene

var combat_manager: CombatManager
var players: Array[PlayerCombatant] = []
var enemies: Array[EnemyCombatant] = []

var active_player: PlayerCombatant
var selected_target: Combatant = null

var selected_dice: Array[DiceData] = []
var pending_rerolls: int = 0
var hovered_card: CardData = null

func setup_ui(new_combat_manager: CombatManager, new_players: Array[PlayerCombatant], new_enemies: Array[EnemyCombatant]) -> void:
	combat_manager = new_combat_manager
	players = new_players
	enemies = new_enemies
	active_player = combat_manager.active_player
	hand_container.add_theme_constant_override("separation", -80)
	
	for p in players:
		p.hp_changed.connect(_on_any_combatant_changed)
		p.guard_changed.connect(_on_any_guard_changed)
		p.hand_changed.connect(_on_player_hand_changed)
		p.dice_pool.dice_changed.connect(_on_player_dice_changed)

	for e in enemies:
		e.hp_changed.connect(_on_any_combatant_changed)
		e.guard_changed.connect(_on_any_guard_changed)
		e.intent_changed.connect(_on_enemy_intent_changed)

	combat_manager.player_turn_started.connect(_on_player_turn_started)
	combat_manager.enemy_turn_started.connect(_on_enemy_turn_started)
	combat_manager.combat_ended.connect(_on_combat_ended)

	end_turn_button.pressed.connect(_on_end_turn_pressed)

	_update_all()

func _on_any_combatant_changed(_current_hp: int, _max_hp: int) -> void:
	_update_all()


func _on_any_guard_changed(_current_guard: int) -> void:
	_update_all()

func _refresh_active_player() -> void:
	active_player = combat_manager.active_player

func _update_all() -> void:
	_update_player_info()
	_update_enemy_info()


func _update_player_info() -> void:
	var lines: Array[String] = []

	for p in players:
		if p == null:
			continue

		var prefix := ""
		if p == active_player:
			prefix = "> "

		lines.append("%sPlayer  HP: %s/%s  Guard: %s" % [
			prefix,
			p.current_hp,
			p.stats.max_hp,
			p.current_guard
		])

	player_label.text = "\n".join(lines)

func _get_default_target_for_card(card: CardData) -> Combatant:
	if card.can_target_enemy:
		for e in enemies:
			if e != null and not e.is_dead():
				return e

	if card.can_target_self:
		return active_player

	return null

func _update_enemy_info() -> void:
	var lines: Array[String] = []

	for e in enemies:
		if e == null:
			continue

		lines.append("%s  HP: %s/%s  Guard: %s" % [
			e.enemy_name,
			e.current_hp,
			e.stats.max_hp,
			e.current_guard
		])

	enemy_label.text = "\n".join(lines)


func _on_player_hp_changed(_current_hp: int, _max_hp: int) -> void:
	_update_all()
	_spawn_floating_text("HP " + str(_current_hp), player_label.global_position + Vector2(0, -20))


func _on_player_guard_changed(_current_guard: int) -> void:
	_update_all()
	_spawn_floating_text("🛡 " + str(_current_guard), player_label.global_position + Vector2(0, 20))


func _on_enemy_hp_changed(_current_hp: int, _max_hp: int) -> void:
	_update_all()
	_spawn_floating_text("HP " + str(_current_hp), enemy_label.global_position + Vector2(0, -20))


func _on_enemy_guard_changed(_current_guard: int) -> void:
	_update_all()
	_spawn_floating_text("🛡 " + str(_current_guard), enemy_label.global_position + Vector2(0, 20))

func _on_player_hand_changed(hand: Array) -> void:
	_refresh_hand()


func _on_player_dice_changed(dice: Array[DiceData]) -> void:
	_refresh_dice()

func _can_selected_dice_play_card(card: CardData) -> bool:
	if selected_dice.size() < card.dice_required:
		return false

	return card.can_use_with_dice(selected_dice)


func _can_any_card_use_die(die: DiceData) -> bool:
	if die == null:
		return false

	if die.is_assigned:
		return false

	for card in active_player.hand:
		if card.can_use_with_die(die.current_value):
			return true

	return false


func _clear_invalid_selected_dice() -> void:
	# Removes dice from selection if they are no longer usable.
	# This protects against stale selections after cards are played.
	var valid_selection: Array[DiceData] = []

	for die in selected_dice:
		if die != null and not die.is_assigned and _can_any_card_use_die(die):
			valid_selection.append(die)

	selected_dice = valid_selection

func _refresh_hand() -> void:
	_clear_children(hand_container)

	if card_view_scene == null:
		push_error("CombatUI is missing card_view_scene.")
		return

	for card in active_player.hand:
		var card_view: CardView = card_view_scene.instantiate()
		var slot := Control.new()
		slot.custom_minimum_size = Vector2(95, 270)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hand_container.add_child(slot)

		card_view.position = Vector2(0, 150)
		slot.add_child(card_view)

		var is_playable := _can_selected_dice_play_card(card)

		card_view.setup(card, is_playable)

		card_view.card_selected.connect(func(selected_card: CardData):
			_on_card_pressed(selected_card)
		)
		
		card_view.card_hovered.connect(func(card: CardData):
			hovered_card = card
			_refresh_dice()
		)

		card_view.card_unhovered.connect(func():
			hovered_card = null
			_refresh_dice()
		)

func _refresh_dice() -> void:
	_clear_invalid_selected_dice()
	_clear_children(dice_container)

	for die in active_player.get_dice():
		var die_slot := VBoxContainer.new()

		var die_button := Button.new()
		die_button.custom_minimum_size = Vector2(60, 60)

		if selected_dice.has(die):
			die_button.text = "[" + str(die.current_value) + "]"
		else:
			die_button.text = str(die.current_value)

		if die.is_assigned:
			die_button.disabled = true
		elif not _can_any_card_use_die(die):
			die_button.disabled = true

		die_button.pressed.connect(func():
			_on_die_pressed(die)
		)

		die_slot.add_child(die_button)
			
		if hovered_card != null:
			if hovered_card.can_use_with_die(die.current_value):
				die_button.text = "✓ " + die_button.text
			else:
				die_button.text = "✕ " + die_button.text
			
		if pending_rerolls > 0 and not die.is_assigned:
			var reroll_button := Button.new()
			reroll_button.text = "Reroll"
			reroll_button.custom_minimum_size = Vector2(60, 24)

			reroll_button.pressed.connect(func():
				_on_reroll_pressed(die)
			)

			die_slot.add_child(reroll_button)

		dice_container.add_child(die_slot)

func _on_reroll_pressed(die: DiceData) -> void:
	if pending_rerolls <= 0:
		return

	if die == null:
		return

	if die.is_assigned:
		return

	die.reroll()
	pending_rerolls -= 1

	selected_dice.clear()

	print("Rerolled die. New value: ", die.current_value)

	_refresh_dice()
	_refresh_hand()
	_update_all()

func _on_card_pressed(card: CardData) -> void:
	if selected_dice.size() < card.dice_required:
		print("Not enough dice selected for ", card.card_name)
		return

	if not card.can_use_with_dice(selected_dice):
		print("Selected dice cannot be used for ", card.card_name)
		return

	var target := selected_target

	if target == null:
		target = _get_default_target_for_card(card)

	var success := combat_manager.play_player_card(card, selected_dice, target)

	if success:
		print("Played card: ", card.card_name)

		selected_dice.clear()

		if card.effect_type == CardData.CardEffectType.REROLL_DIE:
			pending_rerolls += 1
			print("Reroll available.")

		_refresh_hand()
		_refresh_dice()
		_update_all()
	else:
		print("Could not play card: ", card.card_name)

func _on_die_pressed(die: DiceData) -> void:
	if die.is_assigned:
		return

	if not _can_any_card_use_die(die):
		return

	if selected_dice.has(die):
		selected_dice.erase(die)
		print("Unselected die: ", die.current_value)
	else:
		selected_dice.append(die)
		print("Selected die: ", die.current_value)

	_clear_invalid_selected_dice()
	_refresh_dice()
	_refresh_hand()


func _on_end_turn_pressed() -> void:
	selected_dice.clear()
	pending_rerolls = 0
	combat_manager.end_player_turn()

func _on_player_turn_started() -> void:
	_refresh_active_player()
	end_turn_button.disabled = false
	selected_dice.clear()
	pending_rerolls = 0

	_refresh_hand()
	_refresh_dice()
	_update_all()

func _on_enemy_turn_started() -> void:
	end_turn_button.disabled = true
	selected_dice.clear()
	pending_rerolls = 0

	_update_all()

func _on_combat_ended(winner: Combatant) -> void:
	end_turn_button.disabled = true
	enemy_intent_label.text = ""
	
	if winner == active_player:
		player_label.text += "\nVictory."
	else:
		player_label.text += "\nDefeat."


func _get_card_button_text(card: CardData) -> String:
	return "%s\n%s" % [
		card.card_name,
		card.description
	]


func _clear_children(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()

func _on_enemy_intent_changed(intent_text: String) -> void:
	enemy_intent_label.text = intent_text

func _spawn_floating_text(text_value: String, screen_position: Vector2) -> void:
	if floating_text_scene == null:
		return

	var floating_text: FloatingText = floating_text_scene.instantiate()
	add_child(floating_text)

	floating_text.play(text_value, screen_position)
