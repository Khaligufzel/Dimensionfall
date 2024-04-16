extends Control

#This scene is intended to be used inside the content editor
#It is supposed to edit exactly one piece of furniture
#It expects to save the data to a JSON file that contains all furniture data from a mod
#To load data, provide the name of the furniture data file and an ID

@export var furnitureImageDisplay: TextureRect = null
@export var IDTextLabel: Label = null
@export var NameTextEdit: TextEdit = null
@export var DescriptionTextEdit: TextEdit = null
@export var CategoriesList: Control = null
@export var furnitureSelector: Popup = null
@export var imageNameStringLabel: Label = null
@export var moveableCheckboxButton: CheckBox = null
@export var edgeSnappingOptionButton: OptionButton = null
@export var doorOptionButton: OptionButton = null
# For controlling the focus when the tab button is pressed
var control_elements: Array = []

# This signal will be emitted when the user presses the save button
# This signal should alert Gamedata that the furniture data array should be saved to disk
# The content editor has connected this signal to Gamedata already
signal data_changed()

func _ready():
	control_elements = [furnitureImageDisplay,NameTextEdit,DescriptionTextEdit]
	
# The data that represents this furniture
# The data is selected from the Gamedata.data.furniture.data array
# based on the ID that the user has selected in the content editor
var contentData: Dictionary = {}:
	set(value):
		contentData = value
		load_furniture_data()
		furnitureSelector.sprites_collection = Gamedata.data.furniture.sprites


func load_furniture_data():
	if furnitureImageDisplay and contentData.has("sprite"):
		furnitureImageDisplay.texture = Gamedata.data.furniture.sprites[contentData["sprite"]]
		imageNameStringLabel.text = contentData["sprite"]
	if IDTextLabel:
		IDTextLabel.text = str(contentData["id"])
	if NameTextEdit and contentData.has("name"):
		NameTextEdit.text = contentData["name"]
	if DescriptionTextEdit and contentData.has("description"):
		DescriptionTextEdit.text = contentData["description"]
	if CategoriesList and contentData.has("categories"):
		CategoriesList.clear_list()
		for category in contentData["categories"]:
			CategoriesList.add_item_to_list(category)
	if moveableCheckboxButton and contentData.has("moveable"):
		moveableCheckboxButton.button_pressed = contentData["moveable"]
	if edgeSnappingOptionButton and contentData.has("edgesnapping"):
		select_option_by_string(edgeSnappingOptionButton, contentData["edgesnapping"])
	if doorOptionButton:
		update_door_option(contentData.get("Function", {}).get("door", "None"))


func update_door_option(door_state):
	var items = doorOptionButton.get_item_count()
	for i in range(items):
		if doorOptionButton.get_item_text(i) == door_state or (door_state not in ["Open", "Closed"] and doorOptionButton.get_item_text(i) == "None"):
			doorOptionButton.selected = i
			return
	print_debug("No matching door state option found: " + door_state)


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
# Since contentData is a reference to an item in Gamedata.data.furniture.data
# the central array for furnituredata is updated with the changes as well
# The function will signal to Gamedata that the data has changed and needs to be saved
func _on_save_button_button_up():
	contentData["sprite"] = imageNameStringLabel.text
	contentData["name"] = NameTextEdit.text
	contentData["description"] = DescriptionTextEdit.text
	contentData["categories"] = CategoriesList.get_items()
	contentData["moveable"] = moveableCheckboxButton.button_pressed
	contentData["edgesnapping"] = edgeSnappingOptionButton.get_item_text(edgeSnappingOptionButton.selected)
	handle_door_option()
	data_changed.emit()


# If the door function is set, we save the value to contentData
# Else, if the door state is set to none, we erase the value from contentdata
func handle_door_option():
	var door_state = doorOptionButton.get_item_text(doorOptionButton.selected)
	if door_state == "None" and "Function" in contentData and "door" in contentData["Function"]:
		contentData["Function"].erase("door")
	elif door_state in ["Open", "Closed"]:
		contentData["Function"] = {"door": door_state}


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

#When the furnitureImageDisplay is clicked, the user will be prompted to select an image from 
# "res://Mods/Core/Furnitures/". The texture of the furnitureImageDisplay will change to the selected image
func _on_furniture_image_display_gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		furnitureSelector.show()

func _on_sprite_selector_sprite_selected_ok(clicked_sprite) -> void:
	var furnitureTexture: Resource = clicked_sprite.get_texture()
	furnitureImageDisplay.texture = furnitureTexture
	imageNameStringLabel.text = furnitureTexture.resource_path.get_file()

