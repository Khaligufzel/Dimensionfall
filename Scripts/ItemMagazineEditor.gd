extends Control

# This scene is intended to be used inside the item editor
# It is supposed to edit exactly one magazine


# Form elements
@export var UsedAmmoTextEdit: TextEdit = null
@export var MaxAmmoNumberBox: SpinBox = null
@export var CurrentAmmoNumberBox: SpinBox = null


func get_properties() -> Dictionary:
	return {
		"used_ammo": UsedAmmoTextEdit.text,
		"max_ammo": MaxAmmoNumberBox.get_line_edit().text,
		"current_ammo": CurrentAmmoNumberBox.get_line_edit().text
	}

func set_properties(properties: Dictionary) -> void:
	if properties.has("used_ammo"):
		UsedAmmoTextEdit.text = properties["used_ammo"]
	if properties.has("max_ammo"):
		MaxAmmoNumberBox.value = float(properties["max_ammo"])
	if properties.has("current_ammo"):
		CurrentAmmoNumberBox.value = float(properties["current_ammo"])
