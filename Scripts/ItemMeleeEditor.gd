extends Control

# This scene is intended to be used inside the item editor
# It is supposed to edit exactly one type of melee wearon

# Form elements
@export var DamageSpinBox: SpinBox = null


func _ready():
	pass


func get_properties() -> Dictionary:
	return {
		"damage": DamageSpinBox.value
	}


func set_properties(properties: Dictionary) -> void:
	if properties.has("damage"):
		DamageSpinBox.value = properties["damage"]
