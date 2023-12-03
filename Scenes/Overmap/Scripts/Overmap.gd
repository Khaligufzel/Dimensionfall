extends Control

@export var positionLabel: Label = null
@export var tilesContainer: Control = null
@export var json_Helper_Class: GDScript = null
@export var overmapTile: PackedScene = null
@export var travelButton: Button = null
@export var overmapTileLabel: Label = null
var position_coord: Vector2 = Vector2(0, 0)
var last_position_coord: Vector2 = Vector2()
var tiles: Array = ["1.png", "arcstones1.png", "forestunderbrushscale5.png", "rockyfloor4.png"]
var chunks: Dictionary = {} #Stores references to tilegrids representing the map
var noise = FastNoiseLite.new()
var chunk_width: int = 32
var chunk_size = 32
var tile_size = 32
var grid_pixel_size = chunk_size*tile_size
var tile_materials = {}
var all_map_files: Array = []

func _ready():
	load_tiles_material()
	#Remember the list of map files
	all_map_files = json_Helper_Class.new().file_names_in_dir("./Mods/Core/Maps/", ["json"])
	noise.seed = randi()
	noise.fractal_octaves = 5
	noise.fractal_gain = 0.5
	noise.frequency = 0.04
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX

	update_chunks()
	connect("position_coord_changed", on_position_coord_changed)

# This function updates the chunks.
# It loops through a 4x4 grid centered on the current position
# generating new chunks at each position if they don't already exist. 
# After generating any necessary new chunks, it calls `unload_chunks()`
# to unload any chunks that are no longer needed. The
# `chunk_size` variable determines the size of each chunk,
# and `position_coord` is the current position in the world
func update_chunks():
	# Convert the current position to grid coordinates based on the grid's pixel size
	var grid_position = (position_coord / grid_pixel_size).floor() * grid_pixel_size
	#The position is increase arbitrarily so it is more center of screen
	grid_position.x += grid_pixel_size
	grid_position.y += grid_pixel_size

	for x in range(-1, 1):
		for y in range(-1, 1):
			var chunk_grid_position = grid_position + Vector2(x, y) * grid_pixel_size

			if not chunks.has(chunk_grid_position):
				generate_chunk(chunk_grid_position)
				# Retrieve the chunk data for the specific position.
				var chunk_data = chunks[chunk_grid_position]  
				# Use chunk data to create and fill the GridContainer.
				var localized_x: float = chunk_grid_position.x-position_coord.x
				var localized_y: float = chunk_grid_position.y-position_coord.y
				var new_grid_container = create_and_fill_grid_container(chunk_data,\
				Vector2(localized_x,localized_y))
				tilesContainer.call_deferred("add_child",new_grid_container)
#				tilesContainer.add_child(new_grid_container)
				# Store the GridContainer using the grid position as the key.
				chunks[chunk_grid_position] = new_grid_container

	# After generating new chunks, you may want to unload any that are off-screen.
	unload_chunks()


func generate_chunk(grid_position: Vector2):
	var chunk = []
	for y in range(chunk_size):  # x goes from 0 to chunk_size - 1
		for x in range(chunk_size):  # y goes from 0 to chunk_size - 1
			# We calculate global coordinates by 
			# offsetting the local coordinates by the grid_position
			var global_x = x + grid_position.x / tile_size
			var global_y = y + grid_position.y / tile_size
			var noise_value = noise.get_noise_2d(global_x, global_y)
			# Scale noise_value to a valid index in the tiles array
			# Ensure noise_value is scaled correctly based on the number of tiles.
			var tile_index = int((noise_value + 1) / 2 * tiles.size()) % tiles.size()
			chunk.append(tiles[tile_index])
	# Store the chunk using the grid_position as the key.
	chunks[grid_position] = chunk

# The user will leave chunks behind as the map is panned around
# Chunks that are too far from the current position will be destoroyed
func unload_chunks():
	var dist = 0
	var rangeLimit = 0
	for chunk_position in chunks.keys():
		dist = chunk_position.distance_to(position_coord)
		#Lowering this number 5 will cause newly created chunks 
		#to be instantly deleted and recreated
		rangeLimit = 3 * grid_pixel_size
		if dist > rangeLimit:
			chunks[chunk_position].call_deferred("queue_free")
			chunks.erase(chunk_position)


