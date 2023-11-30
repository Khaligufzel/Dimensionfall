extends Control

@export var positionLabel: Label = null
@export var tilesContainer: Control = null
var position_coord: Vector2 = Vector2(0, 0)
var last_position_coord: Vector2 = Vector2()
var tiles: Array = ["1.png", "arcstones1.png", "forestunderbrushscale5.png", "rockyfloor4.png"]
var chunks: Dictionary = {}
var noise = FastNoiseLite.new()
var chunk_height: int = 32
var chunk_width: int = 32
var chunk_size = 32
var tile_size = 32
var grid_pixel_size = chunk_size*tile_size
var loaded_tiles: Array = []
var tile_materials = {} # Create an empty dictionary to store materials

#We will connect the position_coord to this function in the _ready function
func _ready():
#	position_coord = positionLabel.position
	load_tiles_material()
#	noise.seed = randi()
#	noise.fractal_octaves = 3
	
	
#	noise.seed = 2147483646
	noise.seed = randi() % 2147483646
#	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.fractal_octaves = 5
	noise.fractal_gain = 0.5
	noise.frequency = 0.04
#	noise.frequency = 0.02
#	noise.noise_type = noise.TYPE_CELLULAR
#	noise.domain_warp_amplitude = 20.0
#	noise.fractal_gain = 0.5
	update_chunks()
	connect("position_coord_changed", on_position_coord_changed)
#	draw_all_chunks()

# The GDScript function `update_chunks()` updates the
# chunks in a 2D game world. It loops through a 4x4 grid
# centered on the current position, generating new chunks
# at each position if they don't already exist. After
# generating any necessary new chunks, it calls `unload_chunks()`
# to unload any chunks that are no longer needed. The
# `chunk_size` variable determines the size of each chunk,
# and `position_coord` is the current position in the
# game world.
func update_chunks():
	# Convert the current camera or player position to grid coordinates based on the grid's pixel size (chunk size).
	var grid_position = (position_coord / grid_pixel_size).floor() * grid_pixel_size
	grid_position.x += grid_pixel_size+grid_pixel_size
	grid_position.y += grid_pixel_size+grid_pixel_size

	for x in range(-2, 2):  # Adjust the range based on how large you want the active area to be.
		for y in range(-2, 2):
			var chunk_grid_position = grid_position + Vector2(x, y) * grid_pixel_size
			# Key used to store and look up the GridContainers within the chunks dictionary.
			var key = chunk_grid_position
#			var key = str(chunk_grid_position.x) + "," + str(chunk_grid_position.y)

			if not chunks.has(key):
				generate_chunk(chunk_grid_position)
				# Within context of where you handle chunk generation or updating:
				var chunk_data = chunks[chunk_grid_position]  # Retrieve the chunk data for the specific position.
				# Use chunk data to create and fill the GridContainer.
				var new_grid_container = create_and_fill_grid_container(chunk_data, Vector2(chunk_grid_position.x-position_coord.x,chunk_grid_position.y-position_coord.y))
				tilesContainer.add_child(new_grid_container)
				# Store the GridContainer using the grid position as the key.
				chunks[key] = new_grid_container

	# After generating new chunks, you may want to unload any that are off-screen.
	unload_chunks()
#
#func update_chunks():
#	var grid_position_coord = position_coord.snapped(Vector2(grid_pixel_size, grid_pixel_size))
#	var current_chunk_pos = grid_position_coord
#
#	for x in range(-2, 2):
#		for y in range(-2, 2):
#			var chunk_position = current_chunk_pos# + Vector2(x*grid_pixel_size, y*grid_pixel_size)
#			var world_chunk_position = chunk_position
##			var world_chunk_position = chunk_position * chunk_size * tile_size
##			var world_chunk_position = Vector2(grid_pixel_size*x, grid_pixel_size*y)
#			var chunk_has_position: bool = chunks.has(world_chunk_position)
#			if not chunk_has_position:
#				generate_chunk(world_chunk_position)
#				# Within context of where you handle chunk generation or updating:
#				var chunk_data = chunks[chunk_position]  # Retrieve the chunk data for the specific position.
#				var grid_container = create_and_fill_grid_container(chunk_data, chunk_position)
#				tilesContainer.add_child(grid_container)  # Assuming tilesContainer is already added to the scene tree.
##				draw_chunk(world_chunk_position, chunks[world_chunk_position])
#	unload_chunks()


func generate_chunk(grid_position: Vector2):
	var chunk = []
	for y in range(chunk_size):  # x goes from 0 to chunk_size - 1
		for x in range(chunk_size):  # y goes from 0 to chunk_size - 1
			# We calculate global coordinates by offsetting the local coordinates by the grid_position (which is in 'chunk units')
#			var global_x = chunk_size + x + 0
#			var global_y = chunk_size + y + 16
			var global_x = x + grid_position.x / tile_size
			var global_y = y + grid_position.y / tile_size
