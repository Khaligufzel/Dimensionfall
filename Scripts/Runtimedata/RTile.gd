class_name RTile
extends RefCounted

# This class represents a tile with its properties
# Only used while the game is running
# Example tile data:
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

# Properties defined in the tile
var id: String
var name: String
var description: String
var shape: String
var spriteid: String
var sprite: Texture
var categories: Array = []
var references: Dictionary = {}
var parent: RTiles

# Constructor to initialize tile properties from a dictionary
# data: the data as loaded from json
# myparent: The list containing all tiles for this mod
func _init(myparent: RTiles, newid: String):
	parent = myparent
	id = newid

# Overwrite this tile's properties using a DTile
func overwrite_from_dtile(dtile: DTile) -> void:
	if not id == dtile.id:
		print_debug("Cannot overwrite from a different id")
	name = dtile.name
	description = dtile.description
	shape = dtile.shape
	spriteid = dtile.spriteid
	sprite = dtile.sprite
	categories = dtile.categories.duplicate(true)
	references = dtile.references.duplicate(true)

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
	if not references.is_empty():
		data["references"] = references
	return data

# Remove a reference from this tile
func remove_reference(module: String, type: String, refid: String):
	if references.has(module) and references[module].has(type):
		references[module][type].erase(refid)
		if references[module][type].is_empty():
			references[module].erase(type)
		if references[module].is_empty():
			references.erase(module)

# Add a reference to this tile
func add_reference(module: String, type: String, refid: String):
	if not references.has(module):
		references[module] = {}
	if not references[module].has(type):
		references[module][type] = []
	if refid not in references[module][type]:
		references[module][type].append(refid)

# Execute a callable function on each reference of the given type
func execute_callable_on_references_of_type(module: String, type: String, callable: Callable):
	if references.has(module) and references[module].has(type):
		for refid in references[module][type]:
			callable.call(refid)
