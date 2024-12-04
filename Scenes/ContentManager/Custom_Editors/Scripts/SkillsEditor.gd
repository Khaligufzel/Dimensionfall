extends Control

# This scene is intended to be used inside the content editor
# It is supposed to edit exactly one Skill
# It expects to save the data to a JSON file
# To load data, provide the name of the skill data file and an ID

@export var skillImageDisplay: TextureRect = null
@export var IDTextLabel: Label = null
@export var PathTextLabel: Label = null
@export var NameTextEdit: TextEdit = null
@export var DescriptionTextEdit: TextEdit = null
@export var skillSelector: Popup = null

# This signal will be emitted when the user presses the save button
# This signal should alert Gamedata that the skill data array should be saved to disk
signal data_changed()

var olddata: DSkill # Remember what the value of the data was before editing

# The data that represents this skill
# The data is selected from the dskill.parent
# based on the ID that the user has selected in the content editor
var dskill: DSkill = null:
	set(value):
		dskill = value
		load_skill_data()
		skillSelector.sprites_collection = dskill.parent.sprites
		olddata = DSkill.new(dskill.get_data().duplicate(true), null)

# This function updates the form based on the DSkill that has been loaded
func load_skill_data() -> void:
	if skillImageDisplay != null and dskill.spriteid != "":
		skillImageDisplay.texture = dskill.sprite
		PathTextLabel.text = dskill.spriteid
	if IDTextLabel != null:
		IDTextLabel.text = str(dskill.id)
	if NameTextEdit != null:
		NameTextEdit.text = dskill.name
	if DescriptionTextEdit != null:
		DescriptionTextEdit.text = dskill.description

# The editor is closed, destroy the instance
# TODO: Check for unsaved changes
func _on_close_button_button_up() -> void:
	queue_free()

# This function takes all data from the form elements and stores them in the DSkill instance
# Since dskill is a reference to an item in dskill.parent
# the central array for skill data is updated with the changes as well
# The function will signal to Gamedata that the data has changed and needs to be saved
func _on_save_button_button_up() -> void:
	dskill.spriteid = PathTextLabel.text
	dskill.name = NameTextEdit.text
	dskill.description = DescriptionTextEdit.text
	dskill.sprite = skillImageDisplay.texture
	dskill.save_to_disk()
	data_changed.emit()
	olddata = DSkill.new(dskill.get_data().duplicate(true), null)

# When the skillImageDisplay is clicked, the user will be prompted to select an image from 
# "res://Mods/Core/Skills/". The texture of the skillImageDisplay will change to the selected image
func _on_skill_image_display_gui_input(event) -> void:
	if event is InputEventMouseButton and event.pressed:
		skillSelector.show()

func _on_sprite_selector_sprite_selected_ok(clicked_sprite) -> void:
	var skillTexture: Resource = clicked_sprite.get_texture()
	skillImageDisplay.texture = skillTexture
	PathTextLabel.text = skillTexture.resource_path.get_file()
