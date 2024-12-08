extends Control

#This scene is intended to be used inside the content editor
#It is supposed to edit exactly one Equipmentslot
#It expects to save the data to a JSON file
#To load data, provide the name of the slot data file and an ID

@export var slotImageDisplay: TextureRect = null
@export var IDTextLabel: Label = null
@export var PathTextLabel: Label = null
@export var NameTextEdit: TextEdit = null
@export var DescriptionTextEdit: TextEdit = null
@export var slotSelector: Popup = null

# This signal will be emitted when the user presses the save button
# This signal should alert Gamedata that the slot data array should be saved to disk
signal data_changed()

var olddata: DWearableSlot # Remember what the value of the data was before editing

# The data that represents this slot
# The data is selected from the dwearableslot.parent.wearableslots
# based on the ID that the user has selected in the content editor
var dwearableslot: DWearableSlot = null:
	set(value):
		dwearableslot = value
		load_slot_data()
		slotSelector.sprites_collection = dwearableslot.parent.sprites
		olddata = DWearableSlot.new(dwearableslot.get_data().duplicate(true), null)


# This function updates the form based on the DWearableSlot that has been loaded
func load_slot_data() -> void:
	if slotImageDisplay != null and dwearableslot.spriteid:
		slotImageDisplay.texture = dwearableslot.sprite
		PathTextLabel.text = dwearableslot.spriteid
	if IDTextLabel != null:
		IDTextLabel.text = str(dwearableslot.id)
	if NameTextEdit != null:
		NameTextEdit.text = dwearableslot.name
	if DescriptionTextEdit != null:
		DescriptionTextEdit.text = dwearableslot.description

# The editor is closed, destroy the instance
# TODO: Check for unsaved changes
func _on_close_button_button_up() -> void:
	queue_free()

# This function takes all data from the form elements and stores them in the DWearableSlot instance
# Since dwearableslot is a reference to an item in dwearableslot.parent.wearableslots
# the central array for slot data is updated with the changes as well
# The function will signal to Gamedata that the data has changed and needs to be saved
func _on_save_button_button_up() -> void:
	dwearableslot.spriteid = PathTextLabel.text
	dwearableslot.name = NameTextEdit.text
	dwearableslot.description = DescriptionTextEdit.text
	dwearableslot.sprite = slotImageDisplay.texture
	dwearableslot.save_to_disk()
	data_changed.emit()
	olddata = DWearableSlot.new(dwearableslot.get_data().duplicate(true), null)

# When the slotImageDisplay is clicked, the user will be prompted to select an image from 
# "res://Mods/Core/slots/". The texture of the slotImageDisplay will change to the selected image
func _on_slot_image_display_gui_input(event) -> void:
	if event is InputEventMouseButton and event.pressed:
		slotSelector.show()

func _on_sprite_selector_sprite_selected_ok(clicked_sprite) -> void:
	var slotTexture: Resource = clicked_sprite.get_texture()
	slotImageDisplay.texture = slotTexture
	PathTextLabel.text = slotTexture.resource_path.get_file()
