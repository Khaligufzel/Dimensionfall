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

@export var destroyHboxContainer: HBoxContainer = null # contains destroy controls
@export var canDestroyCheckbox: CheckBox = null # If the furniture can be destroyed or not
@export var destructionTextEdit: HBoxContainer = null # Might contain the id of a loot group
@export var destructionImageDisplay: TextureRect = null # What it looks like when destroyed
@export var destructionSpriteNameLabel: Label = null # The name of the destroyed sprite

@export var disassemblyHboxContainer: HBoxContainer = null # contains destroy controls
@export var canDisassembleCheckbox: CheckBox = null # If the furniture can be disassembled or not
@export var disassemblyTextEdit: HBoxContainer = null # Might contain the id of a loot group
@export var disassemblyImageDisplay: TextureRect = null # What it looks like when disassembled
@export var disassemblySpriteNameLabel: Label = null # The name of the disassembly sprite

# For controlling the focus when the tab button is pressed
var control_elements: Array = []
# Tracks which image display control is currently being updated
var current_image_display: String = ""


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
		
	if "destruction" in contentData:
		canDestroyCheckbox.button_pressed = true
		var destruction_data = contentData["destruction"]
		destructionTextEdit.set_text(destruction_data.get("group", ""))
		if destruction_data.has("sprite"):
			destructionImageDisplay.texture = Gamedata.data.furniture.sprites[destruction_data["sprite"]]
			destructionSpriteNameLabel.text = destruction_data["sprite"]
		else:
			destructionImageDisplay.texture = null
			destructionSpriteNameLabel.text = ""
	else:
		canDestroyCheckbox.button_pressed = false

	if "disassembly" in contentData:
		canDisassembleCheckbox.button_pressed = true
		var disassembly_data = contentData["disassembly"]
		disassemblyTextEdit.set_text(disassembly_data.get("group", ""))
		if disassembly_data.has("sprite"):
			disassemblyImageDisplay.texture = Gamedata.data.furniture.sprites[disassembly_data["sprite"]]
			disassemblySpriteNameLabel.text = disassembly_data["sprite"]
		else:
			disassemblyImageDisplay.texture = null
			disassemblySpriteNameLabel.text = ""
	else:
		canDisassembleCheckbox.button_pressed = false

	# Load container data if it exists within the 'Function' property
	var function_data = contentData.get("Function", {})
	if "container" in function_data:
		containerCheckBox.button_pressed = true  # Check the container checkbox
		var container_data = function_data["container"]
		if "itemgroup" in container_data:
			containerTextEdit.set_text(container_data["itemgroup"])  # Set text edit with the itemgroup ID
		else:
			containerTextEdit.mytextedit.clear()  # Clear the text edit if no itemgroup is specified
	else:
		containerCheckBox.button_pressed = false  # Uncheck the container checkbox
		containerTextEdit.mytextedit.clear()  # Clear the text edit as no container data is present


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
	handle_container_option()
	handle_destruction_option()
	handle_disassembly_option()

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


func handle_container_option():
	if containerCheckBox.is_pressed():
		if "Function" not in contentData:
			contentData["Function"] = {}
		if containerTextEdit.get_text() != "":
			contentData["Function"]["container"] = {"itemgroup": containerTextEdit.get_text()}
		else:
			contentData["Function"]["container"] = {}
	elif "Function" in contentData and "container" in contentData["Function"]:
		contentData["Function"].erase("container")
		if contentData["Function"].is_empty():
			contentData.erase("Function")

func handle_destruction_option():
	if canDestroyCheckbox.is_pressed():
		if "destruction" not in contentData:
			contentData["destruction"] = {}
		if destructionTextEdit.get_text() != "":
			contentData["destruction"]["group"] = destructionTextEdit.get_text()
		if destructionSpriteNameLabel.text != "":
			contentData["destruction"]["sprite"] = destructionSpriteNameLabel.text
		else:
			contentData["destruction"].erase("sprite")
	elif "destruction" in contentData:
		contentData.erase("destruction")

