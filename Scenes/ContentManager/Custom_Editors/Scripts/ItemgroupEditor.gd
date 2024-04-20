extends Control

# This scene is intended to be used inside the content editor
# It is supposed to edit exactly one itemgroup
# It expects to save the data to a JSON file that contains all itemgroup data from a mod
# To load data, provide the name of the itemgroup data file and an ID

@export var itemgroupImageDisplay: TextureRect = null
@export var IDTextLabel: Label = null
@export var NameTextEdit: TextEdit = null
@export var DescriptionTextEdit: TextEdit = null
@export var itemgroupSelector: Popup = null
@export var imageNameStringLabel: Label = null
# For controlling the focus when the tab button is pressed
var control_elements: Array = []

# This signal will be emitted when the user presses the save button
# This signal should alert Gamedata that the itemgroup data array should be saved to disk
# The content editor has connected this signal to Gamedata already
signal data_changed()

func _ready():
	control_elements = [itemgroupImageDisplay,NameTextEdit,DescriptionTextEdit]


# The data that represents this itemgroup
# The data is selected from the Gamedata.data.itemgroup.data array
# based on the ID that the user has selected in the content editor
var contentData: Dictionary = {}:
	set(value):
		contentData = value
		load_itemgroup_data()
		itemgroupSelector.sprites_collection = Gamedata.data.itemgroups.sprites


func load_itemgroup_data():
	if itemgroupImageDisplay and contentData.has("sprite") and not contentData["sprite"].is_empty():
		itemgroupImageDisplay.texture = Gamedata.data.itemgroups.sprites[contentData["sprite"]]
		imageNameStringLabel.text = contentData["sprite"]
	if IDTextLabel:
		IDTextLabel.text = str(contentData["id"])
	if NameTextEdit and contentData.has("name"):
		NameTextEdit.text = contentData["name"]
	if DescriptionTextEdit and contentData.has("description"):
		DescriptionTextEdit.text = contentData["description"]


# This function will select the option in the option_button that matches the given string.
# If no match is found, it does nothing.
func select_option_by_string(option_button: OptionButton, option_string: String) -> void:
	for i in range(option_button.get_item_count()):
		if option_button.get_item_text(i) == option_string:
			option_button.selected = i
			return
	print_debug("No matching option found for the string: " + option_string)


#The editor is closed, destroy the instance
#TODO: Check for unsaved changes
func _on_close_button_button_up():
	queue_free()


# This function takes all data from the form elements stores them in the contentData
# Since contentData is a reference to an item in Gamedata.data.itemgroup.data
# the central array for itemgroupdata is updated with the changes as well
# The function will signal to Gamedata that the data has changed and needs to be saved
func _on_save_button_button_up():
	contentData["sprite"] = imageNameStringLabel.text
	contentData["name"] = NameTextEdit.text
	contentData["description"] = DescriptionTextEdit.text
	data_changed.emit()


func _input(event):
	if event.is_action_pressed("ui_focus_next"):
		for myControl in control_elements:
			if myControl.has_focus():
				if Input.is_key_pressed(KEY_SHIFT):  # Check if Shift key
					if !myControl.focus_previous.is_empty():
						myControl.get_node(myControl.focus_previous).grab_focus()
				else:
					if !myControl.focus_next.is_empty():
						myControl.get_node(myControl.focus_next).grab_focus()
				break
		get_viewport().set_input_as_handled()


#When the itemgroupImageDisplay is clicked, the user will be prompted to select an image from 
# "res://Mods/Core/Itemgroups/". The texture of the itemgroupImageDisplay will change to the selected image
func _on_itemgroup_image_display_gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		itemgroupSelector.show()


func _on_sprite_selector_sprite_selected_ok(clicked_sprite) -> void:
	var itemgroupTexture: Resource = clicked_sprite.get_texture()
	itemgroupImageDisplay.texture = itemgroupTexture
	imageNameStringLabel.text = itemgroupTexture.resource_path.get_file()

