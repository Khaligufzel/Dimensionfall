extends Control

# This scene is intended to be used inside the content editor
# It is supposed to edit exactly one Stat
# It expects to save the data to a JSON file
# To load data, provide the name of the stat data file and an ID

@export var statImageDisplay: TextureRect = null
@export var IDTextLabel: Label = null
@export var PathTextLabel: Label = null
@export var NameTextEdit: TextEdit = null
@export var DescriptionTextEdit: TextEdit = null
@export var statSelector: Popup = null

# This signal will be emitted when the user presses the save button
# This signal should alert Gamedata that the stat data array should be saved to disk
signal data_changed()

var olddata: DStat # Remember what the value of the data was before editing

# The data that represents this stat
# The data is selected from the Gamedata.mods.by_id("Core").stats
# based on the ID that the user has selected in the content editor
var dstat: DStat = null:
	set(value):
		dstat = value
		load_stat_data()
		statSelector.sprites_collection = dstat.parent.sprites
		olddata = DStat.new(dstat.get_data().duplicate(true), dstat.parent)


# This function updates the form based on the DStat that has been loaded
func load_stat_data() -> void:
	if statImageDisplay != null and dstat.spriteid != "":
		statImageDisplay.texture = dstat.sprite
		PathTextLabel.text = dstat.spriteid
	if IDTextLabel != null:
		IDTextLabel.text = str(dstat.id)
	if NameTextEdit != null:
		NameTextEdit.text = dstat.name
	if DescriptionTextEdit != null:
		DescriptionTextEdit.text = dstat.description

# The editor is closed, destroy the instance
# TODO: Check for unsaved changes
func _on_close_button_button_up() -> void:
	queue_free()

# This function takes all data from the form elements and stores them in the DStat instance
# Since dstat is a reference to an item in Gamedata.mods.by_id("Core").stats
# the central array for stat data is updated with the changes as well
# The function will signal to Gamedata that the data has changed and needs to be saved
func _on_save_button_button_up() -> void:
	dstat.spriteid = PathTextLabel.text
	dstat.name = NameTextEdit.text
	dstat.description = DescriptionTextEdit.text
	dstat.sprite = statImageDisplay.texture
	dstat.save_to_disk()
	data_changed.emit()
	olddata = DStat.new(dstat.get_data().duplicate(true), dstat.parent)

# When the statImageDisplay is clicked, the user will be prompted to select an image from 
# "res://Mods/Core/Stats/". The texture of the statImageDisplay will change to the selected image
func _on_stat_image_display_gui_input(event) -> void:
	if event is InputEventMouseButton and event.pressed:
		statSelector.show()

func _on_sprite_selector_sprite_selected_ok(clicked_sprite) -> void:
	var statTexture: Resource = clicked_sprite.get_texture()
	statImageDisplay.texture = statTexture
	PathTextLabel.text = statTexture.resource_path.get_file()
