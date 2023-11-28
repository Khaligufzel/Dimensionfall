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
var loaded_tiles: Array = []
var tile_materials = {} # Create an empty dictionary to store materials

#We will connect the position_coord to this function in the _ready function
func _ready():
	load_tiles_material()
	noise.seed = randi()
	noise.fractal_octaves = 4
	noise.domain_warp_amplitude = 20.0
	noise.fractal_gain = 0.5
	update_chunks()
	connect("position_coord_changed", on_position_coord_changed)
	draw_all_chunks()

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
	for x in range(-2, 2):
		for y in range(-2, 2):
			var chunk_position = position_coord + Vector2(x, y) * chunk_size
			if not chunks.has(chunk_position):
				generate_chunk(chunk_position, chunk_size)
	unload_chunks()

# This GDScript function, `generate_chunk`, generates
# a chunk of tiles at a given position with a specified
# size. First, it initializes an empty list, `chunk`,
# to store the tiles. Then, it iterates over the range
# of the new size in both the x and y dimensions. For
# each tile, it determines the tile type based on a 2D
# noise function, which takes the x and y coordinates
# (adjusted by the position of the chunk) as input. This
# noise value is then normalized (to be within the range
# of 0 to 1) and scaled by the size of the `tiles` array,
# then converted to an integer to serve as an index for
# the `tiles` array. The corresponding tile is added
# to the `chunk` list. Finally, the function stores the
# generated chunk in the `chunks` dictionary, using the
# position of the chunk as the key. This function is
# typically used in procedural generation of game maps,
# where each "chunk" represents a portion of the game
# world.
func generate_chunk(position_loc: Vector2, newSize: int):
	var chunk = []
	for x in range(newSize):
		for y in range(newSize):
			var tile_type = noise.get_noise_2d(position_loc.x + x, position_loc.y + y)
			tile_type = int((tile_type + 1) / 2 * tiles.size())
			chunk.append(tiles[tile_type])
	chunks[position_loc] = chunk

func unload_chunks():
	for chunk_position in chunks.keys():
		if chunk_position.distance_to(position_coord) > 2 * chunk_size:
			chunks.erase(chunk_position)

var mouse_button_pressed: bool = false

#We will emit this signal when the position_coords change
signal position_coord_changed(delta)

#We will change the position_coords in the _input function
func _input(event):
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_MIDDLE: 
				if event.pressed:
					mouse_button_pressed = true
				else:
					mouse_button_pressed = false
	
	if event is InputEventMouseMotion:
		if mouse_button_pressed:
			# Calculate the new position first.
			var new_position_coord = position_coord - event.relative / 100
			# Now calculate delta based on the old and new positions.
			var delta = new_position_coord - last_position_coord
			# Update position_coord to the new position
			position_coord = new_position_coord
			# Pass the delta when emitting the signal
			emit_signal("position_coord_changed", delta)
			# Update last_position_coord for the next input event.
			last_position_coord = position_coord
			update_chunks()
#			var delta = position_coord - last_position_coord
#			print_debug(delta)
#			position_coord += event.relative / 100
#			emit_signal("position_coord_changed", delta)
#			last_position_coord = position_coord
#			update_chunks()
#			position_coord.x += event.relative.x / 100
#			position_coord.y += event.relative.y / 100
#			emit_signal("position_coord_changed")
#			update_chunks()

#This function is never called but is used to draw tile onto the screen
#We need to find when to call this function, probably after chunks are updated
func draw_all_chunks():
	for chunk_position in chunks.keys():
		var chunk = chunks[chunk_position]
		for i in range(chunk.size()):
			var tile_position = chunk_position + Vector2(i % 32, i / 32)
			var tile_type = chunk[i]
			var texture = tile_materials[tile_type]
#			var texture = load("res://Mods/Core/OvermapTiles/" + tile_type + ".png")
			var tile = TextureRect.new()
			tile.texture = texture
			tile.position = tile_position * 32
			tilesContainer.add_child(tile)
			loaded_tiles.append(tile)
	if positionLabel:
		positionLabel.text = "Position: " + str(position_coord)


#This function will move all the tiles on screen when the position_coords change
#This will make it look like the user pans across the map
#When tiles move too far away the should be unloaded

func update_tiles_position(delta):
	for tile in loaded_tiles:
		# Update each tile position by subtracting the delta to move them relative to the camera's movement.
		tile.position -= delta * chunk_size
		# Check if the tile has gone off the screen and should be unloaded.
		if tile.position.x < -chunk_size or \
		tile.position.x > get_viewport().size.x + chunk_size or \
		tile.position.y < -chunk_size or \
		tile.position.y > get_viewport().size.y + chunk_size:
			tile.queue_free()
			loaded_tiles.erase(tile)
#func update_tiles_position():
#	for tile in loaded_tiles:
#		tile.position += position_coord# * chunk_size
#		if tile.position.x < -chunk_size or tile.position.x > get_viewport().size.x + chunk_size or tile.position.y < -chunk_size or tile.position.y > get_viewport().size.y + chunk_size:
#			tile.queue_free()
#			loaded_tiles.erase(tile)

#We will call this function when the position_coords change
func on_position_coord_changed(delta):
	update_tiles_position(delta)
	update_chunks()
	if positionLabel:
		positionLabel.text = "Position: " + str(position_coord)
#func on_position_coord_changed():
#	update_tiles_position()
#	update_chunks()
#	if positionLabel:
#		positionLabel.text = "Position: " + str(position_coord)



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