#			var global_x = grid_position.x / tile_size + x
#			var global_y = grid_position.y / tile_size + y
#			var global_x = grid_position.x * chunk_size + x
#			var global_y = grid_position.y * chunk_size + y
			var noise_value = noise.get_noise_2d(global_x, global_y)
			if x == 0 and y == 0:
				print_debug("Global_x = ("+str(global_x)+"), global_y = ("+str(global_y)+"), noise_value = ("+str(noise_value)+"), grid_position = ("+str(grid_position)+")")
			if x == 31 and y == 31:
				print_debug("Global_x = ("+str(global_x)+"), global_y = ("+str(global_y)+"), noise_value = ("+str(noise_value)+"), grid_position = ("+str(grid_position)+")")
			# Scale noise_value to a valid index in the tiles array
			# Ensure noise_value is scaled correctly based on the number of tiles.
			var tile_index
			if noise_value < -0.5:
				tile_index = 0
			elif noise_value >-0.5 and noise_value <0:
				tile_index = 1
			elif noise_value >0 and noise_value <0.5:
				tile_index = 2
			elif noise_value >0.5:
				tile_index = 3
#			var tile_index = int((noise_value + 1) / 2 * tiles.size()) % tiles.size()
			chunk.append(tiles[tile_index])
	# Store the chunk using the grid_position as the key.
	chunks[grid_position] = chunk
#
#func generate_chunk(position_loc: Vector2):
#	var chunk = []
#	for x in range(position_loc.x, position_loc.x + chunk_size):
#		for y in range(position_loc.y, position_loc.y + chunk_size):
#			var tile_type = noise.get_noise_2d(x, y)
##			var tile_type = noise.get_noise_2d(position_loc.x + x, position_loc.y + y)
#			tile_type = int((tile_type + 1) / 2 * tiles.size())
#			chunk.append(tiles[tile_type])
#	chunks[position_loc] = chunk

func unload_chunks():
	var dist = 0
	var range = 0
	for chunk_position in chunks.keys():
		dist = chunk_position.distance_to(position_coord)
		#Lowering this number 5 will cause newly created chunks 
		#to be instantly deleted and recreated
		range = 5 * grid_pixel_size
		if dist > range:
			chunks[chunk_position].queue_free()
			chunks.erase(chunk_position)

var mouse_button_pressed: bool = false

#We will emit this signal when the position_coords change
signal position_coord_changed(delta)


func _input(event):
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

			# Call update_tiles_position to move the tiles on the screen.
#			update_tiles_position(delta)

			# Update last_position_coord for the next input event.
			last_position_coord = position_coord

			# Update the chunks based on the new position.
			update_chunks()


#This function will move all the tiles on screen when the position_coords change
#This will make it look like the user pans across the map
#When tiles move too far away the should be unloaded
func update_tiles_position(delta):
	var dist = Vector2(3 * grid_pixel_size + position_coord.x, 3 * grid_pixel_size + position_coord.x)
	for grid_container in tilesContainer.get_children():
		# Check if the node is indeed a GridContainer since the container might have other types of nodes.
		if grid_container is GridContainer:
			# Update the grid container's position by subtracting the delta to move it relative to the camera's movement.
			grid_container.position -= delta

			# Remove GridContainer if it is too far from the viewport (off-screen)
			# You need to define the bounds based on your game's design
#			var grid_container_global_position = tilesContainer.rect_global_position + grid_container.rect_position
#			var grid_container_global_position = grid_container.position
#
#			# Change these values according to your viewport and map setup
#			if grid_container_global_position.x < -dist.x or grid_container_global_position.x > get_viewport().size.x + dist.x or grid_container_global_position.y < -dist.y or grid_container_global_position.y > get_viewport().size.y + dist.y:
#				grid_container.queue_free()  # Use queue_free() to safely delete the node


#We will call this function when the position_coords change
func on_position_coord_changed(delta):
	update_tiles_position(delta)
	update_chunks()
	if positionLabel:
		positionLabel.text = "Position: " + str(position_coord)
		
		
func create_and_fill_grid_container(chunk: Array, chunk_position: Vector2):
	# Create a new GridContainer node for this chunk.
	var grid_container = GridContainer.new()
	grid_container.columns = chunk_width  # Set the number of columns to chunk_width.
	grid_container.set("theme_override_constants/h_separation", 0)
	grid_container.set("theme_override_constants/v_separation", 0)

	# Calculate the starting position for this chunk's set of tiles.
	var chunk_pixel_position = chunk_position# * chunk_size * tile_size

	# Iterate over the chunk array to create and add TextureRects for each tile.
	for i in range(chunk.size()):
		var tile_type = chunk[i]
		var texture = tile_materials[tile_type] # Retrieve the texture based on the tile type.
		var tile = TextureRect.new()
		tile.texture = texture
		grid_container.add_child(tile)

	# Set the position of the grid container in pixel space.
	grid_container.position = chunk_pixel_position

	# Return the filled grid container.
	return grid_container


# This function reads all the files in "res://Mods/Core/Tiles/". It will check if the file is a .png file. If the file is a .png file, it will create a new material with that .png image as the texture. It will put all of the created materials in a dictionary with the name of the file as the key and the material as the value.
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
					var texture := load("res://Mods/Core/OvermapTiles/" + file_name) # Load the .png file as a texture
					tile_materials[file_name] = texture # Add the material to the dictionary
			file_name = dir.get_next()
	else:
		print_debug("An error occurred when trying to access the path.")
	dir.list_dir_end()

