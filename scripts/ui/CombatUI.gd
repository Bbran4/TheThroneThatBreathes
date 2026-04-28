extends Control
class_name CombatUI

@onready var enemy_label: Label = $EnemyInfo/EnemyLabel
@onready var dice_container: HBoxContainer = $Container/DiceContainer
@onready var hand_container: Control = $Container/HandContainer
@onready var enemy_intent_label: Label = $EnemyIntentLabel

@export var card_view_scene: PackedScene
@export var floating_text_scene: PackedScene
@onready var player_top_hud: PlayerTopHUD = $PlayerTopHUD
@onready var player_label_fallback_position: Control = $PlayerTopHUD

var combat_manager: CombatManager
var players: Array[PlayerCombatant] = []
var enemies: Array[EnemyCombatant] = []

var active_player: PlayerCombatant
var selected_target: Combatant = null

var selected_dice: Array[DiceData] = []
var pending_rerolls: int = 0
var hovered_card: CardData = null

var intent_text_by_enemy: Dictionary = {}

var combat_log_label: Label
var result_panel: PanelContainer
var reward_buttons_container: VBoxContainer
var hand_refresh_version: int = 0

var pending_card: CardData = null
var pending_dice: Array[DiceData] = []

var target_button_layer: Control
var target_buttons_by_combatant: Dictionary = {}

const FAN_ARC_MAX := 50.0
const CARD_SPREAD := 95.0
const FAN_SINK := 1.5
const HOVER_LIFT := 120.0
const HAND_BOTTOM_CROP := 120.0
const CARD_WIDTH := 180.0
const CARD_HEIGHT := 270.0

signal target_selected(target: Combatant)
signal pending_card_changed(card: CardData)

func setup_ui(new_combat_manager: CombatManager, new_players: Array[PlayerCombatant], new_enemies: Array[EnemyCombatant]) -> void:
	combat_manager = new_combat_manager
	players = new_players
	enemies = new_enemies
	active_player = combat_manager.active_player

	player_top_hud.setup(active_player, "Exiled Knight")
	
	_ensure_polish_ui_nodes()

	for p in players:
		p.hp_changed.connect(_on_any_combatant_changed)
		p.guard_changed.connect(_on_any_guard_changed)
		p.hand_changed.connect(_on_player_hand_changed)
		p.dice_pool.dice_changed.connect(_on_player_dice_changed)
		p.damage_taken.connect(_on_combatant_damage_taken)
		p.guard_gained.connect(_on_combatant_guard_gained)
		p.guard_reset.connect(_on_combatant_guard_reset)
		p.died.connect(_on_combatant_died)

	for e in enemies:
		e.hp_changed.connect(_on_any_combatant_changed)
		e.guard_changed.connect(_on_any_guard_changed)
		e.intent_changed.connect(func(intent_text: String):
			_on_enemy_intent_changed(e, intent_text)
		)
		e.damage_taken.connect(_on_combatant_damage_taken)
		e.guard_gained.connect(_on_combatant_guard_gained)
		e.guard_reset.connect(_on_combatant_guard_reset)
		e.died.connect(_on_combatant_died)

	combat_manager.player_turn_started.connect(_on_player_turn_started)
	combat_manager.enemy_turn_started.connect(_on_enemy_turn_started)
	combat_manager.combat_ended.connect(_on_combat_ended)
	combat_manager.combat_log.connect(_on_combat_log)
	combat_manager.enemy_action_started.connect(_on_enemy_action_started)
	combat_manager.enemy_intent_prepared.connect(_refresh_enemy_intents)

	player_top_hud.end_turn_pressed.connect(_on_end_turn_pressed)

	_update_all()
	_refresh_hand()
	_refresh_dice()
	_refresh_enemy_intents()


