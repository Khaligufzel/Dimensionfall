extends Control

# This script works with "exportdata.tscn".
# This scene/script is used in the "modmaintenance" scene to facilitate the extraction of data.
# This script will print the id, name and description of data types in a json format.

@export var output_text_edit: TextEdit = null
@export var type_option_button: OptionButton = null


# When the user clicks the export button, print the id, name and description to output_text_edit in json format
# The output will be an array of objects. Each object will have the properties outlined below.
func _on_export_button_button_up() -> void:
	var data: RefCounted = get_selected_content_data()
	var data_dict: Dictionary = data.get_all()  # Retrieve all data from Gamedata
	var data_data: Array = []  # Array to store the information as dictionaries

	# Iterate through all data and extract the necessary data
	for data_item: RefCounted in data_dict.values():
		var data_info: Dictionary = {
			"id": data_item.id,
			"name": data_item.name,
			"description": data_item.description
		}
		data_data.append(data_info)

	# Convert the array of data to JSON format
	var json_output: String = JSON.stringify(data_data, "\t")  # Use tab for better formatting

	# Output the formatted JSON to the TextEdit control
	output_text_edit.text = json_output


# Define a function to return the appropriate ContentType based on the string input
func get_content_type(content_name: String) -> int:
	# Dictionary to map strings to ContentType constants
	var content_type_map = {
		"tacticalmaps": DMod.ContentType.TACTICALMAPS,
		"maps": DMod.ContentType.MAPS,
		"furnitures": DMod.ContentType.FURNITURES,
		"itemgroups": DMod.ContentType.ITEMGROUPS,
		"items": DMod.ContentType.ITEMS,
		"tiles": DMod.ContentType.TILES,
		"mobs": DMod.ContentType.MOBS,
		"playerattributes": DMod.ContentType.PLAYERATTRIBUTES,
		"wearableslots": DMod.ContentType.WEARABLESLOTS,
		"stats": DMod.ContentType.STATS,
		"skills": DMod.ContentType.SKILLS,
		"quests": DMod.ContentType.QUESTS,
		"overmapareas": DMod.ContentType.OVERMAPAREAS
	}
	
	# Use the dictionary to get the ContentType, or return an error if not found
	return content_type_map.get(content_name, null)  # or another fallback if needed

# Function to retrieve data based on the selected type in type_option_button
func get_selected_content_data() -> RefCounted:
	# Retrieve the selected type as a string from type_option_button
	var selected_type: String = type_option_button.get_item_text(type_option_button.selected)
	
	# Convert the selected type string to the corresponding ContentType using get_content_type
	var content_type = get_content_type(selected_type)
	
	# Retrieve and return the data of the selected content type using Gamedata.get_data_of_type
	return Gamedata.get_data_of_type(content_type)
