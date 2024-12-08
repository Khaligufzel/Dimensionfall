class_name DMobfaction
extends RefCounted


# There's a D in front of the class name to indicate this class only handles mob data, nothing more
# This script is intended to be used inside the GameData autoload singleton
# This script handles the data for one mobfaction. You can access it through Gamedata.mobfactions


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
#				"mobs": ["small slime", "big slime"]
#			},
#			{
#				"relation_type": "hostile"
#				"mobgroup": ["security_robots", "national_guard"],
#				"mobs": ["jabberwock", "cerberus"]
#			}
#		]
#	}

# Properties defined in the JSON structure
var id: String
var name: String
var description: String
var references: Dictionary = {}
var relations: Array = []
var mobs: Dictionary = {}
var mobgroups: Dictionary = {}

# Constructor to initialize mob faction properties from a dictionary
func _init(data: Dictionary):
	id = data.get("id", "")
	name = data.get("name", "")
	description = data.get("description", "")
	references = data.get("references", {})
	relations = data.get("relations", [])

# Returns all properties of the mob faction as a dictionary
func get_data() -> Dictionary:
	var data: Dictionary = {
		"id": id,
		"name": name,
		"description": description,
		"relations": relations,
	}
	if not references.is_empty():
		data["references"] = references
	return data


# Method to save any changes to the stat back to disk
func save_to_disk():
	Gamedata.mobfactions.save_mobfactions_to_disk()
# Handles faction deletion
func delete():
	var relationmobs: Array =  relations.filter(func(relation): return relation.has("mob"))
	for killrelation in relationmobs:
		Gamedata.mods.remove_reference(DMod.ContentType.MOBS, killrelation.mob, DMod.ContentType.MOBFACTIONS, id)
	var relationmobgroups: Array = relations.filter(func(relation): return relation.has("mobgroup"))
	for killrelation in relationmobgroups:
		Gamedata.mobgroups.remove_reference(killrelation.mobgroup, "core", "mobfactions", id)

# Handles quest changes
func changed(olddata: DMobfaction):
	# Get mobs and mobgroups from the old relations
	var old_quest_mobs: Array = olddata.relations.filter(func(relation): return relation.has("mob"))
	var old_quest_mobgroups: Array = olddata.relations.filter(func(relation): return relation.has("mobgroup"))
	# Get mobs and mobgroups from the new relations
	var new_quest_mobs: Array = relations.filter(func(relation): return relation.has("mob"))
	var new_quest_mobgroups: Array = relations.filter(func(relation): return relation.has("mobgroup"))

	# Remove references for old mobs that are not in the new data
	for old_mob in old_quest_mobs:
		if old_mob not in new_quest_mobs:
			Gamedata.mods.remove_reference(DMod.ContentType.MOBS, old_mob.mob, DMod.ContentType.MOBFACTIONS, id)
	# Remove references for old mobgroups that are not in the new data
	for old_mobgroup in old_quest_mobgroups:
		if old_mobgroup not in new_quest_mobgroups:
			Gamedata.mobgroups.remove_reference(old_mobgroup.mobgroup, "core", "mobfactions", id)
	
	# Add references for new mobs
	for new_mob in new_quest_mobs:
		Gamedata.mods.add_reference(DMod.ContentType.MOBS, new_mob.mob, DMod.ContentType.MOBFACTIONS, id)
	# Add references for new mobgroups
	for new_mobgroup in new_quest_mobgroups:
		Gamedata.mobgroups.add_reference(new_mobgroup.mobgroup, "core", "mobfactions", id)
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
