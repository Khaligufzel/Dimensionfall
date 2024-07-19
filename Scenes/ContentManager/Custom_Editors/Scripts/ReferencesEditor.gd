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


# Define an array of 10 colors
const COLORS = [
	Color(0.75, 0.26, 0.35), # Dark red
	Color(0.57, 0.3, 0.57), # Dark purple
	Color(0, 0.4, 0.308),
	Color(0.314, 0.484, 0),
	Color(1, 0, 1), # Magenta
	Color(0, 1, 1), # Cyan
	Color(0.5, 0.5, 0.5), # Gray
	Color(1, 0.5, 0), # Orange
	Color(0.5, 0, 0.5), # Purple
	Color(0.5, 0.5, 0)  # Olive
]

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


# Function to calculate the maximum number of rows required for each mod
func calculate_max_rows_per_mod() -> Dictionary:
	var max_rows_per_mod = {}
	for mod in reference_data:
		var max_rows = 0
		for entity_type in reference_data[mod].keys():
			var entities = reference_data[mod][entity_type]
			max_rows = max(max_rows, entities.size())
		max_rows_per_mod[mod] = max_rows
	return max_rows_per_mod

# Function to create a new StyleBoxFlat for a label with a random color
func create_stylebox(column_index: int) -> StyleBoxFlat:
	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = COLORS[column_index % COLORS.size()]
	return stylebox

# Function to create a new Label with a StyleBoxFlat
func create_label(text: String, column_index: int) -> Label:
	var label = Label.new()
	label.text = text
	var stylebox = create_stylebox(column_index)
	label.add_theme_stylebox_override("normal", stylebox)
	return label

# Function to generate the rows for a given mod based on headers
func generate_mod_rows(headers: Array, mod: String) -> Array:
	var rows = []
	var max_rows = 0
	for entity_type in headers.slice(1, headers.size()):
		var entities = reference_data[mod].get(entity_type.to_lower(), [])
		max_rows = max(max_rows, entities.size())
	
	for i in range(max_rows):
		var row = []
		# Create label for the mod name
		var mod_label = create_label(mod if i == 0 else "", 0)
		row.append(mod_label)
		
		for column_index in range(1, headers.size()):
			var entity_label = create_label("", column_index)
			var entity_type = headers[column_index].to_lower()
			var entities = reference_data[mod].get(entity_type, [])
			entity_label.text = entities[i] if i < entities.size() else ""
			row.append(entity_label)
		
		rows.append(row)
	
	# Add separator row
	var separator_row = []
	for column_index in range(headers.size()):
		var separator_label = create_label("---", column_index)
		separator_row.append(separator_label)
	rows.append(separator_row)

	return rows

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

	for column_index in range(headers.size()):
		var label = create_label(headers[column_index], column_index)
		references_grid.add_child(label)

	# Generate and add the rows for each mod
	for mod in reference_data:
		var rows = generate_mod_rows(headers, mod)
		for row in rows:
			for label in row:
				references_grid.add_child(label)
