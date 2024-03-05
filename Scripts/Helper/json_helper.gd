extends Node

#This script is a generic helper script to load and manipulate JSOn files.
#In another script, you can load an instance of this script using:
#const json_Helper_Class = preload("res://Scripts/Helper/json_helper.gd")
#var json_helper: Resource = null

#func _ready() -> void:
#  json_helper := json_Helper_Class.new()


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
