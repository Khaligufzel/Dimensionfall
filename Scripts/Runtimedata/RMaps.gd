class_name RMaps
extends RefCounted

# There's a R in front of the class name to indicate this class only handles runtime maps data, nothing more
# This script is intended to be used inside the Runtime autoload singleton
# This script handles the list of maps. You can access it through Runtime.mods.by_id("Core").maps

# Paths for map data and sprites
var map_dict: Dictionary = {}
var sprites: Dictionary = {}


# Constructor
func _init() -> void:
	# Get all mods and their IDs
	var mod_ids: Array = Gamedata.mods.get_all_mod_ids()

	# Loop through each mod to get its Dmaps
	for mod_id in mod_ids:
		var dmaps: DMaps = Gamedata.mods.by_id(mod_id).maps

		# Loop through each Dmap in the mod
		for dmap_id: String in dmaps.get_all().keys():
			var dmap: DMap = dmaps.by_id(dmap_id)

			# Check if the map exists in map_dict
			var rmap: RMap
			if not map_dict.has(dmap_id):
				# If it doesn't exist, create a new Rmap
				rmap = add_new(dmap_id)
			else:
				# If it exists, get the existing Rmap
				rmap = map_dict[dmap_id]

			# Overwrite the Rmap properties with the Dmap properties
			rmap.overwrite_from_dmap(dmap)


# Returns the dictionary containing all  maps
func get_all() -> Dictionary:
	return map_dict


# Adds a new  map with a given ID
func add_new(newid: String) -> RMap:
	var new_map: RMap = RMap.new(self, newid, "")
	map_dict[new_map.id] = new_map
	return new_map


# Deletes a  map by its ID and saves changes to disk
func delete_by_id(map_id: String) -> void:
	map_dict[map_id].delete()
	map_dict.erase(map_id)


# Returns a  map by its ID
func by_id(map_id: String) -> RMap:
	return map_dict[map_id]


# Checks if a  map exists by its ID
func has_id(map_id: String) -> bool:
	return map_dict.has(map_id)


# Returns the sprite of the  map
func sprite_by_id(map_id: String) -> Texture:
	return map_dict[map_id].sprite

# Returns the sprite by its file name
func sprite_by_file(spritefile: String) -> Texture:
	return sprites[spritefile]


# Returns a random map
func get_random_map() -> RMap:
	var map_ids = map_dict.keys()
	if map_ids.is_empty():
		return null
	var random_id = map_ids.pick_random()
	return map_dict[random_id]


# Function to get maps by category
func get_maps_by_category(category: String) -> Array[RMap]:
	var maplist: Array[RMap] = []
	for key in map_dict.keys():
		if map_dict[key].categories.has(category):
			maplist.append(map_dict[key])
	return maplist
