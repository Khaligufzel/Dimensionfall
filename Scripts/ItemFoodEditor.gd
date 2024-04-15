extends Control

# This scene is intended to be used inside the item editor
# It is supposed to edit exactly one type of ammo


# Form elements
@export var HealthNumberBox: SpinBox = null

func get_properties() -> Dictionary:
	return {
		"health": HealthNumberBox.get_line_edit().text
	}

func set_properties(properties: Dictionary) -> void:
	if properties.has("damage"):
		HealthNumberBox.get_line_edit().text = properties["health"]
