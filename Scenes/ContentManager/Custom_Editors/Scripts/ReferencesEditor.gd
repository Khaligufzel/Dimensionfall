extends Control


# This script is supposed to work with the ReferencesEditor.tscn
# It allow the user to view the references that other entity have to this entity
# For example, an itemgroup may reference this entity when it's an item in the itemgroup
# A map might reference a furniture that's placed on the map. 
# So when opening this editor on a furniture, you might see the maps that have this furniture

# Down the line, this editor might be used to manipulate the references. 
# This might allow the user to delete this entity from a map that's referencing it.

# The reference data of an entity might look like this (core is the core mod):
#		"references": {
#			"core": {
#				"itemgroups": [
#					"mob_loot",
#					"destroyed_furniture_medium",
#					"disassembled_furniture_medium"
#				],
#				"items": [
#					"cutting_board",
#					"rolling_pin"
#				]
#			}
#		},

@export var references_grid: GridContainer

var reference_data: Dictionary = {}:
	set(newdata):
		reference_data = newdata
		calculate_and_set_columns()
		update_reference_grid()


# Called when the node enters the scene tree for the first time.
func _ready():
	reference_data = {
			"core": {
				"itemgroups": [
					"mob_loot",
					"destroyed_furniture_medium",
					"disassembled_furniture_medium"
				],
				"items": [
					"cutting_board",
					"rolling_pin"
				]
			},
			"mymod": {
				"itemgroups": [
					"zombie_loot",
					"destroyed_trash",
					"disassembled_trash"
				],
				"items": [
					"sword",
					"pistol"
				]
			}
		}


# Function to calculate and set the number of columns for the references_grid
func calculate_and_set_columns():
	var headers = ["mod"]
	if reference_data.size() > 0:
		for mod in reference_data:
			for key in reference_data[mod].keys():
				if not headers.has(key.capitalize()):
					headers.append(key.capitalize())
	references_grid.columns = headers.size()

# Function to update the reference grid based on the reference data
# It will translate the reference_data into a table
# The headers will be "mod", followed by the entity type in the data, 
# for example "itemgroups" or "items"
# Each row in the table will have the mod name in the first column
# Each of the following columns will have the name of that entity type in the cell

# Function to update the reference grid based on the reference data
func update_reference_grid():
	# Clear existing children from the grid
	for child in references_grid.get_children():
		references_grid.remove_child(child)
		child.queue_free()

	# Create and add headers
	var headers = ["mod"]
	if reference_data.size() > 0:
		for mod in reference_data:
			for key in reference_data[mod].keys():
				if not headers.has(key.capitalize()):
					headers.append(key.capitalize())

	for header in headers:
		var label = Label.new()
		label.text = header
		references_grid.add_child(label)

	# Add the data rows
	for mod in reference_data:
		var mod_label = Label.new()
		mod_label.text = mod
		references_grid.add_child(mod_label)

		for entity_type in headers.slice(1, headers.size()):
			var entity_label = Label.new()
			if entity_type.to_lower() in reference_data[mod]:
				var entities = reference_data[mod][entity_type.to_lower()]
				if entities is Array:
					entity_label.text = ", ".join(entities)
				else:
					entity_label.text = str(entities)
			references_grid.add_child(entity_label)
