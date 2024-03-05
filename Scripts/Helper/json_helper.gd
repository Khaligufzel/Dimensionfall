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
	
#This function takes the path to a json file and returns its contents as an array
#It should check if the contents is an array or not. If it is not an array, 
#it should return an empty array
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
				if extensionFilter.is_empty():
					fileNames.append(file_name)
				elif file_name.get_extension() in extensionFilter:
					fileNames.append(file_name)
			file_name = dir.get_next()
	else:
		print_debug("An error occurred when trying to access the path: " + dirName)
	dir.list_dir_end()
	return fileNames


#This function takes a json string and saves it as a json file.
func write_json_file(path: String, json: String):
	# Save the JSON string to the selected file location
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(json)
	else:
		print_debug("Unable to write file " + path)
