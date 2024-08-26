class_name DTacticalmap
extends RefCounted

# This class represents a tactical map with its properties
# Example tactical map data:
# {
#   "chunks": [
#       {"id": "field_grass_basic_00.json"},
#       {"id": "urbanroad_corner.json", "rotation": 180},
#       ...
#   ],
#   "mapheight": 6,
#   "mapwidth": 6
# }

# Subclass to represent individual chunks in the tactical map
class TChunk:
	var id: String = ""
	var rotation: int = 0

	func _init(data: Dictionary):
		id = data.get("id", "")
		rotation = data.get("rotation", 0)

	func get_data() -> Dictionary:
		var data: Dictionary = {"id": id}
		if not rotation == 0:
			data["rotation"] = rotation
		return data


# Properties defined in the tactical map
var id: String = "": # id is the filename without json
	set(newid):
		id = newid.replace(".json", "") # In case the filename is passed, we remove json
var mapwidth: int = 6
var mapheight: int = 6
var chunks: Array[TChunk] = []
var dataPath: String


func _init(newid: String, newdataPath: String):
	id = newid
	dataPath = newdataPath


# Constructor to initialize tactical map properties from a dictionary
func set_data(newdata: Dictionary):
	mapwidth = newdata.get("mapwidth", 6)
	mapheight = newdata.get("mapheight", 6)

	var chunk_data = newdata.get("chunks", [])
	for chunk in chunk_data:
		chunks.append(TChunk.new(chunk))

# Get data function to return a dictionary with all properties
func get_data() -> Dictionary:
	var chunk_data = []
	for chunk in chunks:
		chunk_data.append(chunk.get_data())

	return {
		"mapwidth": mapwidth,
		"mapheight": mapheight,
		"chunks": chunk_data
	}

func load_data_from_disk():
	set_data(Helper.json_helper.load_json_dictionary_file(get_file_path()))

func save_data_to_disk() -> void:
	var map_data_json = JSON.stringify(get_data().duplicate(), "\t")
	Helper.json_helper.write_json_file(get_file_path(), map_data_json)

func get_filename() -> String:
	return id + ".json"
	
func get_file_path() -> String:
	return dataPath + get_filename()

# A tacticalmap is being deleted. Remove all references to this tacticalmap
func delete(tacticalmap_id: String):
	for chunk: TChunk in chunks:
		Gamedata.maps.remove_reference_from_map(chunk.id,"core", "tacticalmaps",get_filename())
	Helper.json_helper.delete_json_file(get_file_path())

func changed(olddata: DTacticalmap):
	# Collect unique IDs from the old data
	var unique_old_ids: Array = []
	var ids_dict_old: Dictionary = {}
	for old_chunk in olddata.chunks:
		ids_dict_old[old_chunk.id] = true
	unique_old_ids = ids_dict_old.keys()

	# Collect unique IDs from the new data (current instance)
	var unique_new_ids: Array = []
	var ids_dict_new: Dictionary = {}
	for new_chunk in chunks:
		ids_dict_new[new_chunk.id] = true
	unique_new_ids = ids_dict_new.keys()

	# Get the tactical map file name for reference management
	var tacticalmap_id = get_filename()

	# Add references for new IDs
	for id in unique_new_ids:
		Gamedata.maps.add_reference_to_map(id, "core", "tacticalmaps", tacticalmap_id)

	# Remove references for IDs not present in new data
	for id in unique_old_ids:
		if id not in unique_new_ids:
			Gamedata.maps.remove_reference_from_map(id, "core", "tacticalmaps", tacticalmap_id)


# Removes all chunks where the map_id matches the given chunk id
func remove_chunk_by_mapid(map_id: String) -> void:
	chunks = chunks.filter(func(chunk): 
		return not (chunk.has("id") and chunk.id == map_id)
	)
	save_data_to_disk()
