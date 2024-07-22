extends Control

# This script is meant to be used with the mod maintenance interface
# This script allows the user to change the selected property on the selected type
# of entity from one type to another type. For example, change "volume" from string to int

@export var propertiesOptionButton: OptionButton
@export var typesOptionButton: OptionButton
@export var outputTextEdit: TextEdit
@export var from_option_button: OptionButton
@export var to_option_button: OptionButton
@export var change_property_type_button: Button



# fills the propertiesOptionButton with all top-level properties of the selected entity type
# 1. Check if a type has been selected and return if not
# 2. check if the type_data array contains anything and return if not
# 3. Loop over all entities in type_data
# 4. For each yop-level property in the entity's property dictionary, add the property
# to propertiesOptionButton if it's not already there
func _on_get_properties_button_button_up():
	propertiesOptionButton.clear()  # Clear existing items
	var game_data = get_type_data()
	var type_data = game_data.data
	if not type_data or type_data.is_empty():
		outputTextEdit.text = "No data available or type not selected."
		return

	var properties_set = {}  # Using a dictionary to track unique properties
	for entity in type_data:
		for property in entity.keys():
			properties_set[property] = true

	for property in properties_set.keys():
		propertiesOptionButton.add_item(property)

	if propertiesOptionButton.get_item_count() == 0:
		outputTextEdit.text = "No properties found for selected type."
	else:
		outputTextEdit.text = "Properties loaded for selected type."


func get_type_data() -> Variant:
	var selected_type = typesOptionButton.get_item_text(typesOptionButton.selected)
	if selected_type == "Item":
		return Gamedata.data.items
	elif selected_type == "Itemgroup":
		return Gamedata.data.itemgroups
	elif selected_type == "Mob":
		return Gamedata.data.mobs
	return null


# The user selects a type to change to. The type can be int or string
# This function needs to enable change_property_type_button if 
# from_option_button also has a value selected
func _on_to_option_button_item_selected(_index):
	if from_option_button.selected != -1:
		change_property_type_button.disabled = false


# The user selects a type to change from. The type can be int or string
# This function needs to enable change_property_type_button if 
# to_option_button also has a value selected
func _on_from_option_button_item_selected(_index):
	if to_option_button.selected != -1:
		change_property_type_button.disabled = false


# Changes the selected property on all entities of the selected type from one
# type to another. For example, change the type of the "volume" property
# from a string to an int
# 1. Check if a type has been selected in typesOptionButton and return if not
# 2. Check if a property has been selected in typesOptionButton and return if not
# 3. Get the data of the selected type and check if it contains data. Return if not
# 4. Loop over the entities in the data of the selected type
# 4.1. For each entity, check if the selected property exists
# 4.2. If the property exists, check if the type matches the type selected in from_option_button
# 4.3. If it matches, change the property type form the current type to the 
# type selected in to_option_button. This can be an int or a string
# 4.4 print the changed entity id and property to the output
# 5. Save the data to file
func _on_change_property_type_button_button_up():
	if typesOptionButton.selected == -1:
		outputTextEdit.text = "No type selected."
		return
	if propertiesOptionButton.selected == -1:
		outputTextEdit.text = "No property selected."
		return

	var game_data = get_type_data()
	var type_data = game_data.data
	if type_data.is_empty():
		outputTextEdit.text = "No data available for the selected type."
		return

	var property_name = propertiesOptionButton.get_item_text(propertiesOptionButton.selected)
	var from_type = from_option_button.get_item_text(from_option_button.selected)
	var to_type = to_option_button.get_item_text(to_option_button.selected)
	
	if from_type == to_type:
		outputTextEdit.text = "From type and to type are the same. No changes made."
		return
	
	var changes = []
	
	for entity in type_data:
		if property_name in entity:
			var value = entity[property_name]
			var value_type = typeof(value)
			if (from_type == "int" and value_type == TYPE_INT) or (from_type == "string" and value_type == TYPE_STRING) or (from_type == "float" and value_type == TYPE_FLOAT):
				if to_type == "int":
					entity[property_name] = int(value)
				elif to_type == "string":
					entity[property_name] = str(value)
				elif to_type == "float":
					entity[property_name] = float(value)
				changes.append("Changed property '" + property_name + "' of entity with ID " + str(entity.get("id", "Unknown ID")) + " to " + to_type)

	if changes.is_empty():
		outputTextEdit.text = "No changes made. Property '" + property_name + "' not found in any entities or type mismatch."
	else:
		outputTextEdit.text = "Changes made:\n" + "\n".join(changes)
		Gamedata.save_data_to_file(game_data)
