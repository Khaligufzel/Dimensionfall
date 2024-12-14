class_name DTacticalmaps
extends RefCounted

# There's a D in front of the class name to indicate this class only handles tactical map data, nothing more
# This script is intended to be used inside the GameData autoload singleton
# This script handles the list of tactical maps. You can access it through Gamedata.mods.by_id(mod_id).tacticalmaps

var dataPath: String = "./Mods/Core/TacticalMaps/"
var mapdict: Dictionary = {}
var mod_id: String = "Core"

func _init(new_mod_id: String):
	mod_id = new_mod_id
	# Update dataPath using the provided mod_id
	dataPath = "./Mods/" + mod_id + "/TacticalMaps/"
	load_maps_from_disk()

# Load all tactical map data from disk into memory
func load_maps_from_disk() -> void:
	var maplist: Array = Helper.json_helper.file_names_in_dir(dataPath, ["json"])
	for mapitem in maplist:
		var mapid: String = mapitem.replace(".json", "")
		var map: DTacticalmap = DTacticalmap.new(mapid, dataPath, self)
		map.load_data_from_disk()
		mapdict[mapid] = map

func get_all() -> Dictionary:
	return mapdict

func duplicate_to_disk(mapid: String, newmapid: String, new_mod_id: String) -> void:
	if new_mod_id != mod_id:
		# Access the DTacticalmaps instance for the target mod
		var other_maps: DTacticalmaps = Gamedata.mods.by_id(new_mod_id).tacticalmaps

		# Add a new tacticalmap to the target mod
		var newmap: DTacticalmap = other_maps.add_new(newmapid)

		# Duplicate the data from the current map and set it in the new map
		var newdata: Dictionary = mapdict[mapid].get_data().duplicate(true)
		newmap.set_data(newdata)
		newmap.save_data_to_disk()
		return  # Exit if mod IDs don't match

	# Proceed with duplication if mod IDs are equal
	var newmap: DTacticalmap = DTacticalmap.new(newmapid, dataPath, self)
	newmap.set_data(mapdict[mapid].get_data().duplicate(true))
	newmap.save_data_to_disk()
	mapdict[newmapid] = newmap


func add_new(newid: String) -> DTacticalmap:
	var newmap: DTacticalmap = DTacticalmap.new(newid, dataPath, self)
	newmap.save_data_to_disk()
	mapdict[newid] = newmap
	return newmap

func delete_by_id(mapid: String) -> void:
	mapdict[mapid].delete()
	mapdict.erase(mapid)

func by_id(mapid: String) -> DTacticalmap:
	return mapdict[mapid]

func has_id(mapid: String) -> bool:
	return mapdict.has(mapid)

# Returns a random map
func get_random_map() -> DTacticalmap:
	var map_ids = mapdict.keys()
	if map_ids.is_empty():
		return null
	var random_id = map_ids[randi() % map_ids.size()]
	return mapdict[random_id]
