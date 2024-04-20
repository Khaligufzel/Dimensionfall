extends Control

#This scene is a control which lists content from any loaded mods
#It allows users to select content for editing and creating new content
#This node should be used to load everything from one specific json file or one directory
#The json file or directory is specified by setting the source variable
#This node is intended to be used in the content editor

@export var contentItems: ItemList = null
@export var collapseButton: Button = null
@export var pupup_ID: Popup = null
@export var popup_textedit: TextEdit = null
signal item_activated(data: Array, itemID: String)
var is_collapsed: bool = false
var popupAction: String = ""
var contentData: Dictionary = {}:
	set(newData):
		contentData = newData
		load_data()
var header: String = "Items":
	set(newName):
		header = newName
		collapseButton.text = header



#This function adds items to the content list based on the provided path
#If the path is a directory, it will list all the files in the directory
#If the path is a json file, it will list all the items in the json file
func load_data():
	if contentData.is_empty():
		return
	contentItems.clear()
	if !contentData.has("data"):
		return
	if contentData.data.is_empty():
		return
	#If the first item is a string, it's a list of files.
	#Otherwise, it's a list of objects representing some kind of data
	if contentData.data[0] is String:
		make_file_list()
	else:
		make_item_list()

# Loops over all the items in contentData.data (which are dictionaries)
# Creates a new item in the list with the id of the item as text
func make_item_list():
	for item in contentData.data:
		# get the id of the item, "missing_id" if not found
		var item_id: String = item.get("id", "missing_id")
		#Add the item and save the index number
		var item_index: int = contentItems.add_item(item_id)
		contentItems.set_item_metadata(item_index, item_id)
		contentItems.set_item_icon(item_index,get_item_sprite(item))


func get_item_sprite(item) -> Texture2D:
	if item.has("sprite") and contentData.sprites.has(item["sprite"]):
		var mySprite: Resource = contentData.sprites[item["sprite"]]
		if mySprite is BaseMaterial3D:
			return mySprite.albedo_texture
		else:
			return mySprite
	return null
	

# Loops over the files in contentData.data (which are filenames)
# For each file, a new item will be added to the list
func make_file_list() -> void:
	for file_name in contentData.data:
		# Extract the base name without the extension
		var base_name = file_name.get_basename()

		# Add all the filenames to the ContentItems list as child nodes
		var item_index: int = contentItems.add_item(base_name)
		# Add the ID as metadata which can be used to load the item data
		contentItems.set_item_metadata(item_index, base_name)

		# If the file has an image to represent it's content, load it
		if contentData.has("sprites") and contentData.sprites.has(base_name + ".png"):
			var mySprite: Resource = contentData.sprites[base_name + ".png"]
			if mySprite:
				contentItems.set_item_icon(item_index, mySprite)


# Executed when an item in ContentItems is double-clicked or 
# when the user selects an item in ContentItems and presses enter
# Index is the position in the ContentItems list starting from 0
func _on_content_items_item_activated(index: int):
	# Get the id of the item from the metadata
	var strItemID: String = contentItems.get_item_metadata(index)
	if strItemID:
		item_activated.emit(contentData, strItemID)
	else:
		print_debug("Tried to signal that item with ID (" + str(index) + ") was activated,\
		 but the item has no metadata")

#This function will append an item to the game data
func add_item_to_data(id: String):
	Gamedata.add_id_to_data(contentData, id)
	load_data()
	
#This function will show a pop-up asking the user to input an ID
func _on_add_button_button_up():
	popupAction = "Add"
	popup_textedit.text = ""
	pupup_ID.show()

#This function requires that an item from the list is selected
#Once clicked, it will show pupup_ID to ask the user for a new ID
#If the user enters an ID and presses OK, it will read the file from the source variable
#And duplicate the item that has the same ID as the ID that was selected
#The duplicate item will recieve the ID that the user has entered in the popup
#Lastly, the new duplicated item will be added to contentItems
func _on_duplicate_button_button_up():
	var selected_id: String = get_selected_item_text()
	if selected_id == "":
		return
	popupAction = "Duplicate"
	popup_textedit.text = selected_id
	pupup_ID.show()
	

