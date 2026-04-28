extends Control
class_name CombatantStatusUI

@onready var guard_label: Label = $VBoxContainer/BarRow/GuardLabel
@onready var health_bar: ProgressBar = $VBoxContainer/BarRow/HealthBar
@onready var hp_value_label: Label = $VBoxContainer/BarRow/HpValueLabel
@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var intent_label: Label = $VBoxContainer/IntentLabel

var combatant: Combatant


func setup(new_combatant: Combatant) -> void:
	combatant = new_combatant

	combatant.hp_changed.connect(_on_hp_changed)
	combatant.guard_changed.connect(_on_guard_changed)
	combatant.died.connect(_on_died)

	if combatant is EnemyCombatant:
		var enemy := combatant as EnemyCombatant
		enemy.intent_changed.connect(_on_intent_changed)

	_refresh_all()


func _refresh_all() -> void:
	if combatant == null:
		return

	health_bar.max_value = combatant.stats.max_hp
	health_bar.value = combatant.current_hp
	hp_value_label.text = "%s/%s" % [combatant.current_hp, combatant.stats.max_hp]
	guard_label.text = "🛡 %s" % combatant.current_guard
	status_label.text = ""

	if combatant is EnemyCombatant:
		intent_label.visible = true
		intent_label.text = ""
	else:
		intent_label.visible = false


func _on_hp_changed(current_hp: int, max_hp: int) -> void:
	health_bar.max_value = max_hp
	health_bar.value = current_hp
	hp_value_label.text = "%s/%s" % [current_hp, max_hp]


func _on_guard_changed(current_guard: int) -> void:
	guard_label.text = "🛡 %s" % current_guard


func _on_intent_changed(intent_text: String) -> void:
	intent_label.text = intent_text


func _on_died(_dead_combatant: Combatant) -> void:
	visible = false
