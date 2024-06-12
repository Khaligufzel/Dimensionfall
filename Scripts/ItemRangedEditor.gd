extends Control

# This scene is intended to be used inside the item editor
# It is supposed to edit exactly one ranged weapon

# Ranged form elements
@export var UsedAmmoTextEdit: TextEdit = null
@export var UsedMagazineContainer: VBoxContainer = null  # This will hold the magazine selection CheckButtons
@export var RangeNumberBox: SpinBox = null
@export var SpreadNumberBox: SpinBox = null
@export var SwayNumberBox: SpinBox = null
@export var RecoilNumberBox: SpinBox = null
@export var UsedSkillTextEdit: HBoxContainer = null
@export var skill_xp_spin_box: SpinBox = null
@export var ReloadSpeedNumberBox: SpinBox = null
@export var FiringSpeedNumberBox: SpinBox = null


func _ready():
	set_drop_functions()
	# Assume Gamedata.get_items_by_type() is implemented as discussed previously
	var magazines = Gamedata.get_items_by_type("Magazine")
	initialize_magazine_selection(magazines)


func initialize_magazine_selection(magazines: Array):
	for magazine in magazines:
		var magazine_button = CheckBox.new()
		magazine_button.text = magazine["id"]
		magazine_button.toggle_mode = true
		UsedMagazineContainer.add_child(magazine_button)


# Returns the properties of the ranged tab in the item editor
func get_properties() -> Dictionary:
	var selected_magazines = []
	for button in UsedMagazineContainer.get_children():
		if button is CheckBox and button.button_pressed:
			selected_magazines.append(button.text)
	
	var properties = {
		"used_ammo": UsedAmmoTextEdit.text,
		"used_magazine": ",".join(selected_magazines),  # Join the selected magazines by commas
		"range": RangeNumberBox.value,
		"spread": SpreadNumberBox.value,
		"sway": SwayNumberBox.value,
		"recoil": RecoilNumberBox.value,
		"reload_speed": ReloadSpeedNumberBox.value,
		"firing_speed": FiringSpeedNumberBox.value
	}
	
	# Only include used_skill if UsedSkillTextEdit has a value
	if UsedSkillTextEdit.get_text() != "":
		properties["used_skill"] = {
			"skill_id": UsedSkillTextEdit.get_text(),
			"xp": skill_xp_spin_box.value
		}
	
	return properties


func set_properties(properties: Dictionary) -> void:
	if properties.has("used_ammo"):
		UsedAmmoTextEdit.text = properties["used_ammo"]
	if properties.has("used_magazine"):
		var used_magazines = properties["used_magazine"].split(",")
		for button in UsedMagazineContainer.get_children():
			if button is CheckBox:
				button.button_pressed = button.text in used_magazines
	if properties.has("range"):
		RangeNumberBox.value = float(properties["range"])
	if properties.has("spread"):
		SpreadNumberBox.value = float(properties["spread"])
	if properties.has("sway"):
		SwayNumberBox.value = float(properties["sway"])
	if properties.has("recoil"):
		RecoilNumberBox.value = float(properties["recoil"])
	if properties.has("used_skill"):
		var used_skill = properties["used_skill"]
		if used_skill.has("skill_id"):
			UsedSkillTextEdit.set_text(used_skill["skill_id"])
		if used_skill.has("xp"):
			skill_xp_spin_box.value = used_skill["xp"]
	if properties.has("reload_speed"):
		ReloadSpeedNumberBox.value = float(properties["reload_speed"])
	if properties.has("firing_speed"):
		FiringSpeedNumberBox.value = float(properties["firing_speed"])


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
