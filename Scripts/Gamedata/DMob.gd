class_name DMob
extends RefCounted


# There's a D in front of the class name to indicate this class only handles mob data, nothing more
# This script is intended to be used inside the GameData autoload singleton
# This script handles the data for one mob. You can access it through Gamedata.mobs

#Example mob data:
#	{
#		"description": "A small robot",
#		"health": 80,
#		"hearing_range": 1000,
#		"id": "scrapwalker",
#		"idle_move_speed": 0.5,
#		"loot_group": "mob_loot",
#		"melee_damage": 20,
#		"melee_range": 1.5,
#		"move_speed": 2.1,
#		"name": "Scrap walker",
#		"references": {
#			"core": {
#				"maps": [
#					"Generichouse",
#					"store_electronic_clothing"
#				],
#				"quests": [
#					"starter_tutorial_00"
#				]
#			}
#		},
#		"sense_range": 50,
#		"sight_range": 200,
#		"sprite": "scrapwalker64.png"
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

# Constructor to initialize mob properties from a dictionary
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
		Gamedata.mobs.save_mobs_to_disk()

# Adds a reference to the references list
func add_reference(module: String, type: String, refid: String):
	var changes_made = Gamedata.dadd_reference(references, module, type, refid)
	if changes_made:
		Gamedata.mobs.save_mobs_to_disk()

# Returns the path of the sprite
func get_sprite_path() -> String:
	return Gamedata.mobs.spritePath + spriteid

# Handles mob changes and updates references if necessary
func on_data_changed(_oldmob: DMob):
	var changes_made = false

	# If any references were updated, save the changes to the data file
	if changes_made:
		print_debug("mob reference updates saved successfully.")
		Gamedata.save_data_to_file(Gamedata.data.mobgroups)


# Some mob has been changed
# INFO if the mobs reference other entities, update them here
func changed(_olddata: DMob):
	Gamedata.mobs.save_mobs_to_disk()


# A mob is being deleted from the data
# We have to remove it from everything that references it
func delete():
	# Check if the mob has references to maps and remove it from those maps
	var mapsdata = Helper.json_helper.get_nested_data(references, "core.maps")
	if mapsdata:
		Gamedata.maps.remove_entity_from_selected_maps("mob", id, mapsdata)


# Executes a callable function on each reference of the given type
func execute_callable_on_references_of_type(module: String, type: String, callable: Callable):
	# Check if it contains the specified 'module' and 'type'
	if references.has(module) and references[module].has(type):
		# If the type exists, execute the callable on each ID found under this type
		for ref_id in references[module][type]:
			callable.call(ref_id)
