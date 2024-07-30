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
		"sprite": spriteid,
		"categories": categories
	}
	if not references.is_empty():
		data["references"] = references
	
	if shape and not shape == "":
		data["shape"] = shape

	return data

# Removes the provided reference from references
func remove_reference(module: String, type: String, refid: String):
	var changes_made = Gamedata.dremove_reference(references, module, type, refid)
	if changes_made:
		Gamedata.tiles.save_tiles_to_disk()

# Adds a reference to the references list
func add_reference(module: String, type: String, refid: String):
	var changes_made = Gamedata.dadd_reference(references, module, type, refid)
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
# INFO if the tiles reference other entities, update them here
func changed(_olddata: DTile):
	Gamedata.tiles.save_tiles_to_disk()


# A tile is being deleted from the data
# We have to remove it from everything that references it
func delete():
	# Check if the tile has references to maps and remove it from those maps
	var mapsdata = Helper.json_helper.get_nested_data(references, "core.maps")
	if mapsdata:
		Gamedata.maps.remove_entity_from_selected_maps("tile", id, mapsdata)


# Executes a callable function on each reference of the given type
func execute_callable_on_references_of_type(module: String, type: String, callable: Callable):
	# Check if it contains the specified 'module' and 'type'
	if references.has(module) and references[module].has(type):
		# If the type exists, execute the callable on each ID found under this type
		for ref_id in references[module][type]:
			callable.call(ref_id)
