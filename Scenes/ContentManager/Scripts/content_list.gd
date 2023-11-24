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

#This function will show a pop-up asking the user to input an ID
func _on_add_button_button_up():
	pupup_ID.show()


# This function will take a string and create a new json file with just {} as the contents.
#If the file already exists, we do not overwrite it
func create_new_json_file(filename: String = "", isArray: bool = true):
	# If no string was provided, return without doing anything.
	if filename.is_empty():
		return

	# If the file already exists, alert the user that the file already exists.
	if FileAccess.file_exists(filename):
		print_debug("The file already exists: " + filename)
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

#Called after the user enters an ID into the popup textbox and presses OK
func _on_ok_button_up():
	pupup_ID.hide()
	if popup_textedit.text == "":
		return;
	if source.ends_with(".json"):
		add_item_to_json_file(popup_textedit.text)
	else:
		create_new_json_file(source + popup_textedit.text + ".json", false)

#Called after the users presses cancel on the popup asking for an ID
func _on_cancel_button_up():
	pupup_ID.hide()


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
