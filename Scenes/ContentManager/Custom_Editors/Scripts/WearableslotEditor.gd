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
signal data_changed(game_data: Dictionary, new_data: Dictionary, old_data: Dictionary)

var olddata: Dictionary # Remember what the value of the data was before editing
# The data that represents this slot
# The data is selected from the Gamedata.data.slots.data array
# based on the ID that the user has selected in the content editor
var contentData: Dictionary = {}:
	set(value):
		contentData = value
		load_slot_data()
		slotSelector.sprites_collection = Gamedata.data.wearableslots.sprites
		olddata = contentData.duplicate(true)


func _ready():
	data_changed.connect(Gamedata.on_data_changed)


#This function update the form based on the contentData that has been loaded
func load_slot_data() -> void:
	if slotImageDisplay != null and contentData.has("sprite"):
		slotImageDisplay.texture = Gamedata.data.wearableslots.sprites[contentData["sprite"]]
		PathTextLabel.text = contentData["sprite"]
	if IDTextLabel != null:
		IDTextLabel.text = str(contentData["id"])
	if NameTextEdit != null and contentData.has("name"):
		NameTextEdit.text = contentData["name"]
	if DescriptionTextEdit != null and contentData.has("description"):
		DescriptionTextEdit.text = contentData["description"]
	

#The editor is closed, destroy the instance
#TODO: Check for unsaved changes
func _on_close_button_button_up() -> void:
	queue_free()

# This function takes all data fro the form elements stores them in the contentData
# Since contentData is a reference to an item in Gamedata.data.slots.data
# the central array for slotdata is updated with the changes as well
# The function will signal to Gamedata that the data has changed and needs to be saved
func _on_save_button_button_up() -> void:
	contentData["sprite"] = PathTextLabel.text
	contentData["name"] = NameTextEdit.text
	contentData["description"] = DescriptionTextEdit.text
	data_changed.emit(Gamedata.data.wearableslots, contentData, olddata)
	olddata = contentData.duplicate(true)


#When the slotImageDisplay is clicked, the user will be prompted to select an image from 
# "res://Mods/Core/slots/". The texture of the slotImageDisplay will change to the selected image
func _on_slot_image_display_gui_input(event) -> void:
	if event is InputEventMouseButton and event.pressed:
		slotSelector.show()


func _on_sprite_selector_sprite_selected_ok(clicked_sprite) -> void:
	var slotTexture: Resource = clicked_sprite.get_texture()
	slotImageDisplay.texture = slotTexture
	PathTextLabel.text = slotTexture.resource_path.get_file()
