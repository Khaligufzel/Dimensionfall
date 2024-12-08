class_name DMob
extends RefCounted


# There's a D in front of the class name to indicate this class only handles mob data, nothing more
# This script is intended to be used inside the GameData autoload singleton
# This script handles the data for one mob. You can access it through Gamedata.mods.by_id("Core").mobs


# This class represents a mob with its properties
# Example mob data:
# {
# 	"description": "A small robot",
# 	"health": 80,
# 	"hearing_range": 1000,
# 	"id": "scrapwalker",
# 	"idle_move_speed": 0.5,
# 	"loot_group": "mob_loot",
# 	"move_speed": 2.1,
# 	"melee_range": 1.5,
# 	"melee_knockback": 2.0,
# 	"melee_cooldown": 2.0,
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
# 	"special_moves": {
# 		"dash": {"speed_multiplier":2,"cooldown":5,"duration":0.5}
# 	},
#	"targetattributes": {
#		"any_of": [
#			{
#				"id": "head_health",
#				"damage": 10
#			},
#			{
#				"id": "torso_health",
#				"damage": 10
#			}
#		],
#		"all_of": [
#			{
#				"id": "poison",
#				"damage": 10
#			},
#			{
#				"id": "stun",
#				"damage": 10
#			}
#		]
#	}
# 	"spriteid": "scrapwalker64.png"
# }

# Properties defined in the JSON
var id: String
var name: String
var description: String
var default_faction: String
var health: int
var hearing_range: int
var idle_move_speed: float
var loot_group: String
var melee_range: float
var melee_knockback: float  # New property for melee knockback
var melee_cooldown: float   # New property for melee cooldown
var move_speed: float
var sense_range: int
var sight_range: int
var special_moves: Dictionary = {} # Holds special moves like {"dash":{"speed_multiplier":2,"cooldown":5,"duration":0.5}}
var spriteid: String
var sprite: Texture
# Updated targetattributes variable to use the new data structure
var targetattributes: Dictionary = {}
var parent: DMobs

# Constructor to initialize quest properties from a dictionary
# myparent: The list containing all quests for this mod
func _init(data: Dictionary, myparent: DMobs):
	parent = myparent
	id = data.get("id", "")
	name = data.get("name", "")
	description = data.get("description", "")
	default_faction = data.get("default_faction", "")
	health = data.get("health", 100)
	hearing_range = data.get("hearing_range", 1000)
	idle_move_speed = data.get("idle_move_speed", 0.5)
	loot_group = data.get("loot_group", "")
	melee_range = data.get("melee_range", 1.5)
	melee_knockback = data.get("melee_knockback", 2.0)  # Initialize with default value
	melee_cooldown = data.get("melee_cooldown", 2.0)    # Initialize with default value
	move_speed = data.get("move_speed", 1.0)
	sense_range = data.get("sense_range", 50)
	sight_range = data.get("sight_range", 200)
	# Initialize special moves from data, retrieving dash from special_moves
	special_moves = data.get("special_moves", {})
	spriteid = data.get("sprite", "")
	
	# Initialize targetattributes based on the new format
	if data.has("targetattributes"):
		targetattributes = data["targetattributes"]

# Get data function to return a dictionary with all properties
func get_data() -> Dictionary:
	var data: Dictionary = {
		"id": id,
		"name": name,
		"description": description,
		"default_faction": default_faction,
		"health": health,
		"hearing_range": hearing_range,
		"idle_move_speed": idle_move_speed,
		"loot_group": loot_group,
		"melee_range": melee_range,
		"melee_knockback": melee_knockback,  # Add to data output
		"melee_cooldown": melee_cooldown,    # Add to data output
		"move_speed": move_speed,
		"sense_range": sense_range,
		"sight_range": sight_range,
		"sprite": spriteid
	}
	if not special_moves.is_empty():
		data["special_moves"] = special_moves
	if not targetattributes.is_empty():
		data["targetattributes"] = targetattributes
	return data


