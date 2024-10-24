extends Control

# This script works with "exportmapdata.tscn".
# This scene/script is used in the "modmaintenance" scene to facilitate the extraction of data for maps
# This script will print the id, name and description of maps in a json format.

@export var output_text_edit: TextEdit = null


# When the user clicks the export button, print the id, name and description to output_text_edit in json format
# The output will be an array of objects. Each object will have the properties outlined below.
func _on_export_button_button_up() -> void:
	var maps: Dictionary = Gamedata.maps.get_all()  # Retrieve all maps from Gamedata
	var map_data: Array = []  # Array to store the map information as dictionaries

	# Iterate through all maps and extract the necessary data
	for map: DMap in maps.values():
		var map_info: Dictionary = {
			"id": map.id,
			"name": map.name,
			"description": map.description
		}
		map_data.append(map_info)

	# Convert the array of map data to JSON format
	var json_output: String = JSON.stringify(map_data, "\t")  # Use tab for better formatting

	# Output the formatted JSON to the TextEdit control
	output_text_edit.text = json_output
