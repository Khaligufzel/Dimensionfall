class_name DTile
extends RefCounted


# There's a D in front of the class name to indicate this class only handles tile data, nothing more
# This script is intended to be used inside the GameData autoload singleton
# This script handles the data for one tile. You can access it through Gamedata.mods.by_id("Core").tiles

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
#		]
#	}

# This class represents a piece of item with its properties
var id: String
var name: String
var description: String
var shape: String
var sprite: Texture
var spriteid: String
var categories: Array
var parent: DTiles

# Constructor to initialize tile properties from a dictionary
func _init(data: Dictionary, myparent: DTiles):
	parent = myparent
	id = data.get("id", "")
	name = data.get("name", "")
	description = data.get("description", "")
	shape = data.get("shape", "")
	spriteid = data.get("sprite", "")
	categories = data.get("categories", [])

# Get data function to return a dictionary with all properties
func get_data() -> Dictionary:
	var data: Dictionary = {
		"id": id,
		"name": name,
		"description": description,
		"sprite": spriteid,
		"categories": categories
	}
	
	if shape and not shape == "":
		data["shape"] = shape

	return data

# Returns the path of the sprite
func get_sprite_path() -> String:
	return parent.spritePath + spriteid


# Some tile has been changed
# INFO if the tiles reference other entities, update them here
func changed(_olddata: DTile):
	parent.save_tiles_to_disk()


# A tile is being deleted from the data
# We have to remove it from everything that references it
func delete():
	# Check to see if any mod has a copy of this tile. if one or more remain, we can keep references
	# Otherwise, the last copy was removed and we need to remove references
	var all_results: Array = Gamedata.mods.get_all_content_by_id(DMod.ContentType.TILES, id)
	if all_results.size() > 0:
		return
	
	# Get a list of all maps that reference this tile
	var myreferences: Dictionary = parent.references.get(id, {})
	var mymaps: Array = myreferences.get("maps", [])
	# For each mod, remove this tile from the maps in this tile's references
	for mod: DMod in Gamedata.mods.get_all_mods():
		mod.maps.remove_entity_from_selected_maps("tile", id, mymaps)
