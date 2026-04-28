extends Control
class_name CombatUI

# CombatUI displays the current combat state.
#
# Hand layout uses a fan arc — cards are positioned with rotation and Y offset
# based on index, matching the feel of Slay the Spire / YuGiOh.
#
# Hover fix: each card stores its OWN rest transform and always returns to it.
# No shared mutable state means rapid hover/unhover never drifts.
#
# Arc-on-spawn fix: _refresh_hand() is deferred by one frame via call_deferred
# so hand_container.size is valid before we do any layout math.

@onready var enemy_label: Label = $EnemyInfo/EnemyLabel
@onready var player_label: Label = $PlayerInfo/PlayerLabel
@onready var dice_container: HBoxContainer = $Container/DiceContainer
@onready var hand_container: Control = $Container/HandContainer   # Must be Control, not HBoxContainer
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

# ─── Fan Hand Layout Constants ────────────────────────────────────────────────

const FAN_ARC_MAX      := 50.0   # Max total spread in degrees across all cards
const CARD_SPREAD      := 95.0   # Horizontal gap between card centers (px)
const FAN_SINK         := 1.5    # How much edge cards dip below center (multiplier)
const HOVER_LIFT       := 120.0  # How far a hovered card rises (px)
const HAND_BOTTOM_CROP := 110.0  # How many px of the card hide below screen bottom
const CARD_WIDTH       := 180.0
const CARD_HEIGHT      := 270.0


func setup_ui(new_combat_manager: CombatManager, new_players: Array[PlayerCombatant], new_enemies: Array[EnemyCombatant]) -> void:
	combat_manager = new_combat_manager
	players = new_players
	enemies = new_enemies
	active_player = combat_manager.active_player

	hand_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

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


# ─── Fan Hand ─────────────────────────────────────────────────────────────────

func _refresh_hand() -> void:
	# Defer by one frame so hand_container.size is populated.
	# Without this, size is Vector2.ZERO on the first call and the arc collapses.
	call_deferred("_do_refresh_hand")


func _do_refresh_hand() -> void:
	_clear_children(hand_container)

	if card_view_scene == null:
		push_error("CombatUI is missing card_view_scene.")
		return

	var hand := active_player.hand
	var n := hand.size()
	if n == 0:
		return

	var container_width := hand_container.size.x
	if container_width <= 0:
		# Container still not ready — try again next frame
		_refresh_hand()
		return

	var arc        : Variant = min(FAN_ARC_MAX, n * 9.0)
	var angle_step : Variant = arc / max(n - 1, 1)
	var start_angle : Variant = -arc / 2.0

	var center_x := container_width / 2.0
	var bottom_y := hand_container.size.y - HAND_BOTTOM_CROP

	for i in n:
		var card: CardData = hand[i]
		var is_playable := _can_selected_dice_play_card(card)

		var card_view: CardView = card_view_scene.instantiate()
		hand_container.add_child(card_view)
		card_view.setup(card, is_playable)

		# ── Compute this card's resting transform ──
		var angle_deg    : Variant = start_angle + angle_step * i
		var offset_x     := (i - (n - 1) / 2.0) * CARD_SPREAD
		var rest_x       := center_x + offset_x - CARD_WIDTH / 2.0
		var rest_y       : Variant = bottom_y + abs(angle_deg) * FAN_SINK - CARD_HEIGHT

		# Apply resting transform
		card_view.position        = Vector2(rest_x, rest_y)
		card_view.pivot_offset    = Vector2(CARD_WIDTH / 2.0, CARD_HEIGHT * 1.4)
		card_view.rotation_degrees = angle_deg
		card_view.scale           = Vector2.ONE
		card_view.z_index         = i

		# ── Connect hover using captured rest values ──
		# Capture all rest data as local constants so the lambdas are self-contained.
		# This is the key fix: hover and unhover both know exactly where to go,
		# regardless of what state the card is currently in.
		var cap_rest_x     := rest_x
		var cap_rest_y     : Variant = rest_y
		var cap_angle      : Variant = angle_deg
		var cap_z          := i

		# Disconnect CardView's built-in hover tweens — we're taking over
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

	# Lift: move to (rest_y - HOVER_LIFT), always relative to REST not current pos
	card_view.hover_tween.tween_property(
		card_view, "position:y",
		rest_y - HOVER_LIFT,
		0.13
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	# Straighten: partially flatten the fan angle
	card_view.hover_tween.tween_property(
		card_view, "rotation_degrees",
		rest_angle * 0.12,
		0.13
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	# Scale up
	card_view.hover_tween.tween_property(
		card_view, "scale",
		Vector2(1.18, 1.18),
		0.13
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _fan_unhover(card_view: CardView, rest_x: float, rest_y: float, rest_angle: float, rest_z: int) -> void:
	if card_view.hover_tween != null:
		card_view.hover_tween.kill()

	card_view.z_index = rest_z

	card_view.hover_tween = card_view.create_tween()
	card_view.hover_tween.set_parallel(true)

	# Always return to the exact resting position, not wherever we currently are
	card_view.hover_tween.tween_property(
		card_view, "position",
		Vector2(rest_x, rest_y),
		0.10
	).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)

	card_view.hover_tween.tween_property(
		card_view, "rotation_degrees",
		rest_angle,
		0.10
	).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)

	card_view.hover_tween.tween_property(
		card_view, "scale",
		Vector2.ONE,
		0.10
	).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)


# ─── Rest of CombatUI (unchanged) ────────────────────────────────────────────

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
		var prefix := "> " if p == active_player else ""
		lines.append("%sPlayer  HP: %s/%s  Guard: %s" % [
			prefix, p.current_hp, p.stats.max_hp, p.current_guard
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
			e.enemy_name, e.current_hp, e.stats.max_hp, e.current_guard
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


func _on_player_hand_changed(_hand: Array) -> void:
	_refresh_hand()


func _on_player_dice_changed(_dice: Array[DiceData]) -> void:
	_refresh_dice()


func _can_selected_dice_play_card(card: CardData) -> bool:
	if selected_dice.size() < card.dice_required:
		return false
	return card.can_use_with_dice(selected_dice)


func _can_any_card_use_die(die: DiceData) -> bool:
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
