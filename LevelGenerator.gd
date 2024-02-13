extends Node3D


var map_save_folder: String

var level_width : int = 32
var level_height : int = 32

@export var level_manager : Node3D
@export var chunkScene: PackedScene = null
@export_file var default_level_json


# Called when the node enters the scene tree for the first time.
func _ready():
	generate_map()
	$"../NavigationRegion3D".bake_navigation_mesh()
	
func generate_map():
	map_save_folder = Helper.save_helper.get_saved_map_folder(Helper.current_level_pos)
	generate_tactical_map()


# We generate a tactical map, which is made up of x by y maps of 32x32 blocks
# If we can find a saved map on the current coordinate, we load that
# Otherwise, we load the mapdata from the game data and make a brand new one
func generate_tactical_map():
	var tacticalMapJSON: Dictionary = {}
	var level_name: String = Helper.current_level_name
	# Load the default map from json
	# Unless the map_save_folder is set
	# In which case we load tha map instead
	if map_save_folder == "":
		tacticalMapJSON = Helper.json_helper.load_json_dictionary_file(\
		Gamedata.data.tacticalmaps.dataPath + level_name)
		var i: int = 0
		for z in range(tacticalMapJSON.mapheight):
			for x in range(tacticalMapJSON.mapwidth):
				var newChunk: Node3D = chunkScene.instantiate()
				level_manager.add_child(newChunk)
				newChunk.global_position.x = x * level_width
				newChunk.global_position.z = z * level_height
				newChunk.generate_chunk(tacticalMapJSON.chunks[i])
				i+=1
	else:
		tacticalMapJSON = Helper.json_helper.load_json_dictionary_file(\
		map_save_folder + "/map.json")
		for chunk in tacticalMapJSON.chunks:
			var newChunk: Node3D = chunkScene.instantiate()
			level_manager.add_child(newChunk)
			newChunk.generate_chunk(chunk)
