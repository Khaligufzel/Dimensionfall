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
signal item_activated(strSource: String, itemID: String)
var is_collapsed: bool = true
var popupAction: String = ""
var source: String = "":
	set(path):
		source = path
		load_data()
var header: String = "Items":
	set(newName):
		header = newName
		collapseButton.text = header

#This function will collapse and expand the $Content/ContentItems when the collapse button is pressed
func _on_collapse_button_button_up():
	$Content/ContentItems.visible = is_collapsed
	is_collapsed = !is_collapsed


# This function will take a string and create a new json file with just {} as the contents.
#If the file already exists, we do not overwrite it
func create_new_json_file(filename: String = "", isArray: bool = true):
	# If no string was provided, return without doing anything.
	if filename.is_empty():
		return

	# If the file already exists, alert the user that the file already exists.
	if FileAccess.file_exists(filename):
#		print_debug("The file already exists: " + filename)
		return

	var file = FileAccess.open(filename, FileAccess.WRITE)
	#The file cen contain either one object or one array with a list of objects
	if isArray:
		file.store_string("[]")
	else:
		file.store_string("{}")
	file.close()
	load_data()


#This function adds items to the content list based on the provided path
#If the path is a directory, it will list all the files in the directory
#If the path is a json file, it will list all the items in the json file
func load_data():
	if source == "":
		return
	contentItems.clear()
	if source.ends_with(".json"):
		load_file()
	else:
		load_dir()
	
func load_file():
	create_new_json_file(source)
	# Save the JSON string to the selected file location
	var file = FileAccess.open(source, FileAccess.READ)
	if file:
		var data_json: Array
		data_json = JSON.parse_string(file.get_as_text())
		for item in data_json:
			# get the id of the item, "missing_id" if not found
			var item_id: String = item.get("id", "missing_id")
			#Add the item and save the index number
			var item_index: int = contentItems.add_item(item_id)
			contentItems.set_item_metadata(item_index, item_id)
			
			if item.has("imagePath"):
				contentItems.set_item_icon(item_index,load(item["imagePath"]))
	else:
		print_debug("Unable to load file: " + source)
	
func load_dir():
	var dir = DirAccess.open(source)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if !dir.current_is_dir() and file_name.get_extension() == "json":
				# Add all the filenames to the ContentItems list as child nodes
				var item_index: int = contentItems.add_item(file_name.replace(".json", ""))
				#Add the ID as metadata which can be used to load the item data
				contentItems.set_item_metadata(item_index, file_name.replace(".json", ""))
			file_name = dir.get_next()
	else:
		print_debug("An error occurred when trying to access the path: " + source)
	dir.list_dir_end()


func _on_content_items_item_activated(index):
	var strItemID: String = contentItems.get_item_metadata(index)
	if strItemID:
		item_activated.emit(source, strItemID)
	else:
		print_debug("Tried to signal that item with ID (" + str(index) + ") was activated,\
		 but the item has no metadata")


#This function enters a new item into the json file specified by the source variable
#The item will just be an object like this: {"id": id}
#If an item with that ID already exists in that file, do nothing
func add_item_to_json_file(id: String):
# If the source is not a JSON file, return without doing anything.
	if !source.ends_with(".json"):
		return

	# If the file does not exist, create a new JSON file.
	if !FileAccess.file_exists(source):
		create_new_json_file(source, true)

	# Open the file and load the JSON data.
	var file = FileAccess.open(source, FileAccess.READ)
	var data_json: Array
	if file:
		data_json = JSON.parse_string(file.get_as_text())
		file.close()
	else:
		print_debug("Unable to load file: " + source)
		return

	# Check if an item with the given ID already exists in the file.
	for item in data_json:
		if item.get("id", "") == id:
			print_debug("An item with ID (" + id + ") already exists in the file.")
			return

	# If no item with the given ID exists, add a new item to the JSON data.
	data_json.append({"id": id})

	# Save the updated JSON data to the file.
	file = FileAccess.open(source, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data_json))
		file.close()
	else:
		print_debug("Unable to write to file: " + source)
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
	if popup_textedit.text == "":
		return;
	if popupAction == "Add":
		if source.ends_with(".json"):
			add_item_to_json_file(popup_textedit.text)
		else:
			create_new_json_file(source + popup_textedit.text + ".json", false)
	if popupAction == "Duplicate":
		if source.ends_with(".json"):
			duplicate_item_in_json_file(get_selected_item_text(), popup_textedit.text)
		else:
			print_debug("There should be code here for when a json file gets duplicated")
	popupAction = ""

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
	if source.ends_with(".json"):
		remove_item_from_json_file(selected_id)
	else:
		delete_json_file(source + selected_id + ".json")
	
	
#This function removes an item from the json file specified by the source variable
#If an item with that ID does not exist in that file, do nothing
func remove_item_from_json_file(id: String):
	# If the source is not a JSON file, return without doing anything.
	if !source.ends_with(".json"):
		return

	# If the file does not exist, return without doing anything.
	if !FileAccess.file_exists(source):
		return

	# Open the file and load the JSON data.
	var file = FileAccess.open(source, FileAccess.READ)
	var data_json: Array
	if file:
		data_json = JSON.parse_string(file.get_as_text())
		file.close()
	else:
		print_debug("Unable to load file: " + source)
		return

	# Check if an item with the given ID exists in the file.
	for i in range(data_json.size()):
		if data_json[i].get("id", "") == id:
			data_json.remove_at(i)
			break

	# Save the updated JSON data to the file.
	file = FileAccess.open(source, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data_json))
		file.close()
	else:
		print_debug("Unable to write to file: " + source)
	load_data()


#This function will take two strings called ID and newID
#It will find an item with this ID in a json file specified by the source variable
#It will then duplicate that item into the json file and change the ID to newID
func duplicate_item_in_json_file(id: String, newID: String):
	# If the source is not a JSON file, return without doing anything.
	if !source.ends_with(".json"):
		return

	# If the file does not exist, return without doing anything.
	if !FileAccess.file_exists(source):
		return

	# Open the file and load the JSON data.
	var file = FileAccess.open(source, FileAccess.READ)
	var data_json: Array
	if file:
		data_json = JSON.parse_string(file.get_as_text())
		file.close()
	else:
		print_debug("Unable to load file: " + source)
		return

	# Check if an item with the given ID exists in the file.
	var item_to_duplicate = null
	for item in data_json:
		if item.get("id", "") == id:
			item_to_duplicate = item.duplicate()
			break

	# If there is no item to duplicate, return without doing anything.
	if item_to_duplicate == null:
		return

	# Change the ID of the duplicated item.
	item_to_duplicate["id"] = newID

	# Add the duplicated item to the JSON data.
	data_json.append(item_to_duplicate)

	# Save the updated JSON data to the file.
	file = FileAccess.open(source, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data_json))
		file.close()
	else:
		print_debug("Unable to write to file: " + source)
	load_data()


#This function will take a path to a json file and delete it
func delete_json_file(path: String):
	var dir = DirAccess.open(path)
	if dir:
		# Delete the file
		var err = dir.remove(path)
		if err == OK:
			print_debug("File deleted successfully: " + path)
		else:
			print_debug("An error occurred when trying to delete the file: " + path)
	load_data()

func get_selected_item_text() -> String:
	if !contentItems.is_anything_selected():
		return ""
	return contentItems.get_item_text(contentItems.get_selected_items()[0])
