class_name RTacticalmaps
extends RefCounted

# There's a R in front of the class name to indicate this class only handles runtime tacticalmaps data, nothing more
# This script is intended to be used inside the Runtime autoload singleton
# This script handles the list of tacticalmaps. You can access it through Runtime.mods.by_id("Core").tacticalmaps

# Paths for tactical map data and sprites
var tacticalmap_dict: Dictionary = {}
var sprites: Dictionary = {}


# Constructor
func _init() -> void:
	# Get all mods and their IDs
	var mod_ids: Array = Gamedata.mods.get_all_mod_ids()

	# Loop through each mod to get its DTacticalmaps
	for mod_id in mod_ids:
		var dtacticalmaps: DTacticalmaps = Gamedata.mods.by_id(mod_id).tacticalmaps

		# Loop through each DTacticalmap in the mod
		for dtacticalmap_id: String in dtacticalmaps.get_all().keys():
			var dtacticalmap: DTacticalmap = dtacticalmaps.by_id(dtacticalmap_id)

			# Check if the tactical map exists in tacticalmap_dict
			var rtacticalmap: RTacticalmap
			if not tacticalmap_dict.has(dtacticalmap_id):
				# If it doesn't exist, create a new RTacticalmap
				rtacticalmap = add_new(dtacticalmap_id)
			else:
				# If it exists, get the existing RTacticalmap
				rtacticalmap = tacticalmap_dict[dtacticalmap_id]

			# Overwrite the RTacticalmap properties with the DTacticalmap properties
			rtacticalmap.overwrite_from_dtacticalmap(dtacticalmap)


# Returns the dictionary containing all tactical maps
func get_all() -> Dictionary:
	return tacticalmap_dict


# Adds a new tactical map with a given ID
func add_new(newid: String) -> RTacticalmap:
	var new_tacticalmap: RTacticalmap = RTacticalmap.new(self, newid, "")
	tacticalmap_dict[new_tacticalmap.id] = new_tacticalmap
	return new_tacticalmap


# Deletes a tactical map by its ID and saves changes to disk
func delete_by_id(tacticalmap_id: String) -> void:
	tacticalmap_dict[tacticalmap_id].delete()
	tacticalmap_dict.erase(tacticalmap_id)


# Returns a tactical map by its ID
func by_id(tacticalmap_id: String) -> RTacticalmap:
	return tacticalmap_dict[tacticalmap_id]


# Checks if a tactical map exists by its ID
func has_id(tacticalmap_id: String) -> bool:
	return tacticalmap_dict.has(tacticalmap_id)


# Returns the sprite of the tactical map
func sprite_by_id(tacticalmap_id: String) -> Texture:
	return tacticalmap_dict[tacticalmap_id].sprite

# Returns the sprite by its file name
func sprite_by_file(spritefile: String) -> Texture:
	return sprites[spritefile]


# Returns a random map
func get_random_map() -> RTacticalmap:
	var map_ids = tacticalmap_dict.keys()
	if map_ids.is_empty():
		return null
	var random_id = map_ids.pick_random()
	return tacticalmap_dict[random_id]
