class_name DMaps
extends RefCounted

# There's a D in front of the class name to indicate this class only handles map data, nothing more
# This script is intended to be used inside the GameData autoload singleton
# This script handles the list of maps. You can access it trough Gamedata.mods.by_id("Core").maps

# Example references data:
#	"references": {
#		"field_grass_basic_00": {
#			"overmapareas": [
#				"city"
#			],
#			"tacticalmaps": [
#				"rockyhill"
#			]
#		}
#	}

var dataPath: String = "./Mods/Core/Maps/"
var mapdict: Dictionary = {}
var references: Dictionary = {}


# Load references from references.json during initialization
func _init(mod_id: String):
	dataPath = "./Mods/" + mod_id + "/Maps/"
	load_references()
	load_maps_from_disk()


# Load references from references.json
func load_references() -> void:
	var path = dataPath + "references.json"
	if FileAccess.file_exists(path):
		references = Helper.json_helper.load_json_dictionary_file(path)
	else:
		references = {}  # Initialize an empty references dictionary if the file doesn't exist


# Load all map data from disk into memory, excluding references.json
func load_maps_from_disk() -> void:
	var maplist: Array = Helper.json_helper.file_names_in_dir(dataPath, ["json"])
	for mapitem in maplist:
		if mapitem == "references.json":
			continue  # Skip references.json
		var mapid: String = mapitem.replace(".json", "")
		var map: DMap = DMap.new(mapid, dataPath, self)
		map.load_data_from_disk()
		mapdict[mapid] = map


func get_all() -> Dictionary:
	return mapdict


func duplicate_to_disk(mapid: String, newmapid: String) -> void:
	var newmap: DMap = DMap.new(newmapid, dataPath, self)
	var newdata: Dictionary = by_id(mapid).get_data().duplicate(true)
	# A duplicated map is brand new and can't already be referenced by something
	# So we delete the references from the duplicated data if it is present
	newdata.erase("references")
	newmap.set_data(newdata)
	newmap.save_data_to_disk()
	mapdict[newmapid] = newmap


func add_new(newid: String) -> void:
	var newmap: DMap = DMap.new(newid, dataPath, self)
	newmap.save_data_to_disk()
	mapdict[newid] = newmap
	

func delete_by_id(mapid: String) -> void:
	mapdict[mapid].delete()
	mapdict.erase(mapid)
	

func erase_id(mapid: String) -> void:
	mapdict.erase(mapid)


func by_id(mapid: String) -> DMap:
	return mapdict[mapid.replace(".json","")]


func has_id(mapid: String) -> bool:
	return mapdict.has(mapid.replace(".json",""))


# Returns the sprite of the map
func sprite_by_id(mapid: String) -> Texture:
	return by_id(mapid).sprite


# Loop over all maps and delete the entity from it. It will be removed from all levels and areas
# entity_type: "tile", "furniture", "mob", "itemgroup"
# entity_id: the id of the entity
func remove_entity_from_all_maps(entity_type: String, entity_id: String):
	remove_entity_from_selected_maps(entity_type, entity_id, mapdict.keys())


# Removes the entity from the maps provided in the maps array
# entity_type: "tile", "furniture", "mob", "itemgroup"
# entity_id: the id of the entity
# maps: An array of map id's (Strings)
func remove_entity_from_selected_maps(entity_type: String, entity_id: String, maps: Array):
	for map in maps:
		mapdict[map].remove_entity_from_map(entity_type, entity_id)


# Function to get maps by category
func get_maps_by_category(category: String) -> Array[DMap]:
	var maplist: Array[DMap] = []
	for key in mapdict.keys():
		if mapdict[key].categories.has(category):
			maplist.append(mapdict[key])
	return maplist


func is_map_in_category(mapid: String, category: String):
	return category in by_id(mapid).categories


# Function to check if a map is in any of the given categories
func is_map_in_any_category(mapid: String, categories: Array[String]) -> bool:
	var map_categories = by_id(mapid).categories
	
	# Check if any of the provided categories are in the map's categories
	for category in categories:
		if category in map_categories:
			return true

	return false  # Return false if none of the categories match


# Function to return unique categories across all maps
func get_unique_categories() -> Array:
	var unique_categories: Array = []  # Use an Array to store unique categories
	for map in mapdict.values():
		for category in map.categories:
			if not unique_categories.has(category):  # Check if category is already added
				unique_categories.append(category)  # Add only if it's unique
	return unique_categories  # Return the array of unique categories
