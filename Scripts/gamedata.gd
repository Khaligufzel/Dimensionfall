extends Node

var tile_materials = {} # Create an empty dictionary to store materials

# Called when the node enters the scene tree for the first time.
func _ready():
	load_tiles_material()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass



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