#Called after the user enters an ID into the popup textbox and presses OK
func _on_ok_button_up():
	pupup_ID.hide()
	var myText = popup_textedit.text
	if myText == "":
		return;
	if popupAction == "Add":
			Gamedata.add_id_to_data(contentData, myText)
	if popupAction == "Duplicate":
		# This is true if contentData.data is an array of strings
		# Else, it will be an array of dictionaries
		if contentData.data[0] is String:
			Gamedata.duplicate_file_in_data(contentData,get_selected_item_text(),myText)
		else:
			Gamedata.duplicate_item_in_data(contentData,get_selected_item_text(),myText)
	popupAction = ""
	load_data()

#Called after the users presses cancel on the popup asking for an ID
func _on_cancel_button_up():
	pupup_ID.hide()
	popupAction = ""

#This function requires that an item from the list is selected
#Once clicked, the selected item will be removed from contentItems
#It will also remove the item from the json file specified by source
func _on_delete_button_button_up():
	var selected_id: String = get_selected_item_text()
	if selected_id == "":
		return
	contentItems.remove_item(contentItems.get_selected_items()[0])
	Gamedata.remove_item_from_data(contentData, selected_id)
	load_data()

func get_selected_item_text() -> String:
	if !contentItems.is_anything_selected():
		return ""
	return contentItems.get_item_text(contentItems.get_selected_items()[0])

#This function will collapse and expand the $Content/ContentItems when the collapse button is pressed
func _on_collapse_button_button_up():
	contentItems.visible = is_collapsed
	if is_collapsed:
		size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	is_collapsed = !is_collapsed


# Function to initiate drag data for selected item
# Only one item can be selectedand dragged at a time.
# We get the selected item from contentItems
# This function should return a new object with an id property that holds the item's text
func _get_drag_data(_newpos):
	# Check if an item is selected
	var selected_index = contentItems.get_selected_items()
	if selected_index.size() == 0:
		return null  # No item selected, so no drag data should be initiated

	# Get the selected item text and ID (metadata, which should be the item ID)
	selected_index = selected_index[0]  # Take the first item in case of multiple (unlikely, but safe)
	var selected_item_text = contentItems.get_item_text(selected_index)
	var selected_item_id = contentItems.get_item_metadata(selected_index)

	# Create a drag preview
	#var preview = _create_drag_preview(selected_item_id)
	#set_drag_preview(preview)

	# Return an object with the necessary data
	return {"id": selected_item_id, "text": selected_item_text}


# This function should return true if the dragged data can be dropped here
func _can_drop_data(_newpos, data) -> bool:
	return false


# This function handles the data being dropped
func _drop_data(newpos, data) -> void:
	if _can_drop_data(newpos, data):
		print_debug("tried to drop data, but can't")


# Helper function to create a preview Control for dragging
func _create_drag_preview(item_id: String) -> Control:
	var preview = TextureRect.new()
	preview.texture = Gamedata.get_sprite_by_id(contentData, item_id)
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
						var drag_threshold: int = 5 # Pixels
						var distance_dragged = start_point.distance_to(end_point)
						
						if distance_dragged <= drag_threshold:
							print_debug("Released the mouse button, but clicked instead of dragged")
					mouse_button_is_pressed = false
	#When the users presses and holds the mouse wheel, we scoll the grid
	if event is InputEventMouseMotion:
		end_point = event.global_position
		if mouse_button_is_pressed:
			if not _get_drag_data(end_point) == null:
				var drag_data: Dictionary = _get_drag_data(end_point)
				force_drag(drag_data, _create_drag_preview(drag_data.id))


func _on_content_items_mouse_entered():
	mouse_button_is_pressed = false
