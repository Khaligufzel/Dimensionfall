extends Control

# This script is meant to be used with the mod maintenance interface
# This script allows the user to erase the selected property from the selected type

@export var propertiesOptionButton: OptionButton
@export var typesOptionButton: OptionButton
@export var outputTextEdit: TextEdit


func _on_back_button_button_up():
	get_tree().change_scene_to_file("res://scene_selector.tscn")


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


# Erases the selected property from all entities of the selected type
# 1. Check if a type has been selected and return if not
# 2. Check if a property has been selected and return if not
# 3. Get the data of the selected type and check if it contains data. Return if not
# 4. Loop over the entities in the data of the selected type
# 4.1. For each entity, erase the selected property if it exists
# 4.2 print the deleted entity id and property to the output
func _on_erase_properties_button_button_up():
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

	var property_to_erase = propertiesOptionButton.get_item_text(propertiesOptionButton.selected)
	var changes = []
	for entity in type_data:
		if property_to_erase in entity:
			changes.append("Removed property '" + property_to_erase + "' from " + str(entity.get("id", "Unknown ID")))
			entity.erase(property_to_erase)

	outputTextEdit.text = "Changes made:\n" + "\n".join(changes)
	if changes.is_empty():
		outputTextEdit.text = "No changes made, property '" + property_to_erase + "' not found in any entities."
	Gamedata.save_data_to_file(game_data)


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
	return null
