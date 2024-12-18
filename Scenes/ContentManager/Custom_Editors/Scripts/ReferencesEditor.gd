extends Control


# This script is supposed to work with the ReferencesEditor.tscn
# It allow the user to view the references that other entity have to this entity
# For example, an itemgroup may reference this entity when it's an item in the itemgroup
# A map might reference a furniture that's placed on the map. 
# So when opening this editor on a furniture, you might see the maps that have this furniture

# Down the line, this editor might be used to manipulate the references. 
# This might allow the user to delete this entity from a map that's referencing it.

# The reference data of an entity is stored inside the mod folder, inside the folder of the entity type
# For example, the item references will be in /mods/mymod/items/references.json
# References for an item might look like this:
#{
#	"itemgroups": [
#		"generic_forest_finds",
#		"starting_items"
#	]
#	"items": [
#		"cooked_acorn"
#	]
#}
# Here we see that an item, for example "acorn", is referenced in an itemgroup called generic_forest_finds


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
		# Clear the existing grid
		for child in references_grid.get_children():
			references_grid.remove_child(child)
			child.queue_free()

		# Populate the grid with headers and rows
		populate_references_grid()


func populate_references_grid():
	# Add headers to the grid
	for key in reference_data.keys():
		var header_label = Label.new()
		header_label.text = key.capitalize()  # Capitalize key for a cleaner look
		header_label.modulate = COLORS[reference_data.keys().find(key) % COLORS.size()]  # Assign a color to the header
		references_grid.add_child(header_label)

	# Determine the number of rows (the maximum list size across all keys)
	var max_rows = 0
	for key in reference_data:
		max_rows = max(max_rows, reference_data[key].size())

	# Add rows of data
	for i in range(max_rows):
		for key in reference_data.keys():
			var value_label = Label.new()
			if i < reference_data[key].size():
				value_label.text = reference_data[key][i]  # Set entity ID as the text
			else:
				value_label.text = ""  # Leave blank if no data for this row
			references_grid.add_child(value_label)
