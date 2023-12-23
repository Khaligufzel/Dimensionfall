extends Node

#This autoload singleton loads all game data required to run the game
#It can be accessed by using Gamedata.property
var data: Dictionary = {}

# We write down the associated paths for the files to load
# Next, sprites are loaded from spritesPath into the .sprites property
# Finally, the data is loaded from dataPath into the .data property
# Maps tile sprites and map data are different so they 
# are loaded in using their respective functions
func _ready():
	data.tiles = {}
	data.mobs = {}
	data.overmaptiles = {}
	data.maps = {}
	data.tiles.dataPath = "./Mods/Core/Tiles/Tiles.json"
	data.tiles.spritePath = "./Mods/Core/Tiles/"
	data.mobs.dataPath = "./Mods/Core/Mobs/Mobs.json"
	data.mobs.spritePath = "./Mods/Core/Mobs/"
	data.overmaptiles.spritePath = "./Mods/Core/OvermapTiles/"
	data.maps.dataPath = "./Mods/Core/Maps/"
	load_sprites()
	load_tile_sprites()
	load_data()
	data.maps.data = Helper.json_helper.file_names_in_dir(data.maps.dataPath, ["json"])

#Loads json data. If no json file exists, it will create an empty array in a new file
func load_data() -> void:
	for dict in data.keys():
		if data[dict].has("dataPath"):
			var dataPath: String = data[dict].dataPath
			if FileAccess.file_exists(dataPath):
				Helper.json_helper.create_new_json_file(dataPath)
				data[dict].data = Helper.json_helper.load_json_array_file(dataPath)

#This loads all the sprites and assigns them to the proper dictionary
func load_sprites():
	for dict in data.keys():
		if data[dict].has("spritePath"):
			var loaded_sprites: Dictionary = {} # Materials used to represent mobs
			var spritesDir: String = data[dict].spritePath
			var png_files: Array = Helper.json_helper.file_names_in_dir(spritesDir, ["png"])
			for png_file in png_files:
				# Load the .png file as a texture
				var texture := load(spritesDir + png_file) 
				# Add the material to the dictionary
				loaded_sprites[png_file] = texture
			data[dict].sprites = loaded_sprites

# This function reads all the files in "res://Mods/Core/Tiles/". It will check if the file is a .png file. If the file is a .png file, it will create a new material with that .png image as the texture. It will put all of the created materials in a dictionary with the name of the file as the key and the material as the value.
func load_tile_sprites() -> void:
	var tile_materials: Dictionary = {} # Materials used to represent tiles
	var tilesDir = data.tiles.spritePath
	var png_files: Array = Helper.json_helper.file_names_in_dir(tilesDir, ["png"])
	for png_file in png_files:
		var texture := load(tilesDir + png_file) # Load the .png file as a texture
		var material := StandardMaterial3D.new() 
		material.albedo_texture = texture # Set the texture of the material
		material.uv1_scale = Vector3(3,2,1)
		tile_materials[png_file] = material # Add the material to the dictionary
	data.tiles.sprites = tile_materials

#This function will take two strings called ID and newID
#It will find an item with this ID in a json file specified by the source variable
#It will then duplicate that item into the json file and change the ID to newID
func duplicate_item_in_data(contentData: Dictionary, id: String, newID: String):
	if contentData.data.is_empty():
		return

	if data.dataPath.ends_with((".json")):
		# Check if an item with the given ID exists in the file.
		var item_index: int = get_array_index_by_id(contentData.data,id)
		if item_index == -1:
			return
		
		# Duplicate the found item recursively
		var item_to_duplicate = contentData.data[item_index].duplicate(true)
		
		# If there is no item to duplicate, return without doing anything.
		if item_to_duplicate == null:
			return
		# Change the ID of the duplicated item.
		item_to_duplicate["id"] = newID
		# Add the duplicated item to the JSON data.
		contentData.data.append(item_to_duplicate)
		Helper.json_helper.write_json_file(contentData.dataPath,JSON.stringify(contentData.data))
	else:
		print_debug("There should be code here for when a file in the gets duplicated")

# This function appends a new object to an existing array
# Pass the array to this function and the value of the ID
# If the data directory ends in .json, it will append an object
# The object that will be appended will be nothing more then {"id": id}
# if the data directory does not end in .json, a new file will be added
# This file will get the name as specified by id, so for example "myhouse"
# After the ID is added, the data array will be saved to disk
func add_id_to_data(contentData: Dictionary, id: String):
	if contentData.dataPath.ends_with((".json")):
		if get_array_index_by_id(contentData.data,id) != -1:
			print_debug("Tried to add an existing id to an array")
			return
		contentData.data.append({"id": id})
		save_data_to_file(contentData)
	else:
		if id in contentData.data:
			print_debug("Tried to add an existing file to a file array")
			return
		contentData.data.append(id)
		#Create a new json file in the directory with only {} in the file
		Helper.json_helper.create_new_json_file(contentData.dataPath + id + ".json", false)

# Will remove an item from the data
# If the first item in data is a dictionary, we remove an item that has the provided id
# If the first item in data is a string, we remove the string and the associated json file
func remove_item_from_data(contentData: Dictionary, id: String):
	if contentData.data.is_empty():
		return
	if contentData.data[0] is Dictionary:
		contentData.data.remove_at(get_array_index_by_id(contentData, id))
	elif contentData.data[0] is String:
		contentData.data.erase(id)
		Helper.json_helper.delete_json_file(contentData.dataPath, id)
	else:
		print_debug("Tried to remove item from data, but the data contains \
		neither Dictionary nor String")

func get_array_index_by_id(contentData: Dictionary, id: String) -> int:
	var myIndex: int = -1
	var i: int = 0
	for item in contentData.data:
		if item.get("id", "") == id:
			myIndex = i
			break
		i += 1
	return myIndex

func save_data_to_file(contentData: Dictionary):
	var datapath: String = contentData.dataPath
	if datapath.ends_with(".json"):
		Helper.json_helper.write_json_file(datapath,JSON.stringify(contentData.data,"\t"))

# This functino is called when an editor has changed data
# The contenteditor (that initializes the individual editors)
# connects the changed_data signal to this function
# and binds the appropriate data array so it can be saved in this function
func on_data_changed(contentData: Dictionary):
	save_data_to_file(contentData)