func _ensure_polish_ui_nodes() -> void:
	combat_log_label = get_node_or_null("CombatLogLabel") as Label
	if combat_log_label == null:
		combat_log_label = Label.new()
		combat_log_label.name = "CombatLogLabel"
		combat_log_label.position = Vector2(24, 420)
		combat_log_label.size = Vector2(520, 140)
		combat_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		combat_log_label.text = ""
		add_child(combat_log_label)

	result_panel = get_node_or_null("ResultPanel") as PanelContainer
	if result_panel == null:
		result_panel = PanelContainer.new()
		result_panel.name = "ResultPanel"
		result_panel.visible = false
		result_panel.custom_minimum_size = Vector2(420, 260)
		result_panel.position = Vector2(430, 180)
		add_child(result_panel)

		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 18)
		margin.add_theme_constant_override("margin_right", 18)
		margin.add_theme_constant_override("margin_top", 18)
		margin.add_theme_constant_override("margin_bottom", 18)
		result_panel.add_child(margin)

		var vbox := VBoxContainer.new()
		vbox.name = "ResultVBox"
		margin.add_child(vbox)

		var title := Label.new()
		title.name = "TitleLabel"
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 26)
		vbox.add_child(title)

		var subtitle := Label.new()
		subtitle.name = "SubtitleLabel"
		subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		subtitle.text = "Choose a reward"
		vbox.add_child(subtitle)

		reward_buttons_container = VBoxContainer.new()
		reward_buttons_container.name = "RewardButtons"
		vbox.add_child(reward_buttons_container)
	else:
		reward_buttons_container = result_panel.get_node_or_null("MarginContainer/ResultVBox/RewardButtons") as VBoxContainer


func _refresh_hand() -> void:
	hand_refresh_version += 1
	var my_version := hand_refresh_version

	await get_tree().process_frame

	if my_version != hand_refresh_version:
		return

	call_deferred("_do_refresh_hand_if_current", my_version)

func _do_refresh_hand_if_current(version: int) -> void:
	if version != hand_refresh_version:
		return

	_do_refresh_hand()

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

func _do_refresh_hand() -> void:
	_clear_children(hand_container)

	if active_player == null:
		return

	if card_view_scene == null:
		push_error("CombatUI is missing card_view_scene.")
		return

	var hand := active_player.hand
	var n := hand.size()
	if n == 0:
		return

	var viewport_size := get_viewport_rect().size

	var container_width := hand_container.size.x
	if container_width <= 0:
		_refresh_hand()
		return

	var arc: Variant = min(FAN_ARC_MAX, n * 9.0)
	var angle_step: Variant = arc / max(n - 1, 1)
	var start_angle: Variant = -arc / 2.0

	var center_x := viewport_size.x * 0.5 - hand_container.global_position.x
	var bottom_y := viewport_size.y - hand_container.global_position.y + HAND_BOTTOM_CROP

	for i in n:
		var card: CardData = hand[i]
		var is_playable := _can_selected_dice_play_card(card)

		var card_view: CardView = card_view_scene.instantiate()
		hand_container.add_child(card_view)
		card_view.setup(card, is_playable)

		var angle_deg: Variant = start_angle + angle_step * i
		var offset_x := (i - (n - 1) / 2.0) * CARD_SPREAD
		var rest_x := center_x + offset_x - CARD_WIDTH / 2.0
		var rest_y: Variant = bottom_y + abs(angle_deg) * FAN_SINK - CARD_HEIGHT

		card_view.position = Vector2(rest_x, rest_y)
		card_view.pivot_offset = Vector2(CARD_WIDTH / 2.0, CARD_HEIGHT * 1.4)
		card_view.rotation_degrees = angle_deg
		card_view.scale = Vector2.ONE
		card_view.z_index = i

		var cap_rest_x := rest_x
		var cap_rest_y: Variant = rest_y
		var cap_angle: Variant = angle_deg
		var cap_z := i

		card_view.mouse_entered.connect(func():
			_fan_hover(card_view, cap_rest_y, cap_angle)
		)

		card_view.mouse_exited.connect(func():
			_fan_unhover(card_view, cap_rest_x, cap_rest_y, cap_angle, cap_z)
		)

		card_view.card_selected.connect(func(selected_card: CardData):
			_on_card_pressed(selected_card)
		)

		card_view.card_hovered.connect(func(c: CardData):
			hovered_card = c
			_refresh_dice()
		)

		card_view.card_unhovered.connect(func():
			hovered_card = null
			_refresh_dice()
		)


