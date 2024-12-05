extends Control

# This scene is intended to be used inside the item editor
# It is supposed to edit exactly one type of melee weapon

# Form elements
@export var DamageSpinBox: SpinBox = null
@export var ReachSpinBox: SpinBox = null
@export var UsedSkillTextEdit: HBoxContainer = null
@export var skill_xp_spin_box: SpinBox = null

var ditem: DItem = null:
	set(value):
		if not value:
			return
		ditem = value
		load_properties()

func _ready():
	set_drop_functions()

# Load the properties from the ditem.melee and update the UI elements
func load_properties() -> void:
	if not ditem.melee:
		print_debug("ditem.melee is null, skipping property loading.")
		return
	if ditem.melee.damage:
		DamageSpinBox.value = ditem.melee.damage
	if ditem.melee.reach:
		ReachSpinBox.value = ditem.melee.reach

	if ditem.melee.used_skill.has("skill_id"):
		UsedSkillTextEdit.set_text(ditem.melee.used_skill["skill_id"])
	if ditem.melee.used_skill.has("xp"):
		skill_xp_spin_box.value = ditem.melee.used_skill["xp"]

# Save the properties from the UI elements back to ditem.melee
func save_properties() -> void:
	ditem.melee.damage = int(DamageSpinBox.value)
	ditem.melee.reach = int(ReachSpinBox.value)

	if UsedSkillTextEdit.get_text() != "":
		ditem.melee.used_skill = {
			"skill_id": UsedSkillTextEdit.get_text(),
			"xp": skill_xp_spin_box.value
		}
	else:
		ditem.melee.used_skill.clear()


# Called when the user has successfully dropped data onto the skillTextEdit
# We have to check the dropped_data for the id property
func skill_drop(dropped_data: Dictionary, texteditcontrol: HBoxContainer) -> void:
	# dropped_data is a Dictionary that includes an 'id'
	if dropped_data and "id" in dropped_data:
		var skill_id = dropped_data["id"]
		if not Gamedata.mods.by_id(dropped_data["mod_id"]).skills.has_id(skill_id):
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
	if not Gamedata.mods.by_id(dropped_data["mod_id"]).skills.has_id(dropped_data["id"]):
		return false

	# If all checks pass, return true
	return true


# Set the drop funcitons on the required skill and skill progression controls
# This enables them to receive drop data
func set_drop_functions():
	UsedSkillTextEdit.drop_function = skill_drop.bind(UsedSkillTextEdit)
	UsedSkillTextEdit.can_drop_function = can_skill_drop