func handle_disassembly_option():
	if canDisassembleCheckbox.is_pressed():
		if "disassembly" not in contentData:
			contentData["disassembly"] = {}
		if disassemblyTextEdit.get_text() != "":
			contentData["disassembly"]["group"] = disassemblyTextEdit.get_text()
		if disassemblySpriteNameLabel.text != "":
			contentData["disassembly"]["sprite"] = disassemblySpriteNameLabel.text
		else:
			contentData["disassembly"].erase("sprite")
	elif "disassembly" in contentData:
		contentData.erase("disassembly")

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


func _on_container_check_box_toggled(toggled_on):
	if not toggled_on:
		containerTextEdit.mytextedit.clear()


# Called when the user has successfully dropped data onto the ItemGroupTextEdit
# We have to check the dropped_data for the id property
func itemgroup_drop(dropped_data: Dictionary, texteditcontrol: HBoxContainer) -> void:
	# Assuming dropped_data is a Dictionary that includes an 'id'
	if dropped_data and "id" in dropped_data:
		var itemgroup_id = dropped_data["id"]
		var itemgroup_data = Gamedata.get_data_by_id(Gamedata.data.itemgroups, itemgroup_id)
		if itemgroup_data.is_empty():
			print_debug("No item data found for ID: " + itemgroup_id)
			return
		texteditcontrol.set_text(itemgroup_id)
		# If it's the container group, we always set the container checkbox to true
		if texteditcontrol == containerTextEdit:
			containerCheckBox.button_pressed = true
		if texteditcontrol == destructionTextEdit:
			canDestroyCheckbox.button_pressed = true
		if texteditcontrol == disassemblyTextEdit:
			canDisassembleCheckbox.button_pressed = true
	else:
		print_debug("Dropped data does not contain an 'id' key.")


func can_itemgroup_drop(dropped_data: Dictionary):
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
	containerTextEdit.drop_function = itemgroup_drop.bind(containerTextEdit)
	containerTextEdit.can_drop_function = can_itemgroup_drop
	disassemblyTextEdit.drop_function = itemgroup_drop.bind(disassemblyTextEdit)
	disassemblyTextEdit.can_drop_function = can_itemgroup_drop
	destructionTextEdit.drop_function = itemgroup_drop.bind(destructionTextEdit)
	destructionTextEdit.can_drop_function = can_itemgroup_drop


# When the furnitureImageDisplay is clicked, the user will be prompted to select an image from
# "res://Mods/Core/Furnitures/". The texture of the furnitureImageDisplay will change to the selected image
func _on_furniture_image_display_gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		current_image_display = "furniture"
		furnitureSelector.show()

func _on_disassemble_image_display_gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		current_image_display = "disassemble"
		furnitureSelector.show()

func _on_destruction_image_display_gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		current_image_display = "destruction"
		furnitureSelector.show()

func _on_sprite_selector_sprite_selected_ok(clicked_sprite) -> void:
	var furnitureTexture: Resource = clicked_sprite.get_texture()
	if current_image_display == "furniture":
		furnitureImageDisplay.texture = furnitureTexture
		imageNameStringLabel.text = furnitureTexture.resource_path.get_file()
	elif current_image_display == "disassemble":
		disassemblyImageDisplay.texture = furnitureTexture
		disassemblySpriteNameLabel.text = furnitureTexture.resource_path.get_file()
	elif current_image_display == "destruction":
		destructionImageDisplay.texture = furnitureTexture
		destructionSpriteNameLabel.text = furnitureTexture.resource_path.get_file()


# Utility function to set the visibility of all children of the given container except the first one
func set_visibility_for_children(container: Control, visible: bool):
	for i in range(1, container.get_child_count()):
		container.get_child(i).visible = visible

func _on_can_destroy_check_box_toggled(toggled_on):
	if not toggled_on:
		destructionTextEdit.mytextedit.clear()
		destructionSpriteNameLabel.text = ""
		destructionImageDisplay.texture = load("res://Scenes/ContentManager/Mapeditor/Images/emptyTile.png")
	set_visibility_for_children(destructionTextEdit, toggled_on)

func _on_can_disassemble_check_box_toggled(toggled_on):
	if not toggled_on:
		disassemblyTextEdit.mytextedit.clear()
		disassemblySpriteNameLabel.text = ""
		disassemblyImageDisplay.texture = load("res://Scenes/ContentManager/Mapeditor/Images/emptyTile.png")
	set_visibility_for_children(disassemblyHboxContainer, toggled_on)
