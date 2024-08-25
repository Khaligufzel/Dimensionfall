extends RefCounted

# This script is a generic helper script to load and manipulate JSON files.
# In Helper.gd, this script is loaded on game start.
# It can be accessed through Helper.json_helper.

# This function takes the path to a JSON file and returns its contents as an array.
# It checks if the contents are an array or not. If it is not an array, it returns an empty array.
func load_json_array_file(source: String) -> Array:
	var data_json: Array = []
	var file = FileAccess.open(source, FileAccess.READ)
	if file:
		var parsed_data = JSON.parse_string(file.get_as_text())
		if typeof(parsed_data) == TYPE_ARRAY:
			data_json = parsed_data
		else:
			print_debug("The file does not contain a JSON array: " + source)
	return data_json

# This function takes the path to a JSON file and returns its contents as a dictionary.
func load_json_dictionary_file(source: String) -> Dictionary:
	var data_json: Dictionary = {}
	var file = FileAccess.open(source, FileAccess.READ)
	if file:
		var parsed_data = JSON.parse_string(file.get_as_text())
		if typeof(parsed_data) == TYPE_DICTIONARY:
			data_json = parsed_data
		else:
			print_debug("The file does not contain a JSON dictionary: " + source)
	return data_json

# This function lists all the files in a specified directory. 
# It takes two arguments: `dir_name` (the path of the directory to list files from)
# and `extension_filter` (an optional array of file extensions to filter by).
# If the `extension_filter` is empty, all filenames will be returned. 
# If not, it will only return filenames whose file extension is in `extension_filter`.
func file_names_in_dir(dir_name: String, extension_filter: Array = []) -> Array:
	var file_names: Array = []
	var dir = DirAccess.open(dir_name)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if !dir.current_is_dir() and (extension_filter.is_empty() or file_name.get_extension() in extension_filter):
				file_names.append(file_name)
			file_name = dir.get_next()
		dir.list_dir_end()  # Close the directory read operation
	else:
		print_debug("Failed to open directory: " + dir_name)
	return file_names

# This function lists all the folders in a specified directory. 
# It takes one argument: `path` (the path of the directory to list folders from).
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
		dir.list_dir_end()  # Close the directory read operation
	else:
		print_debug("An error occurred when trying to access the path: " + path)
	return dirs

# This function takes a JSON string and saves it as a JSON file.
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

# This function deletes a JSON file at the given path.
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
	else:
		print_debug("Failed to open directory: " + dirname)


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
	return current.erase(parts[parts.size() - 1])


# Returns an array of unique values from an array of objects based on the given path.
# The path is a dot-separated string where the second to last part is an array,
# and the last part is the property of the objects in the array.
# Usage example: Helper.json_helper.get_unique_values(quest_data, "rewards.item_id")
# The example will return an array of all the unique items contained in the steps array.
func get_unique_values(mydata: Dictionary, path: String) -> Array:
	var parts = path.split(".")
	var current = mydata
	# Navigate to the second to last part of the path.
	for i in range(parts.size() - 1):
		if current.has(parts[i]):
			current = current[parts[i]]
		else:
			return []
	# The second to last part should be an array.
	if typeof(current) != TYPE_ARRAY:
		return []
	# Extract unique values of the last part.
	var property_name = parts[parts.size() - 1]
	var unique_values = {}  # Use a Dictionary as a set for unique values.
	for item in current:
		if typeof(item) == TYPE_DICTIONARY and item.has(property_name):
			unique_values[item[property_name]] = true
	return unique_values.keys()


# Merges two arrays and returns a new array with unique values.
func merge_unique(array1: Array, array2: Array) -> Array:
	var merged_array = array1.duplicate(true)
	for item in array2:
		if not merged_array.has(item):
			merged_array.append(item)
	return merged_array


# Removes objects from an array in a dictionary if the object's property matches the given ID.
# The path is a dot-separated string where the second to last part is an array,
# and the last part is the property of the objects in the array.
# Returns true if any objects were removed, otherwise false.
# Usage example: Helper.json_helper.remove_object_by_id(data, "steps.mob", "scrapwalker")
# This will remove objects from the steps array where the step's mob property equals "scrapwalker".
func remove_object_by_id(mydata: Dictionary, path: String, id: String) -> bool:
	var parts = path.split(".")
	var current = mydata
	# Navigate to the second to last part of the path.
	for i in range(parts.size() - 1):
		if current.has(parts[i]):
			current = current[parts[i]]
		else:
			return false
	# The second to last part should be an array.
	if typeof(current) != TYPE_ARRAY:
		return false
	# Remove objects where the property's value equals the given id.
	var property_name = parts[parts.size() - 1]
	var removed = false
	for item in current.duplicate():  # Use duplicate() to safely modify the array while iterating.
		if typeof(item) == TYPE_DICTIONARY and item.has(property_name) and item[property_name] == id:
			current.erase(item)
			removed = true
	return removed