func _fan_hover(card_view: CardView, rest_y: float, rest_angle: float) -> void:
	if card_view.hover_tween != null:
		card_view.hover_tween.kill()

	card_view.z_index = 200

	card_view.hover_tween = card_view.create_tween()
	card_view.hover_tween.set_parallel(true)

	card_view.hover_tween.tween_property(card_view, "position:y", rest_y - HOVER_LIFT, 0.13).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	card_view.hover_tween.tween_property(card_view, "rotation_degrees", rest_angle * 0.12, 0.13).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	card_view.hover_tween.tween_property(card_view, "scale", Vector2(1.18, 1.18), 0.13).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _fan_unhover(card_view: CardView, rest_x: float, rest_y: float, rest_angle: float, rest_z: int) -> void:
	if card_view.hover_tween != null:
		card_view.hover_tween.kill()

	card_view.z_index = rest_z

	card_view.hover_tween = card_view.create_tween()
	card_view.hover_tween.set_parallel(true)

	card_view.hover_tween.tween_property(card_view, "position", Vector2(rest_x, rest_y), 0.10).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
	card_view.hover_tween.tween_property(card_view, "rotation_degrees", rest_angle, 0.10).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
	card_view.hover_tween.tween_property(card_view, "scale", Vector2.ONE, 0.10).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)


func _on_any_combatant_changed(_current_hp: int, _max_hp: int) -> void:
	_update_all()


func _on_any_guard_changed(_current_guard: int) -> void:
	_update_all()


func _refresh_active_player() -> void:
	active_player = combat_manager.active_player

func _update_all() -> void:
	_update_player_info()
	_update_enemy_info()
	_refresh_enemy_intents()


func _update_player_info() -> void:
	if player_top_hud == null:
		return

	player_top_hud.set_player(active_player, "Exiled Knight")

func _update_enemy_info() -> void:
	var lines: Array[String] = []

	for e in enemies:
		if e == null:
			continue

		if e.is_dead():
			lines.append("%s  DEFEATED" % e.enemy_name)
		else:
			var marker := " <TARGET>" if selected_target == e else ""
			lines.append("%s%s  HP: %s/%s  Guard: %s" % [
				e.enemy_name,
				marker,
				e.current_hp,
				e.stats.max_hp,
				e.current_guard
			])

	enemy_label.text = "\n".join(lines)


func _get_default_target_for_card(card: CardData) -> Combatant:
	if card.can_target_enemy:
		if selected_target != null and not selected_target.is_dead():
			return selected_target

		for e in enemies:
			if e != null and not e.is_dead():
				return e

	if card.can_target_self:
		return active_player

	return null


func _on_player_hand_changed(_hand: Array) -> void:
	_refresh_hand()


func _on_player_dice_changed(_dice: Array[DiceData]) -> void:
	_refresh_dice()

func _card_can_be_prepared(card: CardData) -> bool:
	if card == null:
		return false

	if card.dice_required <= 0:
		return true

	if selected_dice.size() < card.dice_required:
		return false

	var dice_to_use: Array[DiceData] = []

	for die in selected_dice:
		if dice_to_use.size() >= card.dice_required:
			break

		dice_to_use.append(die)

	return card.can_use_with_dice(dice_to_use)

func _get_dice_for_card(card: CardData) -> Array[DiceData]:
	var dice_to_use: Array[DiceData] = []

	if card == null:
		return dice_to_use

	if card.dice_required <= 0:
		return dice_to_use

	for die in selected_dice:
		if dice_to_use.size() >= card.dice_required:
			break

		dice_to_use.append(die)

	return dice_to_use

func _can_selected_dice_play_card(card: CardData) -> bool:
	if card == null:
		return false

	if card.dice_required <= 0:
		return true

	if selected_dice.size() < card.dice_required:
		return false

	var dice_to_check: Array[DiceData] = []

	for die in selected_dice:
		if dice_to_check.size() >= card.dice_required:
			break

		dice_to_check.append(die)

	return card.can_use_with_dice(dice_to_check)


