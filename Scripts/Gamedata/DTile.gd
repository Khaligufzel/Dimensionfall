class_name DTile
extends RefCounted


# There's a D in front of the class name to indicate this class only handles tile data, nothing more
# This script is intended to be used inside the GameData autoload singleton
# This script handles the data for one tile. You can access it through Gamedata.tiles

#Example tile data:
#	{
#		"id": "kitchen_tiles_green_00",
#		"name": "Kitchen tiles (green)",
#		"description": "A tiled floor you would find in a kitchen. The tiles are painted green",
#		"shape": "cube",
#		"sprite": "kitchentilesgreen.png",
#		"categories": [
#			"Floor",
#			"Urban"
#		],
#		"references": {
#			"core": {
#				"maps": [
#					"generichouse_t"
#				]
#			}
#		}
#	}

# This class represents a piece of item with its properties
var id: String
var name: String
var description: String
var shape: String
var sprite: Texture
var spriteid: String
var categories: Array
var references: Dictionary = {}

# Constructor to initialize tile properties from a dictionary
func _init(data: Dictionary):
	id = data.get("id", "")
	name = data.get("name", "")
	description = data.get("description", "")
	shape = data.get("shape", "")
	spriteid = data.get("sprite", "")
	categories = data.get("categories", [])
	references = data.get("references", {})

# Get data function to return a dictionary with all properties
func get_data() -> Dictionary:
	var data: Dictionary = {
		"id": id,
		"name": name,
		"description": description,
		"shape": shape,
		"sprite": spriteid,
		"categories": categories
	}
	if not references.is_empty():
		data["references"] = references

	return data

# Removes the provided reference from references
func remove_reference(module: String, type: String, refid: String):
	var reftile: DTile = Gamedata.tiles.by_id(refid)
	var changes_made = Gamedata.dremove_reference(reftile.references, module, type, id)
	if changes_made:
		Gamedata.tiles.save_tiles_to_disk()

# Adds a reference to the references list
func add_reference(module: String, type: String, refid: String):
	var reftile: DTile = Gamedata.tiles.by_id(refid)
	var changes_made = Gamedata.dadd_reference(reftile.references, module, type, id)
	if changes_made:
		Gamedata.tiles.save_tiles_to_disk()

# Returns the path of the sprite
func get_sprite_path() -> String:
	return Gamedata.tiles.spritePath + spriteid

# Handles tile changes and updates references if necessary
func on_data_changed(_oldtile: DTile):
	var changes_made = false

	# If any references were updated, save the changes to the data file
	if changes_made:
		print_debug("Tile reference updates saved successfully.")
		Gamedata.save_data_to_file(Gamedata.data.tilegroups)

# Some tile has been changed
# We need to update the relation between the tile and other tiles based on their references
func changed(olddata: DTile):
	var changes_made = false
	
	# Dictionaries to track unique reference IDs
	var old_reference_ids: Dictionary = {}
	var new_reference_ids: Dictionary = {}

	# Collect all unique reference IDs from old data
	if olddata.references:
		for ref in olddata.references:
			old_reference_ids[ref] = true

	# Collect all unique reference IDs from new data
	if references:
		for ref in references:
			new_reference_ids[ref] = true

	# References that are no longer present
	for ref_id in old_reference_ids:
		if not new_reference_ids.has(ref_id):
			changes_made = remove_reference("core", "tiles", ref_id) or changes_made
	
	# Add references for new data
	for ref_id in new_reference_ids:
		changes_made = add_reference("core", "tiles", ref_id) or changes_made
	
	Gamedata.tiles.save_tiles_to_disk()

	# Save changes if any modifications were made
	if changes_made:
		Gamedata.save_data_to_file(Gamedata.data.tilegroups)
		print_debug("Tile changes saved successfully.")
	else:
		print_debug("No changes were made to tile.")

# A tile is being deleted from the data
# We have to remove it from everything that references it
func delete():
	var changes_made = {"value": false}

	# This callable will remove this tile from tilegroups that reference this tile.
	var myfunc: Callable = func (tilegroup_id):
		var tilelist: Array = Gamedata.get_property_by_path(Gamedata.data.tilegroups, "tiles", tilegroup_id)
		for i in range(tilelist.size()):
			if tilelist[i].has("id") and tilelist[i]["id"] == id:
				tilelist.remove_at(i)
				changes_made["value"] = true
				break  # Exit loop after removal to avoid index issues

	execute_callable_on_references_of_type("core", "tilegroups", myfunc)
	
	# This callable will handle the removal of this tile from all references in other tiles
	var remove_from_tile: Callable = func(other_tile_id: String):
		var other_tile: DTile = Gamedata.tiles.by_id(other_tile_id)
		if other_tile and other_tile.references:
			if other_tile.references.erase(id):
				changes_made["value"] = true

	execute_callable_on_references_of_type("core", "tiles", remove_from_tile)
	
	# Save changes to the data file if any changes were made
	if changes_made["value"]:
		Gamedata.save_data_to_file(Gamedata.data.tilegroups)
		Gamedata.tiles.save_tiles_to_disk()
	else:
		print_debug("No changes needed for tile", id)

# Executes a callable function on each reference of the given type
func execute_callable_on_references_of_type(module: String, type: String, callable: Callable):
	# Check if it contains the specified 'module' and 'type'
	if references.has(module) and references[module].has(type):
		# If the type exists, execute the callable on each ID found under this type
		for ref_id in references[module][type]:
			callable.call(ref_id)
