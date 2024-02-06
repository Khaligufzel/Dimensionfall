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
@export var UsedSkillTextEdit: TextEdit = null
@export var ReloadSpeedNumberBox: SpinBox = null
@export var FiringSpeedNumberBox: SpinBox = null


func _ready():
	# Assume Gamedata.get_items_by_type() is implemented as discussed previously
	var magazines = Gamedata.get_items_by_type("Magazine")
	initialize_magazine_selection(magazines)

func initialize_magazine_selection(magazines: Array):
	for magazine in magazines:
		var magazine_button = CheckButton.new()
		magazine_button.text = magazine["name"]  # Assuming each magazine has a 'name' property
		magazine_button.toggle_mode = true
		UsedMagazineContainer.add_child(magazine_button)


func get_properties() -> Dictionary:
	var selected_magazines = []
	for button in UsedMagazineContainer.get_children():
		if button is CheckButton and button.pressed:
			selected_magazines.append(button.text)
	
	return {
		"used_ammo": UsedAmmoTextEdit.text,
		"used_magazine": ",".join(selected_magazines),  # Join the selected magazines by commas
		"range": RangeNumberBox.value,
		"spread": SpreadNumberBox.value,
		"sway": SwayNumberBox.value,
		"recoil": RecoilNumberBox.value,
		"used_skill": UsedSkillTextEdit.text,
		"reload_speed": ReloadSpeedNumberBox.value,
		"firing_speed": FiringSpeedNumberBox.value
	}

func set_properties(properties: Dictionary) -> void:
	if properties.has("used_ammo"):
		UsedAmmoTextEdit.text = properties["used_ammo"]
	if properties.has("used_magazine"):
		var used_magazines = properties["used_magazine"].split(",")
		for button in UsedMagazineContainer.get_children():
			if button is CheckButton:
				button.pressed = button.text in used_magazines
	if properties.has("range"):
		RangeNumberBox.value = float(properties["range"])
	if properties.has("spread"):
		SpreadNumberBox.value = float(properties["spread"])
	if properties.has("sway"):
		SwayNumberBox.value = float(properties["sway"])
	if properties.has("recoil"):
		RecoilNumberBox.value = float(properties["recoil"])
	if properties.has("used_skill"):
		UsedSkillTextEdit.text = properties["used_skill"]
	if properties.has("reload_speed"):
		ReloadSpeedNumberBox.value = float(properties["reload_speed"])
	if properties.has("firing_speed"):
		FiringSpeedNumberBox.value = float(properties["firing_speed"])
