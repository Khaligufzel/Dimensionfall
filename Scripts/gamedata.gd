extends Node

#This autoload singleton loads all game data required to run the game
#It can be accessed by using Gamedata.property

var tile_materials = {} # Materials used to represent tiles
var overmaptile_materials = {} # Materials used to represent overmap tiles
var all_map_files: Array = []

# Called when the node enters the scene tree for the first time.
func _ready():
	load_tiles_material()
	load_overmaptiles_material()
	all_map_files = Helper.json_helper.file_names_in_dir("./Mods/Core/Maps/", ["json"])



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
