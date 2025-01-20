class_name RMobfaction
extends RefCounted

# This class represents a mob faction with its properties, only used while the game is running.
# Example mob faction JSON:
# {
#     "id": "undead",
#     "name": "The Undead",
#     "description": "The unholy remainders of our past sins.",
#     "relations": [
#         {
#             "relation_type": "core",
#             "mobgroup": ["basic_zombies", "basic_vampires"],
#             "mobs": ["small slime", "big slime"]
#         },
#         {
#             "relation_type": "hostile",
#             "mobgroup": ["security_robots", "national_guard"],
#             "mobs": ["jabberwock", "cerberus"]
#         }
#     ]
# }

# Properties defined in the mob faction
var id: String
var name: String
var description: String
var relations: Array = []  # Array of relation dictionaries
var references: Dictionary = {}  # References to other data entities
var parent: RMobfactions  # Reference to the list containing all runtime mob factions for this mod

# Constructor to initialize mob faction properties
# myparent: The list containing all runtime mob factions for this mod
# newid: The ID of the mob faction being created
func _init(myparent: RMobfactions, newid: String):
	parent = myparent
	id = newid

# Overwrite this mob faction's properties using a DMobfaction
func overwrite_from_dmobfaction(dmobfaction: DMobfaction) -> void:
	if id != dmobfaction.id:
		print_debug("Cannot overwrite from a different id")
		return
	name = dmobfaction.name
	description = dmobfaction.description
	relations = dmobfaction.relations
	#references = dmobfaction.references

# Get data function to return a dictionary with all properties
func get_data() -> Dictionary:
	var data: Dictionary = {
		"id": id,
		"name": name,
		"description": description,
		"relations": relations
	}
	if not references.is_empty():
		data["references"] = references
	return data

# Handles changes to mob faction data
# Updates references between mobs, mob groups, and the mob faction
func on_data_changed(olddmobfaction: DMobfaction):
	# Get mobs and mobgroups from the old relations
	var old_mob_relations = olddmobfaction.relations.filter(func(relation): return relation.has("mobs"))
	var old_mobgroup_relations = olddmobfaction.relations.filter(func(relation): return relation.has("mobgroup"))
	# Get mobs and mobgroups from the new relations
	var new_mob_relations = relations.filter(func(relation): return relation.has("mobs"))
	var new_mobgroup_relations = relations.filter(func(relation): return relation.has("mobgroup"))

	# Remove references for old mobs not in the new data
	for old_relation in old_mob_relations:
		if old_relation not in new_mob_relations:
			for mob in old_relation.mobs:
				parent.remove_reference(id, "mobs", mob)

	# Remove references for old mobgroups not in the new data
	for old_relation in old_mobgroup_relations:
		if old_relation not in new_mobgroup_relations:
			for mobgroup in old_relation.mobgroup:
				parent.remove_reference(id, "mobgroups", mobgroup)

	# Add references for new mobs
	for new_relation in new_mob_relations:
		for mob in new_relation.mobs:
			parent.add_reference(id, "mobs", mob)

	# Add references for new mobgroups
	for new_relation in new_mobgroup_relations:
		for mobgroup in new_relation.mobgroup:
			parent.add_reference(id, "mobgroups", mobgroup)

# Deletes this mob faction and removes all its references
func delete():
	# Remove mob references
	for relation in relations.filter(func(rel): return rel.has("mobs")):
		for mob in relation.mobs:
			parent.remove_reference(id, "mobs", mob)

	# Remove mobgroup references
	for relation in relations.filter(func(rel): return rel.has("mobgroup")):
		for mobgroup in relation.mobgroup:
			parent.remove_reference(id, "mobgroups", mobgroup)

	# Remove the mob faction itself
	if parent:
		parent.delete_by_id(id)

# Removes all relations where the mob property matches the given mob_id
func remove_relations_by_mob(mob_id: String) -> void:
	relations = relations.filter(func(relation): 
		return not (relation.has("mobs") and mob_id in relation.mobs)
	)
	if parent:
		parent.save_to_disk()

# Removes all relations where the mobgroup property matches the given mobgroup_id
func remove_relations_by_mobgroup(mobgroup_id: String) -> void:
	relations = relations.filter(func(relation): 
		return not (relation.has("mobgroup") and mobgroup_id in relation.mobgroup)
	)
	if parent:
		parent.save_to_disk()


# Retrieves a list of mob IDs from relations where the relation_type matches the provided type.
# relation_type: String  # Can be "hostile", "neutral", or "friendly"
func get_mobs_by_relation_type(relation_type: String) -> Array:
	var mob_list: Array = []
	
	# Iterate through all relations
	for relation in relations:
		if relation.relation_type == relation_type:
			# Add all mob IDs from the matching relation
			mob_list += relation.get_mob_ids()
	
	return mob_list
