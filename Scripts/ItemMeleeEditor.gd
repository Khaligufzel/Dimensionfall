extends Control

# This scene is intended to be used inside the item editor
# It is supposed to edit exactly one type of melee weapon

# Form elements
@export var DamageSpinBox: SpinBox = null
@export var ReachSpinBox: SpinBox = null


func _ready():
	pass


func get_properties() -> Dictionary:
	return {
		"damage": DamageSpinBox.value,
		"reach": ReachSpinBox.value
	}


func set_properties(properties: Dictionary) -> void:
	if properties.has("damage"):
		DamageSpinBox.value = properties["damage"]
	if properties.has("reach"):
		ReachSpinBox.value = properties["reach"]
