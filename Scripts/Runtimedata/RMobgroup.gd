class_name RMobgroup
extends RefCounted

# This class represents a mob group with its properties
# Only used while the game is running
# Example mob group data:
# {
#     "id": "basic_zombies",
#     "name": "Basic zombies",
#     "description": "The default, basic zombies posing a low threat to the player",
#     "spriteid": "scrapwalker64.png",
#     "mobs": {
#         "basic_zombie_1": 100,
#         "basic_zombie_2": 100,
#         "limping_zombie": 25,
#         "fast_zombie": 10,
#         "heavy_zombie": 25
#     }
# }

# Properties defined in the mob group
var id: String
var name: String
var description: String
var spriteid: String
var sprite: Texture
var mobs: Dictionary = {}  # Holds mob IDs and their weights
var referenced_maps: Array[String] = []
var parent: RMobgroups  # Reference to the list containing all runtime mob groups for this mod

# Constructor to initialize mob group properties from a dictionary
# myparent: The list containing all mob groups for this mod
# newid: The ID of the mob group being created
func _init(myparent: RMobgroups, newid: String):
	parent = myparent
	id = newid

# Overwrite this mob group's properties using a DMobgroup
func overwrite_from_dmobgroup(dmobgroup: DMobgroup) -> void:
	if not id == dmobgroup.id:
		print_debug("Cannot overwrite from a different id")
	name = dmobgroup.name
	description = dmobgroup.description
	spriteid = dmobgroup.spriteid
	sprite = dmobgroup.sprite
	mobs = dmobgroup.mobs.duplicate(true)
	var group_maps: Array = dmobgroup.get_maps()
	# Append group maps to referenced_maps, ensuring uniqueness
	referenced_maps = Helper.json_helper.merge_unique(referenced_maps, group_maps)

# Get data function to return a dictionary with all properties
func get_data() -> Dictionary:
	var data: Dictionary = {
		"id": id,
		"name": name,
		"description": description,
		"spriteid": spriteid,
		"mobs": mobs
	}
	return data


# Function to check if a specific mob ID exists in the "mobs" property
func has_mob(mob_id: String) -> bool:
	return mobs.has(mob_id)


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


# Retrieves all maps associated with the mob group, including maps from its mobs.
func get_maps() -> Array:
	# Get a list of all maps that reference this mob
	var mymaps: Array = referenced_maps.duplicate()
	var modreferencedmaps: Array = []
	# We check the reference for each mob in each mod
	# Collect maps from each mob in the group
	for mob_id in mobs.keys():
		modreferencedmaps = Runtimedata.mobs.by_id(mob_id).referenced_maps # Get the maps from the references
		mymaps = Helper.json_helper.merge_unique(mymaps, modreferencedmaps) # Merge with current list
	
	# Return the map data, or an empty array if no data is found
	return mymaps if mymaps else []
