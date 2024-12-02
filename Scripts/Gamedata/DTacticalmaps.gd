class_name DTacticalmaps
extends RefCounted

# There's a D in front of the class name to indicate this class only handles tactical map data, nothing more
# This script is intended to be used inside the GameData autoload singleton
# This script handles the list of tactical maps. You can access it through Gamedata.mods.by_id(mod_id).tacticalmaps

var dataPath: String = "./Mods/Core/TacticalMaps/"
var mapdict: Dictionary = {}

func _init(mod_id: String):
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

func duplicate_to_disk(mapid: String, newmapid: String) -> void:
	var newmap: DTacticalmap = DTacticalmap.new(newmapid, dataPath, self)
	newmap.set_data(mapdict[mapid].get_data().duplicate(true))
	newmap.save_data_to_disk()
	mapdict[newmapid] = newmap

func add_new(newid: String) -> void:
	var newmap: DTacticalmap = DTacticalmap.new(newid, dataPath, self)
	newmap.save_data_to_disk()
	mapdict[newid] = newmap

func delete_by_id(mapid: String) -> void:
	mapdict[mapid].delete()
	mapdict.erase(mapid)

func by_id(mapid: String) -> DTacticalmap:
	return mapdict[mapid]

# Returns a random map
func get_random_map() -> DTacticalmap:
	var map_ids = mapdict.keys()
	if map_ids.is_empty():
		return null
	var random_id = map_ids[randi() % map_ids.size()]
	return mapdict[random_id]
