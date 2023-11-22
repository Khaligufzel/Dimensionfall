extends Control

@export var contentItems: ItemList = null
@export var collapseButton: Button = null
@export var pupup_ID: Popup = null
@export var popup_textedit: TextEdit = null
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
func create_new_json_file(filename: String = ""):
	# If no string was provided, return without doing anything.
	if filename.is_empty():
		return

	var file_path = source + filename + ".json"

	# If the file already exists, alert the user that the file already exists.
	if FileAccess.file_exists(file_path):
		print_debug("The file already exists: " + file_path)
		return

	var file = FileAccess.open(file_path, FileAccess.WRITE)
	# The name of the json file will be the string that was passed as a parameter.
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
	# Save the JSON string to the selected file location
	var file = FileAccess.open(source, FileAccess.READ)
	if file:
		var data_json: Dictionary
		data_json = JSON.parse_string(file.get_as_text())
		for item in data_json:
			# get the name of the item, "missing_name" if not found
			var item_name: String = item.get("name", "missing_name")
			#Add the item and save the index number
			var item_index: int = contentItems.add_item(item_name)
			#Add the ID as metadata which can be used to load the item data
			contentItems.set_item_metadata(item_index, item.get("id", "missing_id"))
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
				contentItems.add_item(file_name.replace(".json", ""))
			file_name = dir.get_next()
	else:
		print_debug("An error occurred when trying to access the path: " + source)
	dir.list_dir_end()


func _on_ok_button_up():
	pupup_ID.hide()
	if source.ends_with(".json"):
		print_debug("Here should be code that adds an item to the json file")
	else:
		create_new_json_file(popup_textedit.text)


func _on_cancel_button_up():
	pupup_ID.hide()
