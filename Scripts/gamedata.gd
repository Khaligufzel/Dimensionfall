extends Node

#This autoload singleton loads all game data required to run the game
#It can be accessed by using Gamedata.property

var tile_materials: Dictionary = {} # Materials used to represent tiles
var all_tiles: Array = [] # All data describing tiles
var overmaptile_materials: Dictionary = {} # Materials used to represent overmap tiles
var mob_materials: Dictionary = {} # Materials used to represent mobs
var all_mobs: Array = [] # All data describing mobs
var all_map_files: Array = []

# Called when the node enters the scene tree for the first time.
func _ready():
	load_tiles_material()
	load_overmaptiles_material()
	load_mobs_material()
	load_mob_data()
	load_tile_data()
	all_map_files = Helper.json_helper.file_names_in_dir("./Mods/Core/Maps/", ["json"])

#Loads mob json data. If no json file exists, it will create an empty array in a new file
func load_mob_data():
	var mob_dir: String = "./Mods/Core/Mobs/Mobs.json"
	Helper.json_helper.create_new_json_file(mob_dir)
	all_mobs = Helper.json_helper.load_json_array_file(mob_dir)
	
#Loads tile json data. If no json file exists, it will create an empty array in a new file
func load_tile_data():
	var tile_dir: String = "./Mods/Core/Tiles/Tiles.json"
	Helper.json_helper.create_new_json_file(tile_dir)
	all_tiles = Helper.json_helper.load_json_array_file(tile_dir)
	

# This function reads all the files in "res://Mods/Core/Tiles/". It will check if the file is a .png file. If the file is a .png file, it will create a new material with that .png image as the texture. It will put all of the created materials in a dictionary with the name of the file as the key and the material as the value.
func load_mobs_material():
	var mobsDir = "./Mods/Core/Mobs/"	
	var png_files: Array = Helper.json_helper.file_names_in_dir(mobsDir, ["png"])
	for png_file in png_files:
		# Load the .png file as a texture
		var texture := load(mobsDir + png_file) 
		# Add the material to the dictionary
		mob_materials[png_file] = texture
		

# This function reads all the files in "res://Mods/Core/Tiles/". It will check if the file is a .png file. If the file is a .png file, it will create a new material with that .png image as the texture. It will put all of the created materials in a dictionary with the name of the file as the key and the material as the value.
func load_tiles_material():
	var tilesDir = "./Mods/Core/Tiles/"	
	var png_files: Array = Helper.json_helper.file_names_in_dir(tilesDir, ["png"])
	for png_file in png_files:
		var texture := load(tilesDir + png_file) # Load the .png file as a texture
		var material := StandardMaterial3D.new() 
		material.albedo_texture = texture # Set the texture of the material
		material.uv1_scale = Vector3(3,2,1)
		tile_materials[png_file] = material # Add the material to the dictionary


# This function reads all the files in "res://Mods/Core/OvermapTiles/". It will check if the file is a .png file. If the file is a .png file, it will create a new material with that .png image as the texture. It will put all of the created materials in a dictionary with the name of the file as the key and the material as the value.
func load_overmaptiles_material():
	var tilesDir = "./Mods/Core/OvermapTiles/"
	var png_files: Array = Helper.json_helper.file_names_in_dir(tilesDir, ["png"])
	for png_file in png_files:
		# Load the .png file as a texture
		var texture := load(tilesDir + png_file) 
		# Add the material to the dictionary
		overmaptile_materials[png_file] = texture
		

#This function will take two strings called ID and newID
#It will find an item with this ID in a json file specified by the source variable
#It will then duplicate that item into the json file and change the ID to newID
func duplicate_item_in_data(data: Array, id: String, newID: String):
	# If the first item is a string, assume all items are strings and do nothing
	if data[0] is String:
		return
		
	# Check if an item with the given ID exists in the file.
	var item_index: int = get_array_index_by_id(data,id)
	if item_index == -1:
		return
	
	# Duplicate the found item recursively
	var item_to_duplicate = data[item_index].duplicate(true)
	
	# If there is no item to duplicate, return without doing anything.
	if item_to_duplicate == null:
		return
	# Change the ID of the duplicated item.
	item_to_duplicate["id"] = newID
	# Add the duplicated item to the JSON data.
	data.append(item_to_duplicate)
	Helper.json_helper.write_json_file(get_data_directory(data),JSON.stringify(data))


#This function appends a new object to an existing array
#Pass the array to this function and the value of the ID
#The object that will be appended will be nothing more then {"id": id}
#After the ID is added, the data array will be saved to disk
func add_id_to_data(data: Array, id: String):
	if get_array_index_by_id(data,id) != -1:
		print_debug("Tried to add an existing id to an array")
		return
	data.append({"id": id})
	Helper.json_helper.write_json_file(get_data_directory(data),JSON.stringify(data))
	
#This function appends a new filename to an existing array
#Pass the array to this function and the value of the filename
#The string that will be appended will be nothing more then the file name
#After the filename is added, the file will be saved to disk
func add_file_to_data(data: Array, fileName: String):
	if fileName in data:
		print_debug("Tried to add an existing file to a file array")
		return
	data.append(fileName)
	#Create a new json file in the directory with only {} in the file
	Helper.json_helper.create_new_json_file(get_data_directory(data) + fileName, false)

# Will remove an item from the data
# If the first item in data is a dictionary, we remove an item that has the provided id
# If the first item in data is a string, we remove the string and the associated json file
func remove_item_from_data(data: Array, id: String):
	if data[0] is Dictionary:
		data.remove_at(get_array_index_by_id(data, id))
	elif data[0] is String:
		data.erase(id)
		Helper.json_helper.delete_json_file(get_data_directory(data), id)
	else:
		print_debug("Tried to remove item from data, but the data contains \
		neither Dictionary nor String")

func get_data_directory(data: Array) -> String:
	if data == all_tiles:
		return "./Mods/Core/Tiles/Tiles.json"
	if data == all_mobs:
		return "./Mods/Core/Mobs/Mobs.json"
	if data == all_map_files:
		return "./Mods/Core/Maps/"
	return ""

func get_array_index_by_id(data: Array, id: String) -> int:
	var myIndex: int = -1
	var i: int = 0
	for item in data:
		if item.get("id", "") == id:
			myIndex = i
			break
		i += 1
	return myIndex
	