func _can_any_card_use_die(die: DiceData) -> bool:
	if active_player == null:
		return false

	if die == null or die.is_assigned:
		return false

	for card in active_player.hand:
		if card.can_use_with_die(die.current_value):
			return true

	return false


func _clear_invalid_selected_dice() -> void:
	var valid: Array[DiceData] = []

	for die in selected_dice:
		if die != null and not die.is_assigned and _can_any_card_use_die(die):
			valid.append(die)

	selected_dice = valid


func _refresh_dice() -> void:
	if active_player == null:
		return

	_clear_invalid_selected_dice()
	_clear_children(dice_container)

	for die in active_player.get_dice():
		var die_slot := VBoxContainer.new()
		var die_button := Button.new()
		die_button.custom_minimum_size = Vector2(60, 60)

		die_button.text = ("[" + str(die.current_value) + "]") if selected_dice.has(die) else str(die.current_value)

		if die.is_assigned or not _can_any_card_use_die(die):
			die_button.disabled = true

		die_button.pressed.connect(func():
			_on_die_pressed(die)
		)

		die_slot.add_child(die_button)

		if hovered_card != null:
			var mark := "✓ " if hovered_card.can_use_with_die(die.current_value) else "✕ "
			die_button.text = mark + die_button.text

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
	if pending_rerolls <= 0 or die == null or die.is_assigned:
		return

	die.reroll()
	pending_rerolls -= 1
	selected_dice.clear()

	print("Rerolled die. New value: ", die.current_value)

	_refresh_dice()
	_refresh_hand()
	_update_all()


func _on_card_pressed(card: CardData) -> void:
	if active_player == null:
		return

	if not _card_can_be_prepared(card):
		print("Cannot prepare card: ", card.card_name)
		return

	pending_card = card
	pending_dice = _get_dice_for_card(card)
	
	pending_card_changed.emit(pending_card)
	
	if card.requires_manual_target():
		print("Selected card: ", card.card_name, ". Choose a target.")
		return

	_play_pending_card(null)

func _play_pending_card(target: Combatant) -> void:
	if pending_card == null:
		return

	var card := pending_card
	var dice_to_use := pending_dice.duplicate()

	var success := combat_manager.play_player_card(card, dice_to_use, target)

	if success:
		print("Played card: ", card.card_name)

		for die in dice_to_use:
			selected_dice.erase(die)

		if card.effect_type == CardData.CardEffectType.REROLL_DIE:
			pending_rerolls += 1

		pending_card = null
		pending_dice.clear()
		
		pending_card_changed.emit(null)
		
		if selected_target != null and selected_target.is_dead():
			selected_target = null

		_refresh_hand()
		_refresh_dice()
		_update_all()
	else:
		print("Could not play card: ", card.card_name)

func _on_die_pressed(die: DiceData) -> void:
	if die.is_assigned or not _can_any_card_use_die(die):
		return

	if selected_dice.has(die):
		selected_dice.erase(die)
	else:
		selected_dice.append(die)

	_clear_invalid_selected_dice()
	_refresh_dice()
	_refresh_hand()


func _on_end_turn_pressed() -> void:
	selected_dice.clear()
	pending_rerolls = 0
	combat_manager.end_player_turn()


func _on_player_turn_started() -> void:
	_refresh_active_player()

	player_top_hud.set_player(active_player, "Exiled Knight")
	player_top_hud.set_end_turn_enabled(true)
	player_top_hud.set_status_text("Your turn")

	selected_dice.clear()
	pending_rerolls = 0

	_refresh_hand()
	_refresh_dice()
	_update_all()


func _on_enemy_turn_started() -> void:
	player_top_hud.set_end_turn_enabled(false)
	player_top_hud.set_status_text("Enemy turn")

	selected_dice.clear()
	pending_rerolls = 0

	_update_all()


func _on_combat_ended(winner: Combatant) -> void:
	player_top_hud.set_end_turn_enabled(false)
	enemy_intent_label.text = ""

	if _is_player_combatant(winner):
		player_top_hud.set_status_text("Victory")
		_show_result_panel(true)
	else:
		player_top_hud.set_status_text("Defeat")
		_show_result_panel(false)

