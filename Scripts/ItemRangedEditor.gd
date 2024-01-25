extends Control

# This scene is intended to be used inside the item editor
# It is supposed to edit exactly one ranged weapon

# Ranged form elements
@export var UsedAmmoTextEdit: TextEdit = null
@export var UsedMagazineTextEdit: TextEdit = null
@export var RangeNumberBox: SpinBox = null
@export var SpreadNumberBox: SpinBox = null
@export var SwayNumberBox: SpinBox = null
@export var RecoilNumberBox: SpinBox = null
@export var UsedSkillTextEdit: TextEdit = null
@export var ReloadSpeedNumberBox: SpinBox = null
@export var FiringSpeedNumberBox: SpinBox = null

func get_properties() -> Dictionary:
	return {
		"used_ammo": UsedAmmoTextEdit.text,
		"used_magazine": UsedMagazineTextEdit.text,
		"range": RangeNumberBox.get_line_edit().text,
		"spread": SpreadNumberBox.get_line_edit().text,
		"sway": SwayNumberBox.get_line_edit().text,
		"recoil": RecoilNumberBox.get_line_edit().text,
		"used_skill": UsedSkillTextEdit.text,
		"reload_speed": ReloadSpeedNumberBox.get_line_edit().text,
		"firing_speed": FiringSpeedNumberBox.get_line_edit().text
	}

func set_properties(properties: Dictionary) -> void:
	if properties.has("used_ammo"):
		UsedAmmoTextEdit.text = properties["used_ammo"]
	if properties.has("used_magazine"):
		UsedMagazineTextEdit.text = properties["used_magazine"]
	if properties.has("range"):
		RangeNumberBox.get_line_edit().text = properties["range"]
	if properties.has("spread"):
		SpreadNumberBox.get_line_edit().text = properties["spread"]
	if properties.has("sway"):
		SwayNumberBox.get_line_edit().text = properties["sway"]
	if properties.has("recoil"):
		RecoilNumberBox.get_line_edit().text = properties["recoil"]
	if properties.has("used_skill"):
		UsedSkillTextEdit.text = properties["used_skill"]
	if properties.has("reload_speed"):
		ReloadSpeedNumberBox.get_line_edit().text = properties["reload_speed"]
	if properties.has("firing_speed"):
		FiringSpeedNumberBox.get_line_edit().text = properties["firing_speed"]