var mouse_button_pressed: bool = false
#We will emit this signal when the position_coords change
signal position_coord_changed(delta)
func _input(event):
	if !visible:
		return
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_MIDDLE: 
				mouse_button_pressed = event.is_pressed()

	if event is InputEventMouseMotion and mouse_button_pressed:
		# Adjust the position based on the mouse movement, divided by 100 for sensitivity.
		var motion = event.relative / 2
		# Calculate the new position first.
		var new_position_coord = position_coord - motion
		# Round the new_position_coord to the nearest integer.
		new_position_coord = new_position_coord.round()
		# Calculate the delta based on the old and the rounded new positions.
		var delta = new_position_coord - position_coord
		if delta != Vector2.ZERO:
			# Update position_coord to the new rounded position.
			position_coord = new_position_coord
			# Emit the signal to update other parts of the game that depend on the position.
			emit_signal("position_coord_changed", delta)
			# Update last_position_coord for the next input event.
			last_position_coord = position_coord


#This function will move all the tilegrids on screen when the position_coords change
#This will make it look like the user pans across the map
func update_tiles_position(delta):
	for grid_container in tilesContainer.get_children():
		# Update the grid container's position by subtracting the delta
		grid_container.position -= delta

#We will call this function when the position_coords change
func on_position_coord_changed(delta):
	update_tiles_position(delta)
	update_chunks()
	if positionLabel:
		positionLabel.text = "Position: " + str(position_coord)
		
		
func create_and_fill_grid_container(chunk: Array, chunk_position: Vector2):
	var grid_container = GridContainer.new()
	grid_container.columns = chunk_width  # Set the number of columns to chunk_width.
	#Make sure there is no space between the tiles
	grid_container.set("theme_override_constants/h_separation", 0)
	grid_container.set("theme_override_constants/v_separation", 0)

	# Iterate over the chunk array to create and add TextureRects for each tile.
	for i in range(chunk.size()):
		var tile_type = chunk[i]
		var texture = tile_materials[tile_type] # Retrieve the texture based on the tile type.
		var tile = overmapTile.instantiate()
#		var tile = TextureRect.new()
		assign_map_to_tile(tile)
		tile.set_texture(texture)
		tile.connect("tile_clicked", _on_tile_clicked)
		grid_container.call_deferred("add_child",tile)

	# Set the position of the grid container in pixel space.
	grid_container.position = chunk_position

	# Return the filled grid container.
	return grid_container


# This function reads all the files in "res://Mods/Core/OvermapTiles/". It will check if the file is a .png file. If the file is a .png file, it will create a new material with that .png image as the texture. It will put all of the created materials in a dictionary with the name of the file as the key and the material as the value.
func load_tiles_material():
	var tilesDir = "res://Mods/Core/OvermapTiles/"	
	var dir = DirAccess.open(tilesDir)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			var extension = file_name.get_extension()
			if !dir.current_is_dir():
				if extension == "png":
					# Load the .png file as a texture
					var texture := load("res://Mods/Core/OvermapTiles/" + file_name) 
					tile_materials[file_name] = texture # Add the material to the dictionary
			file_name = dir.get_next()
	else:
		print_debug("An error occurred when trying to access the path.")
	dir.list_dir_end()


#This function takes a TextureRect as an argument
#For a chance of 1 in 100, it will modulate the TextureRect to be slightly red
#And it will write a random item from the all_map_files array to it's metadata
#Then it will make sure that when a user clicks on this slightly red tile, 
#It will print the item from it's metadata
func assign_map_to_tile(tile: Control):
	var chance = randi_range(0, 100)
	if chance < 1:
		tile.set_color(Color(1, 0.8, 0.8))  # Make the tile slightly red
		var random_index = randi() % all_map_files.size()
		var random_file = all_map_files[random_index]
		tile.set_meta("map_file", random_file)  # Set the metadata of the tile

#This function will be connected to the signal of the tiles
func _on_tile_clicked(clicked_tile):
	if clicked_tile.has_meta("map_file"):
		var mapFile = clicked_tile.get_meta("map_file")
		var textureString: String = clicked_tile.tileData.texture
		var nameString: String = "Name: " + mapFile
		var envString: String = clicked_tile.tileData.texture
		envString = envString.replace("res://Mods/Core/OvermapTiles/","")
		envString = "\nEnvironment: " + envString
		var challengeString: String = "\nChallenge: Easy"
		overmapTileLabel.text = nameString + envString + challengeString
		Helper.current_level_name = mapFile
		travelButton.disabled = false
	else: 
		travelButton.disabled = true
		overmapTileLabel.text = "Select a valid target"


func _on_travel_button_button_up():
	get_tree().change_scene_to_file("res://level_generation.tscn")
