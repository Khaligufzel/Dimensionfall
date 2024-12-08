extends Control

# This scene is a control which lists content from any loaded mods
# It allows users to select content for editing and creating new content
# This node should be used to load everything from one specific json file or one directory
# The json file or directory is specified by setting the source variable
# This node is intended to be used in the content editor

@export var contentItems: ItemList = null
@export var collapseButton: Button = null
@export var pupup_ID: Popup = null
@export var popup_textedit: TextEdit = null
signal item_activated(type: DMod.ContentType, itemID: String, list: Control)
var popupAction: String = ""
var datainstance: RefCounted # One of the data classes like DMap, DTile, DMob and so on
var mod_id: String = "Core"
var contentType: DMod.ContentType:
	set(newData):
		contentType = newData
		if newData == DMod.ContentType.STATS or newData == DMod.ContentType.WEARABLESLOTS or newData == DMod.ContentType.PLAYERATTRIBUTES or newData == DMod.ContentType.QUESTS or newData == DMod.ContentType.SKILLS or newData == DMod.ContentType.OVERMAPAREAS or newData == DMod.ContentType.TILES or newData == DMod.ContentType.TACTICALMAPS or newData == DMod.ContentType.MAPS:
			# Use mod-specific data for these content types
			datainstance = Gamedata.mods.by_id(mod_id).get_data_of_type(contentType)
		else:
			# Use global data for other content types
			datainstance = Gamedata.get_data_of_type(contentType)
		load_data()


var header: String = "Items":
	set(newName):
		header = newName
		collapseButton.text = header


var is_collapsed: bool = false:
	get:
		return is_collapsed
	set(value):
		is_collapsed = value
		set_collapsed()
		save_collapse_state()



func _ready():
	contentItems.set_drag_forwarding(_create_drag_data, Callable(), Callable())


# This function adds items to the content list based on the provided path
# If the path is a directory, it will list all the files in the directory
# If the path is a json file, it will list all the items in the json file
func load_data():
	contentItems.clear()
	load_list()
	load_collapse_state()

# Executed when an item in ContentItems is double-clicked or 
# when the user selects an item in ContentItems and presses enter
# Index is the position in the ContentItems list starting from 0
func _on_content_items_item_activated(index: int):
	# Get the id of the item from the metadata
	var strItemID: String = contentItems.get_item_metadata(index)
	if strItemID:
		item_activated.emit(contentType, strItemID, self)
	else:
		print_debug("Tried to signal that item with ID (" + str(index) + ") was activated,\
		 but the item has no metadata")

# This function will append an item to the game data
func add_item_to_data(id: String):
	Gamedata.add_id_to_data(contentType, id)
	load_data()

# This function will show a pop-up asking the user to input an ID
func _on_add_button_button_up():
	popupAction = "Add"
	popup_textedit.text = ""
	pupup_ID.show()

# This function requires that an item from the list is selected
# Once clicked, it will show pupup_ID to ask the user for a new ID
# If the user enters an ID and presses OK, it will read the file from the source variable
# And duplicate the item that has the same ID as the ID that was selected
# The duplicate item will recieve the ID that the user has entered in the popup
# Lastly, the new duplicated item will be added to contentItems
func _on_duplicate_button_button_up():
	var selected_id: String = get_selected_item_text()
	if selected_id == "":
		return
	popupAction = "Duplicate"
	popup_textedit.text = selected_id
	pupup_ID.show()

# Called after the user enters an ID into the popup textbox and presses OK
func _on_ok_button_up():
	pupup_ID.hide()
	var myText = popup_textedit.text
	if myText == "":
		return
	if popupAction == "Add":
		datainstance.add_new(myText)
	if popupAction == "Duplicate":
		datainstance.duplicate_to_disk(get_selected_item_text(), myText)
	popupAction = ""
	# Check if the list is collapsed and expand it if true
	if is_collapsed:
		is_collapsed = false
	load_data()


# Called after the users presses cancel on the popup asking for an ID
func _on_cancel_button_up():
	pupup_ID.hide()
	popupAction = ""

# This function requires that an item from the list is selected
# Once clicked, the selected item will be removed from contentItems
# It will also remove the item from the json file specified by source
func _on_delete_button_button_up():
	var selected_id: String = get_selected_item_text()
	if selected_id == "":
		return
	delete(selected_id)


