extends Node3D

var level_name



var level_json_as_text

var level_levels : Array

var level_width : int = 32
var level_height : int = 32


@onready var defaultBlock: PackedScene = preload("res://Blocks/grass_001.tscn")
@export var level_manager : Node3D
@export var block_scenes : Array[PackedScene]
@export_file var default_level_json
var tile_materials = {} # Create an empty dictionary to store materials



# Called when the node enters the scene tree for the first time.
func _ready():
	level_name = Helper.current_level_name
	load_tiles_material()
	generate_level()
	$"../NavigationRegion3D".bake_navigation_mesh()
	
func generate_level():
	
	var textureName: String = ""
	if level_name == "":
		get_level_json()
	else:
		get_custom_level_json("./Mods/Core/Maps/" + level_name)
	
	
	var level_number = 0
	#we need to generate level layer by layer starting from the bottom
	for level in level_levels:
		if level != []:
			var level_node = Node3D.new()
			level_manager.add_child(level_node)
			level_node.global_position.y = level_number-10
			
			
			var current_block = 0
			
			# we will generate number equal to "layer_height" of horizontal rows of blocks
			for h in level_height:
				
				# this loop will generate blocks from West to East based on the tile number
				# in json file

				
				for w in level_width:
					
					# checking if we have tile from json in our block array containing packedscenes
					# of blocks that we need to instantiate.
					# If yes, then instantiate
					
#					if block_scenes[level["data"][current_block]-1]:
					if level[current_block]:
						textureName = level[current_block].texture
						if textureName != "":
#							var block : StaticBody3D
##							block = block_scenes[0].instantiate()
#							block = create_block_with_material(textureName)
													
							var block: StaticBody3D = defaultBlock.instantiate()
							if textureName in tile_materials:
								var material = tile_materials[textureName]
								block.update_texture(material)
	#						block = block_scenes[layer["data"][current_block]-1].instantiate()
							level_node.add_child(block)
							
							block.global_position.x = w
							#block.global_position.y = layer_number
							block.global_position.z = h
					current_block += 1
				
		level_number += 1
		
	

	
	# YEAH I KNOW THAT SHOULD BE ONE FUNCTION, BUT IT'S 2:30 AM and... I'm TIRED LOL
func get_level_json():
	var file = default_level_json
	level_json_as_text = FileAccess.get_file_as_string(file)
	var json_as_dict: Dictionary = JSON.parse_string(level_json_as_text)
	level_levels = json_as_dict["levels"]
	level_width = json_as_dict["mapwidth"]
	level_width = json_as_dict["mapheight"]

func get_custom_level_json(level_path):
	var file = level_path
	level_json_as_text = FileAccess.get_file_as_string(file)
	var json_as_dict = JSON.parse_string(level_json_as_text)
	level_levels = json_as_dict["levels"]


#This function takes a filename and create a new instance of block_scenes[0] which is a StaticBody3D. It will then take the material from the material dictionary based on the provided filename and apply it to the instance of StaticBody3D. Lastly it will return the StaticBody3D.
func create_block_with_material(filename: String) -> StaticBody3D:
	var block: StaticBody3D = defaultBlock.instantiate()
	if filename in tile_materials:
		var material = tile_materials[filename]
		block.update_texture(material)
	return block


# This function reads all the files in "res://Mods/Core/Tiles/". It will check if the file is a .png file. If the file is a .png file, it will create a new material with that .png image as the texture. It will put all of the created materials in a dictionary with the name of the file as the key and the material as the value.
func load_tiles_material():
	var tilesDir = "res://Mods/Core/Tiles/"	
	var dir = DirAccess.open(tilesDir)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			var extension = file_name.get_extension()

			if !dir.current_is_dir():
				if extension == "png":
					var texture := load("res://Mods/Core/Tiles/" + file_name) # Load the .png file as a texture
					var material := StandardMaterial3D.new() 
					material.albedo_texture = texture # Set the texture of the material
					material.uv1_scale = Vector3(3,2,1)
					tile_materials[file_name] = material # Add the material to the dictionary
			file_name = dir.get_next()
	else:
		print_debug("An error occurred when trying to access the path.")
	dir.list_dir_end()
