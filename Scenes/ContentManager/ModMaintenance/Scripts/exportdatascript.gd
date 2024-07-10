extends Control

# This script is meant to be used with the mod maintenance interface
# This script allows the user to export the selected properties from the selected type

@export var typesOptionButton: OptionButton
@export var outputTextEdit: TextEdit
@export var properties_v_box_container: VBoxContainer



func _on_back_button_button_up():
	get_tree().change_scene_to_file("res://scene_selector.tscn")


# fills the properties_v_box_container with all top-level properties of the selected entity type
# 1. Check if a type has been selected and return if not
# 2. check if the type_data array contains anything and return if not
# 3. Loop over all entities in type_data
# 4. For each yop-level property in the entity's property dictionary, 
# create a checkbox with the name of the property for each property
# 5. add the property to properties_v_box_container if it's not already there. 
func _on_get_properties_button_button_up():
	# Clear the container before adding new items
	for child in properties_v_box_container.get_children():
		child.queue_free()
	
	var game_data = get_type_data()
	var type_data = game_data.data
	if not type_data or type_data.is_empty():
		outputTextEdit.text = "No data available or type not selected."
		return

	var properties_set = {}  # Dictionary to track unique properties
	for entity in type_data:
		for property in entity.keys():
			properties_set[property] = true

	for property in properties_set.keys():
		# Create a new CheckBox for each unique property
		var checkbox = CheckBox.new()
		checkbox.text = property
		# Add the CheckBox to the VBoxContainer
		properties_v_box_container.add_child(checkbox)

	if properties_v_box_container.get_child_count() == 0:
		outputTextEdit.text = "No properties found for selected type."
	else:
		outputTextEdit.text = "Properties loaded for selected type."


# Gets the relevant data from gamedata based on the type that was selected.
func get_type_data() -> Variant:
	var selected_type = typesOptionButton.get_item_text(typesOptionButton.selected)
	if selected_type == "Item":
		return Gamedata.data.items
	elif selected_type == "Furniture":
		return Gamedata.data.furniture
	elif selected_type == "Itemgroup":
		return Gamedata.data.itemgroups
	elif selected_type == "Mob":
		return Gamedata.data.mobs
	elif selected_type == "Tile":
		return Gamedata.data.tiles
	return null


# The user presses the export button.
func _on_exportroperties_button_button_up():
	export_data()


# Export the selected properties from the selected type
# 1. Check if typesOptionButton has any value selected. Return if not.
# 2. Check if any properties in the properties_v_box_container have been selected. Return if not
# 3. Loop over the data for each entity of the selected type
# 3.1 Create a new line in the outputTextEdit with the properties
# The id should always be on the front of the line, followed by the rest of the properties
# Each property should be separated by a comma with no space in between
func export_data():
	# 1. Check if typesOptionButton has any value selected. Return if not.
	var selected_type_index = typesOptionButton.selected
	if selected_type_index == -1:
		outputTextEdit.text = "No type selected."
		return

	# Get the selected type data
	var game_data = get_type_data()
	var type_data = game_data.data
	if not type_data or type_data.is_empty():
		outputTextEdit.text = "No data available for selected type."
		return

	# 2. Check if any properties in the properties_v_box_container have been selected. Return if not
	var selected_properties = []
	for i in range(properties_v_box_container.get_child_count()):
		var checkbox = properties_v_box_container.get_child(i)
		if checkbox is CheckBox and checkbox.button_pressed:
			if checkbox.text != "id":  # Exclude 'id' from selected properties
				selected_properties.append(checkbox.text)

	if selected_properties.is_empty():
		outputTextEdit.text = "No properties selected."
		return

	# 3. Add property names as the header in outputTextEdit
	var header = "id,"
	for property in selected_properties:
		header += property + ","
	header = header.rstrip(",") + "\n"

	# Initialize output_text with the header
	var output_text = header

	# Loop over the data for each entity of the selected type
	for entity in type_data:
		# 3.1 Create a new line in the outputTextEdit with the properties
		var line = entity.id + ","  # id is always at the front of the line
		for property in selected_properties:
			if property in entity:
				var value = entity[property]
				match typeof(value):
					TYPE_FLOAT, TYPE_INT, TYPE_STRING, TYPE_BOOL:
						line += str(value) + ","
					TYPE_ARRAY:
						line += "[array],"
					TYPE_DICTIONARY:
						line += "[object],"
					_:
						line += "null,"
			else:
				line += "null,"
		# Remove the last comma and add a new line
		line = line.rstrip(",") + "\n"
		output_text += line

	# Set the outputTextEdit text
	outputTextEdit.text = output_text
