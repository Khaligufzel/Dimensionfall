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
@export var containerCheckBox: CheckBox = null
@export var containerTextEdit: TextEdit = null

# For controlling the focus when the tab button is pressed
var control_elements: Array = []
# Original state of the container itemgroup for comparison when the itemgroup chanes
var original_itemgroup: String = ""

# This signal will be emitted when the user presses the save button
# This signal should alert Gamedata that the furniture data array should be saved to disk
# The content editor has connected this signal to Gamedata already
signal data_changed()
# Signal for container changes specifically
signal itemgroup_changed(old_group, new_group, furniture_id)


func _ready():
	# For properly using the tab key to switch elements
	control_elements = [furnitureImageDisplay,NameTextEdit,DescriptionTextEdit]
	itemgroup_changed.connect(Gamedata.on_furniture_itemgroup_changed)


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

	# Load container data if it exists within the 'Function' property
	var function_data = contentData.get("Function", {})
	if "container" in function_data:
		containerCheckBox.button_pressed = true  # Check the container checkbox
		var container_data = function_data["container"]
		if "itemgroup" in container_data:
			containerTextEdit.text = container_data["itemgroup"]  # Set text edit with the itemgroup ID
			original_itemgroup = containerTextEdit.text  # Initialize the original state
		else:
			containerTextEdit.clear()  # Clear the text edit if no itemgroup is specified
	else:
		containerCheckBox.button_pressed = false  # Uncheck the container checkbox
		containerTextEdit.clear()  # Clear the text edit as no container data is present


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
	
	# Check if the container should be saved
	if containerCheckBox.is_pressed():
		# Initialize 'Function' dictionary if it doesn't exist
		if "Function" not in contentData:
			contentData["Function"] = {}
			
		# the container will remain empty if no itemgroup is set, 
		# which will just act as an empty container
		if containerTextEdit.text != "":
			# Update or set the container property within the 'Function' dictionary
			contentData["Function"]["container"] = {"itemgroup": containerTextEdit.text}
		else: # No itemgroup provided, it's an emtpy container
			contentData["Function"]["container"] = {}
	elif "Function" in contentData and "container" in contentData["Function"]:
		# If the checkbox is not checked or text edit is empty, remove the container data
		contentData["Function"].erase("container")
		# If the 'Function' dictionary becomes empty, remove it as well
		if contentData["Function"].is_empty():
			contentData.erase("Function")
	
	var current_itemgroup = containerTextEdit.text
	if original_itemgroup != current_itemgroup:
		itemgroup_changed.emit(contentData["id"], original_itemgroup, current_itemgroup)
		original_itemgroup = current_itemgroup  # Update the original state

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


func _on_container_check_box_toggled(toggled_on):
	if not toggled_on:
		containerTextEdit.clear()


func _on_clear_container_button_button_up():
	containerTextEdit.clear()


# This function should return true if the dragged data can be dropped here
func _can_drop_data(_newpos, data) -> bool:
	# Check if the containerCheckBox is checked; if not, return false
	if not containerCheckBox.is_pressed():
		return false

	# Check if the data dictionary has the 'id' property
	if not data or not data.has("id"):
		return false
	
	# Fetch itemgroup data by ID from the Gamedata to ensure it exists and is valid
	var itemgroup_data = Gamedata.get_data_by_id(Gamedata.data.itemgroups, data["id"])
	if itemgroup_data.is_empty():
		return false

	# If all checks pass, return true
	return true


# This function handles the data being dropped
func _drop_data(newpos, data) -> void:
	if _can_drop_data(newpos, data):
		_handle_item_drop(data, newpos)


# Called when the user has successfully dropped data onto the ItemGroupTextEdit
# We have to check the dropped_data for the id property
func _handle_item_drop(dropped_data, _newpos) -> void:
	# Assuming dropped_data is a Dictionary that includes an 'id'
	if dropped_data and "id" in dropped_data:
		var itemgroup_id = dropped_data["id"]
		var itemgroup_data = Gamedata.get_data_by_id(Gamedata.data.itemgroups, itemgroup_id)
		if itemgroup_data.is_empty():
			print_debug("No item data found for ID: " + itemgroup_id)
			return
		containerTextEdit.text = itemgroup_id
	else:
		print_debug("Dropped data does not contain an 'id' key.")
