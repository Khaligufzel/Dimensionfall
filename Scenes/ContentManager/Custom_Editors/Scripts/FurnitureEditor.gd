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
@export var moveableCheckboxButton: CheckBox = null # The player can push it if selected
@export var edgeSnappingOptionButton: OptionButton = null # Apply edge snapping if selected
@export var doorOptionButton: OptionButton = null # Maks the furniture as a door
@export var containerCheckBox: CheckBox = null # Marks the furniture as a container
@export var containerTextEdit: HBoxContainer = null # Might contain the id of a loot group
@export var destructionTextEdit: HBoxContainer = null # Might contain the id of a loot group
@export var disassemblyTextEdit: HBoxContainer = null # Might contain the id of a loot group

# For controlling the focus when the tab button is pressed
var control_elements: Array = []


# This signal will be emitted when the user presses the save button
# This signal should alert Gamedata that the mob data array should be saved to disk
signal data_changed(game_data: Dictionary, new_data: Dictionary, old_data: Dictionary)


var olddata: Dictionary # Remember what the value of the data was before editing
# The data that represents this furniture
# The data is selected from the Gamedata.data.furniture.data array
# based on the ID that the user has selected in the content editor
var contentData: Dictionary = {}:
	set(value):
		contentData = value
		load_furniture_data()
		furnitureSelector.sprites_collection = Gamedata.data.furniture.sprites
		olddata = contentData.duplicate(true)


func _ready():
	# For properly using the tab key to switch elements
	control_elements = [furnitureImageDisplay,NameTextEdit,DescriptionTextEdit]
	data_changed.connect(Gamedata.on_data_changed)
	set_drop_functions()


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
	if destructionTextEdit:
		destructionTextEdit.set_text(contentData.get("destruction_group", ""))
	if disassemblyTextEdit:
		disassemblyTextEdit.set_text(contentData.get("disassembly_group", ""))

	# Load container data if it exists within the 'Function' property
	var function_data = contentData.get("Function", {})
	if "container" in function_data:
		containerCheckBox.button_pressed = true  # Check the container checkbox
		var container_data = function_data["container"]
		if "itemgroup" in container_data:
			containerTextEdit.set_text(container_data["itemgroup"])  # Set text edit with the itemgroup ID
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
	# Save the destruction group only if there is a value
	if destructionTextEdit.get_text().strip_edges() != "":
		contentData["destruction_group"] = destructionTextEdit.get_text()
	else:
		# Remove the key if no value is present to avoid storing empty or outdated data
		contentData.erase("destruction_group")

	# Save the disassembly group only if there is a value
	if disassemblyTextEdit.get_text().strip_edges() != "":
		contentData["disassembly_group"] = disassemblyTextEdit.get_text()
	else:
		# Remove the key if no value is present to avoid storing empty or outdated data
		contentData.erase("disassembly_group")
	
	handle_door_option()
	
	# Check if the container should be saved
	if containerCheckBox.is_pressed():
		# Initialize 'Function' dictionary if it doesn't exist
		if "Function" not in contentData:
			contentData["Function"] = {}
			
		# the container will remain empty if no itemgroup is set, 
		# which will just act as an empty container
		if containerTextEdit.get_text() != "":
			# Update or set the container property within the 'Function' dictionary
			contentData["Function"]["container"] = {"itemgroup": containerTextEdit.get_text()}
		else: # No itemgroup provided, it's an emtpy container
			contentData["Function"]["container"] = {}
	elif "Function" in contentData and "container" in contentData["Function"]:
		# If the checkbox is not checked or text edit is empty, remove the container data
		contentData["Function"].erase("container")
		# If the 'Function' dictionary becomes empty, remove it as well
		if contentData["Function"].is_empty():
			contentData.erase("Function")

	data_changed.emit(Gamedata.data.furniture, contentData, olddata)
	olddata = contentData.duplicate(true)


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


# Called when the user has successfully dropped data onto the ItemGroupTextEdit
# We have to check the dropped_data for the id property
func itemgroup_drop(dropped_data: Dictionary, texteditcontrol: TextEdit) -> void:
	# Assuming dropped_data is a Dictionary that includes an 'id'
	if dropped_data and "id" in dropped_data:
		var itemgroup_id = dropped_data["id"]
		var itemgroup_data = Gamedata.get_data_by_id(Gamedata.data.itemgroups, itemgroup_id)
		if itemgroup_data.is_empty():
			print_debug("No item data found for ID: " + itemgroup_id)
			return
		texteditcontrol.text = itemgroup_id
	else:
		print_debug("Dropped data does not contain an 'id' key.")


func can_itemgroup_drop(dropped_data: Dictionary, texteditcontrol: TextEdit):
	# Check if the containerCheckBox is checked; if not, return false
	# Only applies to containerTextEdit
	if texteditcontrol == containerTextEdit and not containerCheckBox.is_pressed():
		return false

	# Check if the data dictionary has the 'id' property
	if not dropped_data or not dropped_data.has("id"):
		return false
	
	# Fetch itemgroup data by ID from the Gamedata to ensure it exists and is valid
	var itemgroup_data = Gamedata.get_data_by_id(Gamedata.data.itemgroups, dropped_data["id"])
	if itemgroup_data.is_empty():
		return false

	# If all checks pass, return true
	return true


func set_drop_functions():
	containerTextEdit.drop_function = itemgroup_drop.bind(containerTextEdit.mytextedit)
	containerTextEdit.can_drop_function = can_itemgroup_drop.bind(containerTextEdit.mytextedit)
	disassemblyTextEdit.drop_function = itemgroup_drop.bind(disassemblyTextEdit.mytextedit)
	disassemblyTextEdit.can_drop_function = can_itemgroup_drop.bind(disassemblyTextEdit.mytextedit)
	destructionTextEdit.drop_function = itemgroup_drop.bind(destructionTextEdit.mytextedit)
	destructionTextEdit.can_drop_function = can_itemgroup_drop.bind(destructionTextEdit.mytextedit)
