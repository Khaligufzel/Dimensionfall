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

var ditem: DItem = null:
	set(value):
		if not value:
			return
		ditem = value
		load_properties()


func _ready():
	set_drop_functions()
	# Assume Gamedata.get_items_by_type() is implemented as discussed previously
	var magazines = Gamedata.items.get_items_by_type("magazine")
	initialize_magazine_selection(magazines)


func initialize_magazine_selection(magazines: Array):
	for magazine in magazines:
		var magazine_button = CheckBox.new()
		magazine_button.text = magazine["id"]
		magazine_button.toggle_mode = true
		UsedMagazineContainer.add_child(magazine_button)


# Returns the properties of the ranged tab in the item editor
func save_properties() -> void:
	var selected_magazines = []
	for button in UsedMagazineContainer.get_children():
		if button is CheckBox and button.button_pressed:
			selected_magazines.append(button.text)
	
	
	ditem.ranged.used_ammo = UsedAmmoTextEdit.text
	ditem.ranged.used_magazine = ",".join(selected_magazines)  # Join the selected magazines by commas
	ditem.ranged.firing_range = int(RangeNumberBox.value)
	ditem.ranged.spread = int(SpreadNumberBox.value)
	ditem.ranged.sway = int(SwayNumberBox.value)
	ditem.ranged.recoil = int(RecoilNumberBox.value)
	ditem.ranged.reload_speed = ReloadSpeedNumberBox.value
	ditem.ranged.firing_speed = FiringSpeedNumberBox.value
	
	# Only include used_skill if UsedSkillTextEdit has a value
	if UsedSkillTextEdit.get_text() != "":
		ditem.ranged.used_skill = {
			"skill_id": UsedSkillTextEdit.get_text(),
			"xp": skill_xp_spin_box.value
		}
	else:
		ditem.ranged.used_skill.clear()


func load_properties() -> void:
	if not ditem.ranged:
		print_debug("ditem.ranged is null, skipping property loading.")
		return
	if ditem.ranged.used_ammo != "":
		UsedAmmoTextEdit.text = ditem.ranged.used_ammo
	if ditem.ranged.used_magazine != "":
		var used_magazines = ditem.ranged.used_magazine.split(",")
		for button in UsedMagazineContainer.get_children():
			if button is CheckBox:
				button.button_pressed = button.text in used_magazines
	RangeNumberBox.value = ditem.ranged.firing_range
	SpreadNumberBox.value = ditem.ranged.spread
	SwayNumberBox.value = ditem.ranged.sway
	RecoilNumberBox.value = ditem.ranged.recoil
	ReloadSpeedNumberBox.value = ditem.ranged.reload_speed
	FiringSpeedNumberBox.value = ditem.ranged.firing_speed
	
	if ditem.ranged.used_skill.has("skill_id"):
		UsedSkillTextEdit.set_text(ditem.ranged.used_skill["skill_id"])
	if ditem.ranged.used_skill.has("xp"):
		skill_xp_spin_box.value = ditem.ranged.used_skill["xp"]


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
