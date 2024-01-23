extends Control

# This scene is intended to be used inside the item editor
# It is supposed to edit exactly one type of ammo


# Form elements
@export var DamageNumberBox: SpinBox = null

func get_properties() -> Dictionary:
	return {
		"damage": DamageNumberBox.get_line_edit().text
	}

func set_properties(properties: Dictionary) -> void:
	if properties.has("damage"):
		DamageNumberBox.get_line_edit().text = properties["damage"]
