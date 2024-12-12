class_name DMobfaction
extends RefCounted


# There's a D in front of the class name to indicate this class only handles mob data, nothing more
# This script is intended to be used inside the GameData autoload singleton
# This script handles the data for one mobfaction. You can access it through Gamedata.mods.by_id("Core")


# Represents a mob faction and its properties.
# This script is used for handling mob faction data within the GameData autoload singleton.
# Example mob faction JSON:
# {
# 	"id": "undead",
# 	"name": "The Undead",
# 	"description": "The unholy remainders of our past sins.",
#	"relations": [
#			{
#				"relation_type": "core"
#				"mobgroup": ["basic_zombies", "basic_vampires"],
#				"mobs": ["small slime", "big slime"],
#				"factions": ["human_faction", "animal_faction"]
#			},
#			{
#				"relation_type": "hostile"
#				"mobgroup": ["security_robots", "national_guard"],
#				"mobs": ["jabberwock", "cerberus"],
#				"factions": ["human_faction", "animal_faction"]
#			}
#		]
#	}

# Inner class to handle relations in a mob faction
class Relation:
	var relation_type: String  # Can be "hostile", "neutral", or "friendly"
	var mobgroups: Array = []  # Array of mobgroup IDs
	var mobs: Array = []       # Array of mob IDs
	var factions: Array = []   # Array of faction IDs

	# Constructor to initialize the relation with data from a dictionary
	func _init(relation_data: Dictionary):
		relation_type = relation_data.get("relation_type", "neutral")  # Default to "neutral" if not specified
		mobgroups = relation_data.get("mobgroups", [])
		mobs = relation_data.get("mobs", [])
		factions = relation_data.get("factions", [])

	# Returns all relation properties as a dictionary
	func get_data() -> Dictionary:
		var data: Dictionary = {
			"relation_type": relation_type
		}
		if not mobgroups.is_empty():
			data["mobgroups"] = mobgroups
		if not mobs.is_empty():
			data["mobs"] = mobs
		if not factions.is_empty():
			data["factions"] = factions
		return data

	# Returns all mob IDs
	func get_mob_ids() -> Array:
		return mobs

	# Returns all mobgroup IDs
	func get_mobgroup_ids() -> Array:
		return mobgroups

	# Returns all faction IDs
	func get_faction_ids() -> Array:
		return factions


# Properties defined in the JSON structure
var id: String
var name: String
var description: String
var relations: Array = []
var parent: DMobfactions

# Constructor to initialize itemgroup properties from a dictionary
# myparent: The list containing all itemgroups for this mod
func _init(data: Dictionary, myparent: DMobfactions):
	parent = myparent
	id = data.get("id", "")
	name = data.get("name", "")
	description = data.get("description", "")
	relations = []
	for relation_data in data.get("relations", []):
		relations.append(Relation.new(relation_data))


# Returns all properties of the mob faction as a dictionary
func get_data() -> Dictionary:
	var data: Dictionary = {
		"id": id,
		"name": name,
		"description": description,
		"relations": []
	}
	for relation in relations:
		data["relations"].append(relation.get_data())
	return data


# Method to save any changes to the stat back to disk
func save_to_disk():
	parent.save_mobfactions_to_disk()

# A mobfaction is being deleted from the data
# We have to remove it from everything that references it
func delete():
	# Check to see if any mod has a copy of this mobfaction. if one or more remain, we can keep references
	# Otherwise, the last copy was removed and we need to remove references
	var all_results: Array = Gamedata.mods.get_all_content_by_id(DMod.ContentType.MOBFACTIONS, id)
	if all_results.size() > 1:
		parent.remove_reference(id) # Erase the reference for the id in this mod
		return

	# Remove all references from current relations
	for relation in relations:
		for mob_id in relation.get_mob_ids():
			Gamedata.mods.remove_reference(DMod.ContentType.MOBS, mob_id, DMod.ContentType.MOBFACTIONS, id)

		for mobgroup_id in relation.get_mobgroup_ids():
			Gamedata.mods.remove_reference(DMod.ContentType.MOBGROUPS, mobgroup_id, DMod.ContentType.MOBFACTIONS, id)

		for faction_id in relation.get_faction_ids():
			Gamedata.mods.remove_reference(DMod.ContentType.MOBFACTIONS, faction_id, DMod.ContentType.MOBFACTIONS, id)
	parent.remove_reference(id) # Erase the reference for the id in this mod


# Handles quest changes
func changed(olddata: DMobfaction):
	var old_mob_ids: Array = []
	var old_mobgroup_ids: Array = []
	var old_faction_ids: Array = []

	# Collect IDs from olddata relations
	for old_relation in olddata.relations:
		old_mob_ids += old_relation.get_mob_ids()
		old_mobgroup_ids += old_relation.get_mobgroup_ids()
		old_faction_ids += old_relation.get_faction_ids()

	var new_mob_ids: Array = []
	var new_mobgroup_ids: Array = []
	var new_faction_ids: Array = []

	# Collect IDs from current relations
	for new_relation in relations:
		new_mob_ids += new_relation.get_mob_ids()
		new_mobgroup_ids += new_relation.get_mobgroup_ids()
		new_faction_ids += new_relation.get_faction_ids()

	# Remove outdated references
	for old_mob_id in old_mob_ids:
		if old_mob_id not in new_mob_ids:
			Gamedata.mods.remove_reference(DMod.ContentType.MOBS, old_mob_id, DMod.ContentType.MOBFACTIONS, id)

	for old_mobgroup_id in old_mobgroup_ids:
		if old_mobgroup_id not in new_mobgroup_ids:
			Gamedata.mods.remove_reference(DMod.ContentType.MOBGROUPS, old_mobgroup_id, DMod.ContentType.MOBFACTIONS, id)

	for old_faction_id in old_faction_ids:
		if old_faction_id not in new_faction_ids:
			Gamedata.mods.remove_reference(DMod.ContentType.MOBFACTIONS, old_faction_id, DMod.ContentType.MOBFACTIONS, id)

	# Add new references
	for new_mob_id in new_mob_ids:
		if new_mob_id not in old_mob_ids:
			Gamedata.mods.add_reference(DMod.ContentType.MOBS, new_mob_id, DMod.ContentType.MOBFACTIONS, id)

	for new_mobgroup_id in new_mobgroup_ids:
		if new_mobgroup_id not in old_mobgroup_ids:
			Gamedata.mods.add_reference(DMod.ContentType.MOBGROUPS, new_mobgroup_id, DMod.ContentType.MOBFACTIONS, id)

	for new_faction_id in new_faction_ids:
		if new_faction_id not in old_faction_ids:
			Gamedata.mods.add_reference(DMod.ContentType.MOBFACTIONS, new_faction_id, DMod.ContentType.MOBFACTIONS, id)

	save_to_disk()


# Removes all relations where the mob property matches the given mob_id
func remove_relations_by_mob(mob_id: String) -> void:
	relations = relations.filter(func(relation): 
		return not (relation.has("mob") and relation.mob == mob_id)
	)
	save_to_disk()


# Removes all relations where the mobgroup property matches the given mobgroup_id
func remove_relations_by_mobgroup(mobgroup_id: String) -> void:
	relations = relations.filter(func(relation): 
		return not (relation.has("mobgroup") and relation.mobgroup == mobgroup_id)
	)
	save_to_disk()
