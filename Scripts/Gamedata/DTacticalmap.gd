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
var parent: DTacticalmaps


# Initialize a tacticalmap
# newid: The id of the tacticalmap
# newdataPath: the path to the json file containing the tacticalmap
# For example: "/Mods/Core/Tacticalmaps/mytacticalmap.json
# myparent: The DTacticalmaps that initialized this tacticalmap
func _init(newid: String, newdataPath: String, myparent: DTacticalmaps):
	id = newid
	dataPath = newdataPath
	parent = myparent


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

# We remove ourselves from the filesystem and the parent maplist
# After this, the map is deleted from the current mod that the parent maplist is a part of
# If no copies of this map remain in any mod, we have to remove all references.
func delete():
	# Check to see if any mod has a copy of this map. if one or more remain, we can keep references
	# Otherwise, the last copy was removed and we need to remove references
	var all_results: Array = Gamedata.mods.get_all_content_by_id(DMod.ContentType.TACTICALMAPS, id)
	if all_results.size() > 0:
		return
	for chunk: TChunk in chunks:
		Gamedata.mods.remove_reference(DMod.ContentType.MAPS, chunk.id, DMod.ContentType.TACTICALMAPS, get_filename().replace(".json", ""))
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
	for newid in unique_new_ids:
		Gamedata.mods.add_reference(DMod.ContentType.MAPS, newid.replace(".json", ""), DMod.ContentType.TACTICALMAPS, tacticalmap_id.replace(".json", ""))

	# Remove references for IDs not present in new data
	for oldid in unique_old_ids:
		if oldid not in unique_new_ids:
			Gamedata.mods.remove_reference(DMod.ContentType.MAPS, oldid.replace(".json", ""), DMod.ContentType.TACTICALMAPS, tacticalmap_id.replace(".json", ""))


# Removes all chunks where the map_id matches the given chunk id
func remove_chunk_by_mapid(map_id: String) -> void:
	chunks = chunks.filter(func(chunk): 
		return not (chunk.has("id") and chunk.id == map_id)
	)
	save_data_to_disk()
