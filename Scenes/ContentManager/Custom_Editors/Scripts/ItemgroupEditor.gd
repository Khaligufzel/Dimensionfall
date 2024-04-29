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
@export var selectedItemNameDisplay: Label = null
@export var itemList: ItemList = null
# For controlling the focus when the tab button is pressed
var control_elements: Array = []
# Will keep track of the id's in the itemgroup list when it was loaded or saved
# This is used to compare the list when it is saved and see the difference
var old_list: Array[String] = []


# The data that represents this itemgroup
# The data is selected from the Gamedata.data.itemgroup.data array
# based on the ID that the user has selected in the content editor
var contentData: Dictionary = {}:
	set(value):
		contentData = value
		load_itemgroup_data()
		itemgroupSelector.sprites_collection = Gamedata.data.itemgroups.sprites


# This signal will be emitted when the user presses the save button
# This signal should alert Gamedata that the itemgroup data array should be saved to disk
# The content editor has connected this signal to Gamedata already
signal data_changed()
signal itemlist_changed(itemgroup: String, oldlist: Array[String], newlist: Array[String])


func _ready():
	control_elements = [itemgroupImageDisplay,NameTextEdit,DescriptionTextEdit]
	itemlist_changed.connect(Gamedata.on_itemgroup_changed)


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
	# Load the items into the itemList
	itemList.clear()  # Clear the list before populating
	if contentData.has("items"):
		for item_id in contentData["items"]:
			# Get item data and sprite from the game data
			var item_data = Gamedata.get_data_by_id(Gamedata.data.items, item_id)
			if not item_data.is_empty():
				var item_sprite = Gamedata.get_sprite_by_id(Gamedata.data.items, item_id)
				var item_index = itemList.add_item(item_data.get("name", "Unnamed Item"), item_sprite)
				itemList.set_item_metadata(item_index, item_id)
				old_list.append(item_id)  # Add to old list for comparison
	_refresh_old_list()


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
	
	# Collect all item IDs from the itemList and update the contentData accordingly
	var newlist: Array[String] = []
	for i in range(itemList.get_item_count()):
		var item_id = itemList.get_item_metadata(i)  # Assuming metadata holds the item ID
		newlist.append(item_id)
	
	if newlist.size() > 0:
		contentData["items"] = newlist
	elif contentData.has("items"):
		contentData.erase("items")  # Delete the "items" property if the list is empty
	
	# Check if there are any changes between old and new item lists
	if _is_itemList_changed():
		itemlist_changed.emit(contentData.id, old_list, newlist)
	
	# Update the old_list as the new baseline for future changes
	old_list = newlist.duplicate()
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


# This function should return true if the dragged data can be dropped here
func _can_drop_data(_newpos, data) -> bool:
	# Check if the data dictionary has the 'id' property
	if not data or not data.has("id"):
		return false
	
	# Fetch item data by ID from the Gamedata to ensure it exists and is valid
	var item_data = Gamedata.get_data_by_id(Gamedata.data.items, data["id"])
	if item_data.is_empty():
		return false

	# Check if the ID of the dragged item already exists in the itemList
	for i in range(itemList.get_item_count()):
		if itemList.get_item_metadata(i) == data["id"]:
			return false

	# If all checks pass, return true
	return true


# This function handles the data being dropped
func _drop_data(newpos, data) -> void:
	if _can_drop_data(newpos, data):
		_handle_item_drop(data, newpos)


# Called when the user has successfully dropped data onto the itemList
# We have to check the dropped_data for the id property
# Then we have to get the item data from Gamedata.get_data_by_id(Gamedata.data.items, id)
# Then we have to get the sprite using Gamedata.get_sprite_by_id(Gamedata.data.items, id)
# Then we have to create a new item in itemList using the id as the text and the sprite as the icon
func _handle_item_drop(dropped_data, _newpos) -> void:
	# Assuming dropped_data is a Dictionary that includes an 'id'
	if dropped_data and "id" in dropped_data:
		var item_id = dropped_data["id"]
		var item_data = Gamedata.get_data_by_id(Gamedata.data.items, item_id)
		if item_data.is_empty():
			print_debug("No item data found for ID: " + item_id)
			return
		
		# Retrieve the sprite for the item
		var item_sprite = Gamedata.get_sprite_by_id(Gamedata.data.items, item_id)
		if item_sprite:
			# Add the item to the itemList with the retrieved sprite as an icon
			var item_index = itemList.add_item(item_id, item_sprite)
			itemList.set_item_metadata(item_index, item_id)  # Store the item ID as metadata
		else:
			print_debug("No sprite found for item with ID: " + item_id)
	else:
		print_debug("Dropped data does not contain an 'id' key.")


# The user clicked in the list, but not on any of the items
# Deselect all items and reset the selectedItemNameDisplay label
func _on_item_list_empty_clicked(_at_position, _mouse_button_index):
	itemList.deselect_all()  # Deselect any selected items
	selectedItemNameDisplay.text = "No item selected"  # Reset the display label


# The user has selected an item from the list
# Update the selectedItemNameDisplay label to show the selected item's text
func _on_item_list_item_selected(index):
	var item_text = itemList.get_item_text(index)  # Get the text of the selected item
	selectedItemNameDisplay.text = item_text  # Display the text in the label


# The user has released the remove item button after pressing it
# We have to check if an item is selected in the itemList
# If an item is selected, we remove it from the list and update the selectedItemNameDisplay label
# If no item is selected, we do nothing
func _on_remove_item_button_button_up():
	var selected_index = itemList.get_selected_items()
	if selected_index.size() > 0:
		# Get the first selected item index (since multiple selections might be disabled, this is safe)
		selected_index = selected_index[0]
		itemList.remove_item(selected_index)
		selectedItemNameDisplay.text = "No item selected"  # Update the display label after removing an item
		print_debug("Item removed at index: " + str(selected_index))
	else:
		print_debug("No item selected to remove")


# Function to refresh old_list with the current item IDs in itemList
func _refresh_old_list():
	old_list.clear()  # Clear the current contents of old_list
	for i in range(itemList.get_item_count()):
		var item_id = itemList.get_item_metadata(i)  # Get the item ID stored in metadata
		old_list.append(item_id)  # Add the item ID to old_list


# Function to compare old_list with the current itemList IDs
func _is_itemList_changed() -> bool:
	var current_list: Array = []
	for i in range(itemList.get_item_count()):
		var item_id = itemList.get_item_metadata(i)  # Assuming metadata holds the item ID
		current_list.append(item_id)
	
	# Check if old_list and current_list have the same size and the same elements in the same order
	if old_list.size() != current_list.size():
		return true  # Sizes are different, lists are not the same
	
	for i in range(old_list.size()):
		if old_list[i] != current_list[i]:
			return true  # Found a difference in one of the positions
	
	return false  # No differences found
