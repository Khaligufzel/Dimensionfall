extends Control

# This scene is intended to be used inside the item editor
# It is supposed to edit exactly one type of melee weapon

# Form elements
@export var DamageSpinBox: SpinBox = null
@export var ReachSpinBox: SpinBox = null
@export var UsedSkillTextEdit: HBoxContainer = null
@export var skill_xp_spin_box: SpinBox = null


func _ready():
	set_drop_functions()


func get_properties() -> Dictionary:
	var properties = {
		"damage": DamageSpinBox.value,
		"reach": ReachSpinBox.value
	}
	
	# Only include used_skill if UsedSkillTextEdit has a value
	if UsedSkillTextEdit.get_text() != "":
		properties["used_skill"] = {
			"skill_id": UsedSkillTextEdit.get_text(),
			"xp": skill_xp_spin_box.value
		}
	return properties


func set_properties(properties: Dictionary) -> void:
	if properties.has("damage"):
		DamageSpinBox.value = properties["damage"]
	if properties.has("reach"):
		ReachSpinBox.value = properties["reach"]
	if properties.has("used_skill"):
		var used_skill = properties["used_skill"]
		if used_skill.has("skill_id"):
			UsedSkillTextEdit.set_text(used_skill["skill_id"])
		if used_skill.has("xp"):
			skill_xp_spin_box.value = used_skill["xp"]


# Called when the user has successfully dropped data onto the skillTextEdit
# We have to check the dropped_data for the id property
func skill_drop(dropped_data: Dictionary, texteditcontrol: HBoxContainer) -> void:
	# dropped_data is a Dictionary that includes an 'id'
	if dropped_data and "id" in dropped_data:
		var skill_id = dropped_data["id"]
		var skill_data = Gamedata.get_data_by_id(Gamedata.data.skills, skill_id)
		if skill_data.is_empty():
			print_debug("No item data found for ID: " + skill_id)
			return
		texteditcontrol.set_text(skill_id)
	else:
		print_debug("Dropped data does not contain an 'id' key.")


func can_skill_drop(dropped_data: Dictionary):
	# Check if the data dictionary has the 'id' property
	if not dropped_data or not dropped_data.has("id"):
		return false
	
	# Fetch skill data by ID from the Gamedata to ensure it exists and is valid
	var skill_data = Gamedata.get_data_by_id(Gamedata.data.skills, dropped_data["id"])
	if skill_data.is_empty():
		return false

	# If all checks pass, return true
	return true


# Set the drop funcitons on the required skill and skill progression controls
# This enables them to receive drop data
func set_drop_functions():
	UsedSkillTextEdit.drop_function = skill_drop.bind(UsedSkillTextEdit)
	UsedSkillTextEdit.can_drop_function = can_skill_drop
