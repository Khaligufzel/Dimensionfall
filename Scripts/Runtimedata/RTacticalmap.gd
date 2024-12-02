class_name RTacticalmap
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
var id: String = "": # ID is the filename without `.json`
	set(newid):
		id = newid.replace(".json", "") # Removes `.json` if the filename is passed
var mapwidth: int = 6
var mapheight: int = 6
var chunks: Array[TChunk] = []
var dataPath: String = ""
var parent: RTacticalmaps

# Constructor to initialize the tactical map with an ID and data path
func _init(myparent: RTacticalmaps, newid: String, newdataPath: String):
	id = newid
	dataPath = newdataPath
	parent = myparent

func overwrite_from_dtacticalmap(dtacticalmap: DTacticalmap) -> void:
	if not id == dtacticalmap.id:
		print_debug("Cannot overwrite from a different id")
		return
	
	# Update basic properties
	mapwidth = dtacticalmap.mapwidth
	mapheight = dtacticalmap.mapheight
	dataPath = dtacticalmap.dataPath

	# Clear existing chunks
	chunks.clear()

	# Loop through dtacticalmap.chunks and create new TChunk instances
	for chunk_data in dtacticalmap.chunks:
		var new_chunk = TChunk.new(chunk_data.get_data())
		chunks.append(new_chunk)