# Function to return an array of all "id" values in the targetattributes
func get_attr_ids() -> Array:
	var ids: Array = []
	for attribute in targetattributes.get("any_of", []):
		if attribute.has("id"):
			ids.append(attribute["id"])
	for attribute in targetattributes.get("all_of", []):
		if attribute.has("id"):
			ids.append(attribute["id"])
	return ids


# Some mob has been changed
# INFO if the mob reference other entities, update them here
func changed(olddata: DMob):
	var old_loot_group: String = olddata.loot_group

	# Exit if old_group and new_group are the same
	if old_loot_group and not old_loot_group == loot_group:
		# This mob will be removed from the old itemgroup's references
		Gamedata.itemgroups.remove_reference(old_loot_group, "core", "mobs", id)
		
		# This mob will be added to the new itemgroup's references
		Gamedata.itemgroups.add_reference(loot_group, "core", "mobs", id)
	update_mob_attribute_references(olddata)
	parent.save_mobs_to_disk() # Save changes regardless of whether or not a reference was updated


# A mob is being deleted from the data
# We have to remove it from everything that references it
func delete():
	# Check to see if any mod has a copy of this tile. if one or more remain, we can keep references
	# Otherwise, the last copy was removed and we need to remove references
	var all_results: Array = Gamedata.mods.get_all_content_by_id(DMod.ContentType.MOBS, id)
	if all_results.size() > 0:
		return
		
	Gamedata.itemgroups.remove_reference(loot_group, "core", "mobs", id)
	
	# Get a list of all maps that reference this mob
	var myreferences: Dictionary = parent.references.get(id, {})
	var mymaps: Array = myreferences.get("maps", [])
	# For each mod, remove this mob from the maps in this mob's references
	for mod: DMod in Gamedata.mods.get_all_mods():
		mod.maps.remove_entity_from_selected_maps("mob", id, mymaps)
	
	# This callable will handle the removal of this mob from all steps in quests
	var remove_from_quest: Callable = func(quest_id: String):
		Gamedata.mods.by_id("Core").quests.remove_mob_from_quest(quest_id,id)
		
	# Pass the callable to every quest in the mob's references
	# It will call remove_from_quest on every mob in mob_data.references.core.quests
	execute_callable_on_references_of_type(DMod.ContentType.QUESTS, remove_from_quest)


# Executes a callable function on each reference of the given type
# type: The type of entity that you want to execute the callable for
# callable: The function that will be executed for every entity of this type
func execute_callable_on_references_of_type(type: DMod.ContentType, callable: Callable):
	# myreferences will ba dictionary that contains entity types that have references to this skill's id
	# See DMod.add_reference for an example structure of references
	var myreferences: Dictionary = parent.references.get(id, {})
	var type_string: String = DMod.get_content_type_string(type)
	# Check if it contains the specified 'module' and 'type'
	if myreferences.has(type_string):
		# If the type exists, execute the callable on each ID found under this type
		for ref_id in myreferences[type_string]:
			callable.call(ref_id)


# Collects all attributes defined in an item and updates the references to that attribute
func update_mob_attribute_references(olddata: DMob):
	# Collect skill IDs from old and new data
	var old_attr_ids = olddata.get_attr_ids()
	var new_attr_ids = get_attr_ids()

	# Remove old skill references that are not in the new list
	for old_attr_id in old_attr_ids:
		if not new_attr_ids.has(old_attr_id):
			Gamedata.mods.remove_reference(DMod.ContentType.PLAYERATTRIBUTES, old_attr_id, DMod.ContentType.MOBS, id)
	
	# Add new attribute references
	for new_attr_id in new_attr_ids:
		Gamedata.mods.remove_reference(DMod.ContentType.PLAYERATTRIBUTES, new_attr_id, DMod.ContentType.MOBS, id)


# Function to retrieve an array of maps from the references
func get_maps() -> Array:
	# Get a list of all maps that reference this mob
	var myreferences: Dictionary = parent.references.get(id, {})
	var mymaps: Array = myreferences.get("maps", [])
	# Return the map data, or an empty array if no data is found
	return mymaps if mymaps else []
