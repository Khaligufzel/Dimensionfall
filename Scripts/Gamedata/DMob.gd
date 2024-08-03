class_name DMob
extends RefCounted


# There's a D in front of the class name to indicate this class only handles mob data, nothing more
# This script is intended to be used inside the GameData autoload singleton
# This script handles the data for one mob. You can access it through Gamedata.mobs


# This class represents a mob with its properties
# Example mob data:
# {
# 	"description": "A small robot",
# 	"health": 80,
# 	"hearing_range": 1000,
# 	"id": "scrapwalker",
# 	"idle_move_speed": 0.5,
# 	"loot_group": "mob_loot",
# 	"melee_damage": 20,
# 	"melee_range": 1.5,
# 	"move_speed": 2.1,
# 	"name": "Scrap walker",
# 	"references": {
# 		"core": {
# 			"maps": [
# 				"Generichouse",
# 				"store_electronic_clothing"
# 			],
# 			"quests": [
# 				"starter_tutorial_00"
# 			]
# 		}
# 	},
# 	"sense_range": 50,
# 	"sight_range": 200,
# 	"spriteid": "scrapwalker64.png"
# }

# Properties defined in the JSON
var id: String
var name: String
var description: String
var health: int
var hearing_range: int
var idle_move_speed: float
var loot_group: String
var melee_damage: int
var melee_range: float
var move_speed: float
var sense_range: int
var sight_range: int
var spriteid: String
var sprite: Texture
var references: Dictionary = {}

# Constructor to initialize mob properties from a dictionary
func _init(data: Dictionary):
	id = data.get("id", "")
	name = data.get("name", "")
	description = data.get("description", "")
	health = data.get("health", 100)
	hearing_range = data.get("hearing_range", 1000)
	idle_move_speed = data.get("idle_move_speed", 0.5)
	loot_group = data.get("loot_group", "")
	melee_damage = data.get("melee_damage", 20)
	melee_range = data.get("melee_range", 1.5)
	move_speed = data.get("move_speed", 1.0)
	sense_range = data.get("sense_range", 50)
	sight_range = data.get("sight_range", 200)
	spriteid = data.get("sprite", "")
	references = data.get("references", {})

# Get data function to return a dictionary with all properties
func get_data() -> Dictionary:
	var data: Dictionary = {
		"id": id,
		"name": name,
		"description": description,
		"health": health,
		"hearing_range": hearing_range,
		"idle_move_speed": idle_move_speed,
		"loot_group": loot_group,
		"melee_damage": melee_damage,
		"melee_range": melee_range,
		"move_speed": move_speed,
		"sense_range": sense_range,
		"sight_range": sight_range,
		"sprite": spriteid
	}
	if not references.is_empty():
		data["references"] = references
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


# Some mob has been changed
# INFO if the mob reference other entities, update them here
func changed(olddata: DMob):
	var old_loot_group: String = olddata.loot_group

	# Exit if old_group and new_group are the same
	if old_loot_group == loot_group:
		print_debug("No change in mob. Exiting function.")
		return

	# This mob will be removed from the old itemgroup's references
	# The 'or' makes sure changes_made does not change back to false
	Gamedata.itemgroups.remove_reference(old_loot_group, "core", "mobs", id)
	
	# This mob will be added to the new itemgroup's references
	# The 'or' makes sure changes_made does not change back to false
	Gamedata.itemgroups.add_reference(loot_group, "core", "mobs", id)
	Gamedata.mobs.save_mobs_to_disk() # Save changes regardless of whether or not a reference was updated


# A mob is being deleted from the data
# We have to remove it from everything that references it
func delete():
	var changes_made = { "value": false }
	Gamedata.itemgroups.remove_reference(loot_group, "core", "mobs", id)
	
	# Check if the mob has references to maps and remove it from those maps
	var mapsdata = Helper.json_helper.get_nested_data(references,"core.maps")
	if mapsdata:
		Gamedata.maps.remove_entity_from_selected_maps("mob", id, mapsdata)
	
	# This callable will handle the removal of this mob from all steps in quests
	var remove_from_quest: Callable = func(quest_id: String):
		var quest_data = Gamedata.get_data_by_id(Gamedata.data.quests, quest_id)
		changes_made["value"] = Helper.json_helper.remove_object_by_id(quest_data, "steps.mob", id) or changes_made["value"]
		
	# Pass the callable to every quest in the mob's references
	# It will call remove_from_quest on every mob in mob_data.references.core.quests
	execute_callable_on_references_of_type("core", "quests", remove_from_quest)

	# Save changes to the data file if any changes were made
	if changes_made["value"]:
		Gamedata.save_data_to_file(Gamedata.data.quests)
	else:
		print_debug("No changes needed for mob", id)


# Executes a callable function on each reference of the given type
func execute_callable_on_references_of_type(module: String, type: String, callable: Callable):
	# Check if it contains the specified 'module' and 'type'
	if references.has(module) and references[module].has(type):
		# If the type exists, execute the callable on each ID found under this type
		for ref_id in references[module][type]:
			callable.call(ref_id)
