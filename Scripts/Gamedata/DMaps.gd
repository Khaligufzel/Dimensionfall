class_name DMaps
extends RefCounted

# There's a D in front of the class name to indicate this class only handles map data, nothing more
# This script is intended to be used inside the GameData autoload singleton
# This script handles the list of maps. You can access it trough Gamedata.maps

var dataPath: String = "./Mods/Core/Maps/"
var mapdict: Dictionary = {}


func _init():
	load_maps_from_disk()

# Load all mapdata from disk into memory
func load_maps_from_disk() -> void:
	var maplist: Array = Helper.json_helper.file_names_in_dir(dataPath, ["json"])
	for mapitem in maplist:
		var map: DMap = DMap.new(mapitem, dataPath)
		map.load_data_from_disk()
		mapdict[mapitem] = map


func get_maps() -> Dictionary:
	return mapdict
