class_name DMobgroup
extends RefCounted


# There's a D in front of the class name to indicate this class only handles mob data, nothing more
# This script is intended to be used inside the GameData autoload singleton
# This script handles the data for one mobgroup. You can access it through Gamedata.mobgroups


# Represents a mob group and its properties.
# This script is used for handling mob group data within the GameData autoload singleton.
# Example mob group JSON:
# {
# 	"id": "basic_zombies",
# 	"name": "Basic zombies",
# 	"description": "The default, basic zombies posing a low threat to the player",
# 	"spriteid": "scrapwalker64.png",
# 	"references": {
# 		"core": {
# 			"maps": [
# 				"Generichouse",
# 				"store_electronic_clothing"
# 			]
# 		}
# 	},
# 	"mobs": {
# 		"basic_zombie_1": 100,
# 		"basic_zombie_2": 100,
# 		"limping_zombie": 25,
# 		"fast_zombie": 10,
# 		"heavy_zombie": 25
# 	}
# }

# Properties defined in the JSON structure
var id: String
var name: String
var description: String
var spriteid: String
var sprite: Texture
var references: Dictionary = {}
var mobs: Dictionary = {}  # Holds the list of mobs and their weights

# Constructor to initialize mob group properties from a dictionary
func _init(data: Dictionary):
	id = data.get("id", "")
	name = data.get("name", "")
	description = data.get("description", "")
	spriteid = data.get("spriteid", "")
	references = data.get("references", {})
	mobs = data.get("mobs", {})


# Returns all properties of the mob group as a dictionary
func get_data() -> Dictionary:
	var data: Dictionary = {
		"id": id,
		"name": name,
		"description": description,
		"spriteid": spriteid,
		"mobs": mobs
	}
	if not references.is_empty():
		data["references"] = references
	return data


# Method to save any changes to the stat back to disk
func save_to_disk():
	Gamedata.mobgroups.save_stats_to_disk()


# Removes the specified reference from the mob group's references
func remove_reference(module: String, type: String, refid: String):
	var changes_made = Gamedata.dremove_reference(references, module, type, refid)
	if changes_made:
		Gamedata.mobgroups.save_mobgroups_to_disk()

# Adds a new reference to the mob group's references
func add_reference(module: String, type: String, refid: String):
	var changes_made = Gamedata.dadd_reference(references, module, type, refid)
	if changes_made:
		Gamedata.mobgroups.save_mobgroups_to_disk()

# Handles changes to the mob group, such as updating references
func changed(olddata: DMobgroup):
	update_mob_references(olddata)
	Gamedata.mobgroups.save_mobgroups_to_disk()

# Updates references to mobs within the mob group
func update_mob_references(olddata: DMobgroup):
	var old_mobs = olddata.mobs.keys()
	var new_mobs = mobs.keys()

	# Remove old references not present in the new data
	for old_mob in old_mobs:
		if not new_mobs.has(old_mob):
			Gamedata.mods.remove_reference(DMod.ContentType.MOBS, old_mob, DMod.ContentType.MOBGROUPS, id)

	# Add new references
	for new_mob in new_mobs:
		Gamedata.mods.add_reference(DMod.ContentType.MOBS, new_mob, DMod.ContentType.MOBGROUPS, id)


# Deletes the mob group, removing all its references
func delete():
	# Remove references to maps
	var mapsdata: Array = Helper.json_helper.get_nested_data(references, "core.maps")
	for mymap: String in mapsdata:
		var mymaps: Array = Gamedata.mods.get_all_content_by_id(DMod.ContentType.MAPS, mymap)
		for dmap: DMaps in mymaps:
			dmap.remove_entity_from_selected_maps("mobgroup", id, mapsdata)

	# Remove references to mobs
	for mob in mobs.keys():
		Gamedata.mods.remove_reference(DMod.ContentType.MOBS, mob, DMod.ContentType.MOBGROUPS, id)
	
	# This callable will handle the removal of this mobgroup from all steps in quests
	var remove_from_quest: Callable = func(quest_id: String):
		Gamedata.mods.by_id("Core").quests.remove_mobgroup_from_quest(quest_id,id)
		
	# Pass the callable to every quest in the mobgroup's references
	# It will call remove_from_quest on every mobgroup in mobgroup_data.references.core.quests
	execute_callable_on_references_of_type("core", "quests", remove_from_quest)


# Retrieves all maps associated with the mob group, including maps from its mobs.
func get_maps() -> Array:
	var unique_maps: Array = Helper.json_helper.get_nested_data(references, "core.maps")

	# Collect maps from each mob in the group
	for mob_id in mobs.keys():
		var mob = Gamedata.mods.by_id("Core").mobs.by_id(mob_id)
		if mob:
			unique_maps = Helper.json_helper.merge_unique(unique_maps, mob.get_maps())
	return unique_maps


# Function to return an array of all mob IDs in the "mobs" property
func get_mob_ids() -> Array[String]:
	var mob_ids: Array[String] = []
	for mob_id in mobs.keys():
		mob_ids.append(mob_id)
	return mob_ids


# Function to check if a specific mob ID exists in the "mobs" property
func has_mob(mob_id: String) -> bool:
	return mobs.has(mob_id)


# Executes a callable function on each reference of the given type
func execute_callable_on_references_of_type(module: String, type: String, callable: Callable):
	# Check if it contains the specified 'module' and 'type'
	if references.has(module) and references[module].has(type):
		# If the type exists, execute the callable on each ID found under this type
		for ref_id in references[module][type]:
			callable.call(ref_id)


# Function to return a randomly selected mob ID based on the weights in the "mobs" property
func get_random_mob_id() -> String:
	# If no mobs are present, return an empty string
	if mobs.is_empty():
		return ""

	# Calculate the total weight
	var total_weight: int = 0
	for weight in mobs.values():
		total_weight += weight

	# Generate a random number within the total weight
	var random_pick: int = randi() % total_weight

	# Iterate through the mobs and select the mob based on the random pick
	for mob_id in mobs.keys():
		random_pick -= mobs[mob_id]
		if random_pick < 0:
			return mob_id  # Return the selected mob ID

	return ""  # Fallback in case of an error, should not be reached