func get_selected_item_text() -> String:
	if not contentItems.is_anything_selected():
		return ""
	return contentItems.get_item_text(contentItems.get_selected_items()[0])


# This function will collapse and expand the $Content/ContentItems when the collapse button is pressed
func _on_collapse_button_button_up():
	is_collapsed = !is_collapsed


func set_collapsed():
	contentItems.visible = not is_collapsed
	if not is_collapsed:
		size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		size_flags_vertical = Control.SIZE_SHRINK_BEGIN


# Function to initiate drag data for selected item
# Only one item can be selected and dragged at a time.
# We get the selected item from contentItems
# This function should return a new object with an id property that holds the item's text
func _create_drag_data(_newpos):
	# Check if an item is selected
	var selected_index = contentItems.get_selected_items()
	if selected_index.size() == 0:
		return null  # No item selected, so no drag data should be initiated

	# Get the selected item text and ID (metadata, which should be the item ID)
	selected_index = selected_index[0]  # Take the first item in case of multiple (unlikely, but safe)
	var selected_item_text = contentItems.get_item_text(selected_index)
	var selected_item_id = contentItems.get_item_metadata(selected_index)

	# Create a drag preview
	var preview = _create_drag_preview(selected_item_id)
	set_drag_preview(preview)

	# Return an object with the necessary data, including mod_id and contentType
	return {
		"id": selected_item_id,
		"text": selected_item_text,
		"mod_id": mod_id,
		"contentType": contentType
	}



# This function should return true if the dragged data can be dropped here
func _can_drop_data(_newpos, _data) -> bool:
	return false


# This function handles the data being dropped
func _drop_data(newpos, data) -> void:
	if _can_drop_data(newpos, data):
		print_debug("tried to drop data, but can't")


# Helper function to create a preview Control for dragging
func _create_drag_preview(item_id: String) -> Control:
	var preview = TextureRect.new()
	if not contentType == DMod.ContentType.TACTICALMAPS and not contentType == DMod.ContentType.OVERMAPAREAS and not contentType == DMod.ContentType.MOBFACTIONS:
		preview.texture = datainstance.sprite_by_id(item_id)

	preview.custom_minimum_size = Vector2(32, 32)  # Set the desired size for your preview
	return preview


var start_point
var end_point
var mouse_button_is_pressed
# Overriding the _gui_input function to detect drag attempts
func _on_content_items_gui_input(event):
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if event.is_pressed():
					start_point = event.global_position
					mouse_button_is_pressed = true
				else:
					# Finalize drawing/copying operation
					end_point = event.global_position
					if mouse_button_is_pressed:
						var drag_threshold: int = 5  # Pixels
						var distance_dragged = start_point.distance_to(end_point)
						
						if distance_dragged <= drag_threshold:
							print_debug("Released the mouse button, but clicked instead of dragged")
					mouse_button_is_pressed = false


func _on_content_items_mouse_entered():
	mouse_button_is_pressed = false


func save_collapse_state():
	var config = ConfigFile.new()
	var path = "user://settings.cfg"
	
	# Ensure to load existing settings to not overwrite them
	var err = config.load(path)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		print("Failed to load settings:", err)
		return

	config.set_value("contenteditor:contentlist:" + header, "is_collapsed", is_collapsed)
	config.save(path)


func load_collapse_state():
	var config = ConfigFile.new()
	var path = "user://settings.cfg"
	
	# Load the config file
	var err = config.load(path)
	if err == OK:
		if config.has_section_key("contenteditor:contentlist:" + header, "is_collapsed"):
			is_collapsed = config.get_value("contenteditor:contentlist:" + header, "is_collapsed")
			set_collapsed()
		else:
			print("No saved state for:", header)
	else:
		print("Failed to load settings for:", header, "with error:", err)


# Load the quests list
func load_list():
	for entry: RefCounted in datainstance.get_all().values():
		# Add all the filenames to the ContentItems list as child nodes
		var item_index: int = contentItems.add_item(entry.id)
		# Add the ID as metadata which can be used to load the quest data
		contentItems.set_item_metadata(item_index, entry.id)
		if "sprite" in entry:
			contentItems.set_item_icon(item_index, entry.sprite)

func delete(selected_id) -> void:
	Gamedata.get_data_of_type(contentType).delete_by_id(selected_id)
	load_data()
