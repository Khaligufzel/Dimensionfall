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
#	"attacks": {
#		"melee": [
#			{
#				"id": "basic_melee",
#				"multiplier": 1.1
#			},
#			{
#				"id": "advanced_melee",
#				"multiplier": 1.0
#			}
#		],
#		"ranged": [
#			{
#				"id": "basic_ranged",
#				"multiplier": 1.0
#			},
#			{
#				"id": "advanced_ranged",
#				"multiplier": 1.0
#			}
#		]
#	}
# 	"spriteid": "scrapwalker64.png"
# }

# Properties defined in the JSON
var id: String
var name: String
var faction_id: String = "default"
var description: String
var default_faction: String
var health: int
var hearing_range: int
var idle_move_speed: float
var loot_group: String
var move_speed: float
var sense_range: int
var sight_range: int
var special_moves: Dictionary = {} # Holds special moves like {"dash":{"speed_multiplier":2,"cooldown":5,"duration":0.5}}
var spriteid: String
var sprite: Texture
var attacks: Dictionary = {} # List of attacks this mob can use
var parent: DMobs

# Constructor to initialize mob properties from a dictionary
# myparent: The list containing all mobs for this mod
func _init(data: Dictionary, myparent: DMobs):
	parent = myparent
	id = data.get("id", "")
	name = data.get("name", "")
	faction_id = data.get("faction_id", "")
	description = data.get("description", "")
	default_faction = data.get("default_faction", "")
	health = data.get("health", 100)
	hearing_range = data.get("hearing_range", 1000)
	idle_move_speed = data.get("idle_move_speed", 0.5)
	loot_group = data.get("loot_group", "")
	move_speed = data.get("move_speed", 1.0)
	sense_range = data.get("sense_range", 50)
	sight_range = data.get("sight_range", 200)
	# Initialize special moves from data, retrieving dash from special_moves
	special_moves = data.get("special_moves", {})
	spriteid = data.get("sprite", "")
	
	if data.has("attacks"):
		attacks = data["attacks"]

# Get data function to return a dictionary with all properties
func get_data() -> Dictionary:
	var data: Dictionary = {
		"id": id,
		"name": name,
		"faction_id": faction_id,
		"description": description,
		"default_faction": default_faction,
		"health": health,
		"hearing_range": hearing_range,
		"idle_move_speed": idle_move_speed,
		"loot_group": loot_group,
		"move_speed": move_speed,
		"sense_range": sense_range,
		"sight_range": sight_range,
		"sprite": spriteid
	}
	if not special_moves.is_empty():
		data["special_moves"] = special_moves
	if not attacks.is_empty():
		data["attacks"] = attacks
	return data


# Function to return an array of all "id" values in the attacks
func get_attk_ids() -> Array:
	var ids: Array = []
	for attack in attacks.get("melee", []):
		if attack.has("id"):
			ids.append(attack["id"])
	for attack in attacks.get("ranged", []):
		if attack.has("id"):
			ids.append(attack["id"])
	return ids


# Some mob has been changed
# INFO if the mob reference other entities, update them here
func changed(olddata: DMob):
	var old_loot_group: String = olddata.loot_group

	# Exit if old_group and new_group are the same
	if old_loot_group and not old_loot_group == loot_group:
		# This mob will be removed from the old itemgroup's references
		Gamedata.mods.remove_reference(DMod.ContentType.ITEMGROUPS, old_loot_group, DMod.ContentType.MOBS, id)
		
	# This mob will be added to the new itemgroup's references
	Gamedata.mods.add_reference(DMod.ContentType.ITEMGROUPS, loot_group, DMod.ContentType.MOBS, id)
	update_mob_attack_references(olddata)
	parent.save_mobs_to_disk() # Save changes regardless of whether or not a reference was updated


# A mob is being deleted from the data
# We have to remove it from everything that references it
func delete():
	# Check to see if any mod has a copy of this tile. if one or more remain, we can keep references
	# Otherwise, the last copy was removed and we need to remove references
	var all_results: Array = Gamedata.mods.get_all_content_by_id(DMod.ContentType.MOBS, id)
	if all_results.size() > 1:
		return

	# Get a list of all maps that reference this mob
	var myreferences: Dictionary = parent.references.get(id, {})
	var mymobgroups: Array = myreferences.get("mobgroups", [])
	# For each mod, remove this mob from the maps in this mob's references
	for mod: DMod in Gamedata.mods.get_all_mods():
		mod.maps.remove_entity_from_all_maps("mob", id)
		mod.mobgroups.remove_entity_from_selected_mobgroups(id, mymobgroups)

	# This callable will handle the removal of this mob from all steps in quests
	var remove_from_quest: Callable = func(quest_id: String):
		# Get all copies of the quest with quest_id from all mods
		var allmodquests: Array = Gamedata.mods.get_all_content_by_id(DMod.ContentType.QUESTS,quest_id)
		for quest: DQuest in allmodquests:
			quest.remove_steps_by_mob(id) # Remove the mob from the quest

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
	var typestring: String = DMod.get_content_type_string(type)
	# Check if it contains the specified 'module' and 'type'
	if myreferences.has(typestring):
		# If the type exists, execute the callable on each ID found under this type
		for ref_id in myreferences[typestring]:
			callable.call(ref_id)


# Collects all attacks defined in an item and updates the references to that attack
func update_mob_attack_references(olddata: DMob):
	# Collect skill IDs from old and new data
	var old_attk_ids = olddata.get_attk_ids()
	var new_attk_ids = get_attk_ids()

	# Remove old skill references that are not in the new list
	for old_attk_id in old_attk_ids:
		if not new_attk_ids.has(old_attk_id):
			Gamedata.mods.remove_reference(DMod.ContentType.ATTACKS, old_attk_id, DMod.ContentType.MOBS, id)
	
	# Add new attack references
	for new_attk_id in new_attk_ids:
		Gamedata.mods.add_reference(DMod.ContentType.ATTACKS, new_attk_id, DMod.ContentType.MOBS, id)


# Function to retrieve an array of maps from the references
func get_maps() -> Array:
	# Get a list of all maps that reference this mob
	var myreferences: Dictionary = parent.references.get(id, {})
	var mymaps: Array = myreferences.get("maps", [])
	# Return the map data, or an empty array if no data is found
	return mymaps if mymaps else []