func select_target(target: Combatant) -> void:
	if target == null:
		return

	if target.is_dead():
		return

	selected_target = target
	_update_all()
	target_selected.emit(target)

	if pending_card == null:
		return

	if pending_card.target_mode == CardData.TargetMode.SINGLE_ENEMY:
		if not _is_enemy_combatant(target):
			print("That card needs an enemy target.")
			return

		_play_pending_card(target)
		return

	if pending_card.target_mode == CardData.TargetMode.SINGLE_ALLY:
		if not _is_player_combatant(target):
			print("That card needs an ally target.")
			return

		_play_pending_card(target)
		return

func clear_target() -> void:
	selected_target = null
	_update_all()

func cancel_pending_card() -> void:
	pending_card = null
	pending_dice.clear()

func _show_result_panel(player_won: bool) -> void:
	if result_panel == null:
		return

	result_panel.visible = true

	var title := result_panel.get_node_or_null("MarginContainer/ResultVBox/TitleLabel") as Label
	var subtitle := result_panel.get_node_or_null("MarginContainer/ResultVBox/SubtitleLabel") as Label

	if title != null:
		title.text = "VICTORY" if player_won else "DEFEAT"

	if subtitle != null:
		subtitle.text = "Choose a reward" if player_won else "The throne keeps breathing."

	if reward_buttons_container == null:
		return

	_clear_children(reward_buttons_container)

	if not player_won:
		var close_button := Button.new()
		close_button.text = "Return"
		reward_buttons_container.add_child(close_button)
		return

	var reward_cards := _get_reward_card_options(3)

	for card in reward_cards:
		var button := Button.new()
		button.text = "+ " + card.card_name
		button.custom_minimum_size = Vector2(320, 42)
		button.pressed.connect(func():
			_on_reward_card_chosen(card)
		)
		reward_buttons_container.add_child(button)


func _get_reward_card_options(amount: int) -> Array[CardData]:
	var options: Array[CardData] = []

	if active_player != null:
		var source_cards: Array = []
		source_cards.append_array(active_player.deck)
		source_cards.append_array(active_player.discard_pile)
		source_cards.append_array(active_player.hand)
		source_cards.shuffle()

		for card in source_cards:
			if card != null and not options.has(card):
				options.append(card)

			if options.size() >= amount:
				return options

	while options.size() < amount:
		var placeholder := CardData.new()
		placeholder.card_name = "Reward Card %s" % (options.size() + 1)
		placeholder.description = "Placeholder reward."
		placeholder.base_damage = 4 + options.size() * 2
		placeholder.can_target_enemy = true
		options.append(placeholder)

	return options


func _on_reward_card_chosen(card: CardData) -> void:
	print("Reward chosen: ", card.card_name)

	if active_player != null:
		active_player.discard_pile.append(card)
		active_player.deck_changed.emit(active_player.deck.size(), active_player.discard_pile.size())

	if reward_buttons_container != null:
		_clear_children(reward_buttons_container)

		var chosen_label := Label.new()
		chosen_label.text = "Chosen: " + card.card_name
		chosen_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		reward_buttons_container.add_child(chosen_label)


func _on_combat_log(message: String) -> void:
	if combat_log_label == null:
		return

	var existing: Array[String] = []

	for line in combat_log_label.text.split("\n", false):
		existing.append(line)

	existing.append(message)

	while existing.size() > 7:
		existing.remove_at(0)

	combat_log_label.text = "\n".join(existing)


func _on_enemy_action_started(enemy: EnemyCombatant, card: CardData, target: Combatant) -> void:
	_spawn_floating_text(
		"%s: %s" % [enemy.enemy_name, card.card_name],
		enemy_label.global_position + Vector2(0, 24)
	)


func _on_combatant_damage_taken(
	combatant: Combatant,
	incoming_damage: int,
	blocked_damage: int,
	hp_damage: int,
	_guard_before: int,
	_guard_after: int,
	_hp_before: int,
	_hp_after: int
) -> void:
	var position := _get_floating_text_position_for_combatant(combatant)

	if blocked_damage > 0:
		_spawn_floating_text("Blocked " + str(blocked_damage), position + Vector2(0, 18))

	if hp_damage > 0:
		_spawn_floating_text("-" + str(hp_damage), position)
	elif incoming_damage > 0:
		_spawn_floating_text("Blocked", position)


