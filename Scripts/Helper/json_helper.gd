extends Node

#This script is a generic helper script to load and manipulate JSOn files.
#In Helper.gd, this script is loaded on game start
#It can be accessed trough Helper.json_helper


#This function takes the path to a json file and returns its contents as an array
#It should check if the contents is an array or not. If it is not an array, 
#it should return an empty array
func load_json_array_file(source: String) -> Array:
	var data_json: Array = []
	var file = FileAccess.open(source, FileAccess.READ)
	if file:
		var parsed_data = JSON.parse_string(file.get_as_text())
		if typeof(parsed_data) == TYPE_ARRAY:
			data_json = parsed_data
		else:
			print_debug("The file does not contain a JSON array: " + source)
	else:
		print_debug("Unable to load file: " + source)
	return data_json
	
#This function takes the path to a json file and returns its contents as an dictionary
func load_json_dictionary_file(source: String) -> Dictionary:
	var data_json: Dictionary = {}
	var file = FileAccess.open(source, FileAccess.READ)
	if file:
		var parsed_data = JSON.parse_string(file.get_as_text())
		if typeof(parsed_data) == TYPE_DICTIONARY:
			data_json = parsed_data
		else:
			print_debug("The file does not contain a JSON dictionary: " + source)
	else:
		print_debug("Unable to load file: " + source)
	return data_json


# This function lists all the files in a specified directory. 
# it takes two arguments: `dirName` (the path of the directory
# to list files from) and `extensionFilter` (an optional
# array of file extensions to filter by).
# If the `extensionFilter` is empty, all filenames will be returned. 
# If not, it will only return filenames which file extentnion is in `extensionFilter`
func file_names_in_dir(dirName: String, extensionFilter: Array = []) -> Array:
	var fileNames: Array = []
	var dir = DirAccess.open(dirName)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if !dir.current_is_dir():
				if extensionFilter.is_empty() or file_name.get_extension() in extensionFilter:
					fileNames.append(file_name)
			file_name = dir.get_next()
		dir.list_dir_end()  # Close the directory read operation
	else:
		print_debug("Failed to open directory: " + dirName)
	return fileNames


# This function lists all the files in a specified directory. 
# it takes ne argument: `dirName` (the path of the directory
# to list folders from) 
func folder_names_in_dir(path: String) -> Array:
	var dirs: Array = []
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var folder_name = dir.get_next()
		while folder_name != "":
			if dir.current_is_dir():
				dirs.append(folder_name)
			folder_name = dir.get_next()
	else:
		print("An error occurred when trying to access the path.")
	return dirs


#This function takes a json string and saves it as a json file.
func write_json_file(path: String, json: String) -> Error:
	# If the file does not exists, we create a new one.
	if not FileAccess.file_exists(path):
		create_new_json_file(path)
	# Save the JSON string to the selected file location
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(json)
		file.close()
		return OK
	else:
		print_debug("Unable to write file " + path)
	return FAILED


# This function will take a path and create a new json file with just {} or [] as the contents.
#If the file already exists, we do not overwrite it
func create_new_json_file(filename: String = "", isArray: bool = true):
	# If no string was provided, return without doing anything.
	if filename.is_empty():
		return

	# If the file already exists, alert the user that the file already exists.
	if FileAccess.file_exists(filename):
		return

	# Extract the directory path from the filename and check if it exists.
	var directory_path = filename.get_base_dir()
	var base_dir = "./"
	if directory_path.begins_with("user://"):
		base_dir = "user://"
	var dir = DirAccess.open(base_dir)
	if not dir.dir_exists(directory_path):
		# Create the directory if it does not exist.
		var err = dir.make_dir_recursive(directory_path)
		if err != OK:
			print_debug("Failed to create directory: " + directory_path)
			return
		print_debug("Directory created: " + directory_path)

	var file = FileAccess.open(filename, FileAccess.WRITE)
	#The file cen contain either one object or one array with a list of objects
	if isArray:
		file.store_string("[]")
	else:
		file.store_string("{}")
	file.close()



#This function enters a new item into the json file specified by the source variable
#The item will just be an object like this: {"id": id}
#If an item with that ID already exists in that file, do nothing
func add_id_to_json_file(source: String, id: String):
# If the source is not a JSON file, return without doing anything.
	if !source.ends_with(".json"):
		return

	# If the file does not exist, create a new JSON file.
	if !FileAccess.file_exists(source):
		create_new_json_file(source, true)
		
	var data_json: Array = load_json_array_file(source)

	# Check if an item with the given ID already exists in the file.
	for item in data_json:
		if item.get("id", "") == id:
			print_debug("An item with ID (" + id + ") already exists in the file.")
			return

	# If no item with the given ID exists, add a new item to the JSON data.
	data_json.append({"id": id})
	write_json_file(source, JSON.stringify(data_json, "\t"))


#This function will take a path to a json file and delete it
func delete_json_file(path: String):
	var filename: String = path.get_file()
	var dirname: String = path.replace(filename,"")
	var dir = DirAccess.open(dirname)
	if dir:
		# Delete the file
		var err = dir.remove(filename)
		if err == OK:
			print_debug("File deleted successfully: " + path)
		else:
			print_debug("An error occurred when trying to delete the file: " + path)


# Returns the value from the given property from the given dictionary
# mydata = any dictionary with properties
# path = a dot-separated string properties.
# Usage example: Helper.json_helper.get_nested_data(furniture_data, "Function.container.itemgroup")
# The example will return the value of itemgroup from the furniture_data
func get_nested_data(mydata: Dictionary, path: String) -> Variant:
	var parts = path.split(".")
	var current = mydata
	for part in parts:
		if current.has(part):
			current = current[part]
		else:
			return null
	return current

# Deletes the nested property from the given dictionary
# mydata = any dictionary with properties
# path = a dot-separated string of properties.
# Usage example: Helper.json_helper.delete_nested_property(furniture_data, "Function.container.itemgroup")
# The example will delete the 'itemgroup' property from the 'container' inside 'Function' of 'furniture_data'
# Returns true if the property was deleted, false if the property does not exist or could not be deleted
func delete_nested_property(mydata: Dictionary, path: String) -> bool:
	var parts = path.split(".")
	var current = mydata
	for i in range(parts.size() - 1):
		if current.has(parts[i]):
			current = current[parts[i]]
		else:
			return false
	var property_to_remove = parts[parts.size() - 1]
	return current.erase(property_to_remove)