func _on_combatant_guard_gained(
	combatant: Combatant,
	amount: int,
	_guard_before: int,
	_guard_after: int
) -> void:
	var position := _get_floating_text_position_for_combatant(combatant)
	_spawn_floating_text("🛡 +" + str(amount), position + Vector2(0, 20))


func _on_combatant_guard_reset(
	combatant: Combatant,
	guard_before: int,
	_guard_after: int
) -> void:
	if guard_before <= 0:
		return

	var position := _get_floating_text_position_for_combatant(combatant)
	_spawn_floating_text("Guard reset", position + Vector2(0, 36))


func _get_floating_text_position_for_combatant(combatant: Combatant) -> Vector2:
	for p in players:
		if p == combatant:
			return player_top_hud.global_position + Vector2(120, 36)

	for e in enemies:
		if e == combatant:
			return enemy_label.global_position + Vector2(0, -20)

	return global_position + Vector2(300, 300)


func _on_combatant_died(combatant: Combatant) -> void:
	if selected_target == combatant:
		selected_target = null

	intent_text_by_enemy.erase(combatant)

	_spawn_floating_text("DEFEATED", _get_floating_text_position_for_combatant(combatant))

	_update_all()


func _on_enemy_intent_changed(enemy: EnemyCombatant, intent_text: String) -> void:
	if enemy == null:
		return

	if enemy.is_dead() or intent_text == "":
		intent_text_by_enemy.erase(enemy)
	else:
		intent_text_by_enemy[enemy] = intent_text

	_refresh_enemy_intents()


func _refresh_enemy_intents() -> void:
	var lines: Array[String] = []

	for e in enemies:
		if e == null or e.is_dead():
			continue

		if intent_text_by_enemy.has(e):
			lines.append(intent_text_by_enemy[e])
		else:
			lines.append("%s: ..." % e.enemy_name)

	enemy_intent_label.text = "\n".join(lines)


func _clear_children(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()


func _spawn_floating_text(text_value: String, screen_position: Vector2) -> void:
	if floating_text_scene == null:
		return

	var floating_text: FloatingText = floating_text_scene.instantiate()
	add_child(floating_text)
	floating_text.play(text_value, screen_position)

func setup_target_buttons(combatant_visuals: Dictionary) -> void:
	if target_button_layer == null:
		target_button_layer = Control.new()
		target_button_layer.name = "TargetButtonLayer"
		target_button_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		target_button_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(target_button_layer)

	_clear_children(target_button_layer)
	target_buttons_by_combatant.clear()

	for combatant in combatant_visuals.keys():
		var visual: Node2D = combatant_visuals[combatant]

		var button := Button.new()
		button.text = ""
		button.flat = true
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.modulate = Color(1, 1, 1, 0.12)

		# Adjust these to fit your sprites.
		var button_size := Vector2(130, 170)
		button.size = button_size
		button.global_position = visual.get_global_transform_with_canvas().origin - button_size * 0.5

		button.pressed.connect(func():
			print("Selected target: ", combatant.get_display_name())
			select_target(combatant)
		)

		target_button_layer.add_child(button)
		target_buttons_by_combatant[combatant] = button

func refresh_target_buttons(combatant_visuals: Dictionary) -> void:
	for combatant in target_buttons_by_combatant.keys():
		var button: Button = target_buttons_by_combatant[combatant]

		if combatant == null or combatant.is_dead():
			button.visible = false
			continue

		if not combatant_visuals.has(combatant):
			button.visible = false
			continue

		var visual: Node2D = combatant_visuals[combatant]
		var button_size := button.size

		button.visible = true
		button.global_position = visual.get_global_transform_with_canvas().origin - button_size * 0.5

		if combatant == selected_target:
			button.modulate = Color(1.0, 0.85, 0.2, 0.28)
		else:
			button.modulate = Color(1, 1, 1, 0.08)
