extends Control

@export var positionLabel: Label = null
@export var tilesContainer: Control = null
@export var overmapTile: PackedScene = null
@export var overmapTileLabel: Label = null
var last_position_coord: Vector2 = Vector2()
var noise = FastNoiseLite.new()
var grid_chunks: Dictionary = {} # Stores references to grid containers (visual tile grids)
var chunk_width: int = 32
var chunk_size: int = 32
var tile_size: int = 32
var grid_pixel_size: int = chunk_size * tile_size
var selected_overmap_tile: Control = null

# Variable to keep track of the previously visible overmap tile
var previous_visible_tile: Control = null

# We will emit this signal when the position_coords change
# Which happens when the user has panned the overmap
signal position_coord_changed(delta: Vector2)
#Fires when the player has pressed the travel button
signal change_level_pressed()

func _ready():
	# Centers the view when opening the ovemap. Works with default window size.
	# TODO: Have it calculated based on the window size
	Helper.position_coord = Vector2(-7,-5)
	update_chunks()
	position_coord_changed.connect(on_position_coord_changed)
	Helper.overmap_manager.player_coord_changed.connect(on_player_coord_changed)


# This function updates the chunks.
# It loops through a 4x4 grid centered on the current position
# generating new chunks at each position if they don't already exist. 
# After generating any necessary new chunks, it calls `unload_chunks()`
# to unload any chunks that are no longer needed. The
# `chunk_size` variable determines the size of each chunk,
# and `position_coord` is the current position in the world
# This function updates the chunks.
# It loops through a 4x4 grid centered on the current position
# generating new chunks at each position if they don't already exist. 
# After generating any necessary new chunks, it calls `unload_chunks()`
# to unload any chunks that are no longer needed. The
# `chunk_size` variable determines the size of each chunk,
# and `position_coord` is the current position in the world
func update_chunks():
	# Convert the current position to grid coordinates based on the chunk size
	# The grid position will move 32 over when the Helper_coord passes the last tile
	# The grid_position will be 0,0 between 0,0 and 31,31 if chunk_size = 32
	# The grid_position will be 1,0 between 32,0 and 64,31 if chunk_size = 32
	var grid_position: Vector2 = (Helper.position_coord / chunk_size).floor() * chunk_size

	for x in range(-2, 3):
		for y in range(-2, 3):
			# At 0,0 we will have positions -64,-64 and -64, -32 and -64, 0 etc.
			var chunk_grid_position: Vector2 = grid_position + Vector2(x, y) * chunk_size
			
			# Use the separate Dictionary for retrieving the noise data
			if not Helper.chunks.has(chunk_grid_position):
				generate_chunk(chunk_grid_position)
			# Retrieve the chunk data for the specific position.
			var chunk_data = Helper.chunks[chunk_grid_position]

			if not grid_chunks.has(chunk_grid_position):
				# Use chunk data to create and fill the GridContainer.
				var localized_x: float = chunk_grid_position.x*tile_size - Helper.position_coord.x * tile_size
				var localized_y: float = chunk_grid_position.y*tile_size - Helper.position_coord.y * tile_size
				var new_grid_container = create_and_fill_grid_container(chunk_data, Vector2(localized_x, localized_y))
				tilesContainer.call_deferred("add_child", new_grid_container)
				# Store the GridContainer using the grid position as the key.
				grid_chunks[chunk_grid_position] = new_grid_container

	# After generating new chunks, you may want to unload any that are off-screen.
	unload_chunks()


# This function creates terrain for a specific area on the overmap. It uses a grid_position 
# to determine where to generate the terrain. The function employs a noise algorithm 
# to select tile types from a predefined list, creating a chunk of terrain data. 
# This data is stored in a global dictionary for later use in rendering the overmap.
func generate_chunk(grid_position: Vector2) -> void:
	var chunk = []
	for y in range(chunk_size):  # x goes from 0 to chunk_size - 1
		for x in range(chunk_size):  # y goes from 0 to chunk_size - 1
			# We calculate global coordinates by 
			# offsetting the local coordinates by the grid_position
			var global_x = grid_position.x + x # at 0,0 it will be between 0 and 15
			var global_y = grid_position.y + y
			if global_x == 0 and global_y == 0:
				chunk.append({"global_x": global_x, "global_y": global_y, "tacticalmap": Gamedata.data.tacticalmaps.data[0]})
			else:
				chunk.append({"global_x": global_x, "global_y": global_y, "tacticalmap": get_random_mapname_1_in_100()})
	# Store the chunk using the grid_position as the key.
	Helper.chunks[grid_position] = chunk
	
func get_random_mapname_1_in_100() -> String:
	if randi_range(0, 100) < 1:
		return Gamedata.data.tacticalmaps.data.pick_random()
	return ""


# The user will leave chunks behind as the map is panned around
# Chunks that are too far from the current position will be destroyed
# This will only destroy the visual representation of the data stored in Helper.chunks
func unload_chunks():
	# Lowering this number 5 will cause newly created chunks 
	# to be instantly deleted and recreated
	var range_limit = 3 * grid_pixel_size
	for chunk_position in grid_chunks.keys():
		if chunk_position.distance_to(Helper.position_coord) > range_limit:
			# Destroy the grid itself
			grid_chunks[chunk_position].call_deferred("queue_free")
			# Remove the reference to the grid
			grid_chunks.erase(chunk_position)

# Function to handle keyboard input for moving the overmap
func _input(event):
	if not visible:
		return
	if event is InputEventKey:
		var delta = Vector2.ZERO
		if event.is_pressed():
			match event.keycode:
				KEY_UP:
					delta = Vector2(0, -1)
				KEY_DOWN:
					delta = Vector2(0, 1)
				KEY_LEFT:
					delta = Vector2(-1, 0)
				KEY_RIGHT:
					delta = Vector2(1, 0)
		if delta != Vector2.ZERO:
			move_overmap(delta)


# Function to move the overmap by adjusting the position_coord
func move_overmap(delta: Vector2):
	var new_position_coord = (Helper.position_coord + delta).round()
	delta = new_position_coord - Helper.position_coord
	if delta != Vector2.ZERO:
		Helper.position_coord = new_position_coord
		position_coord_changed.emit(delta)
		last_position_coord = Helper.position_coord


# This function will move all the tile grids on screen when the position_coords change
# This will make it look like the user pans across the map
func update_tiles_position(delta: Vector2):
	for grid_container in tilesContainer.get_children():
		# Update the grid container's position by subtracting the delta
		grid_container.position -= delta * tile_size


# We will call this function when the position_coords change
func on_position_coord_changed(delta: Vector2):
	update_tiles_position(delta)
	update_chunks()
	if positionLabel:
		positionLabel.text = "Position: " + str(Helper.position_coord)


# This function creates and populates a GridContainer with tiles based on chunk data. 
# It takes two arguments: chunk, an array containing data for each tile in the chunk, 
# and chunk_position, a Vector2 representing the chunk's position in the world. 
# The function generates a new GridContainer, sets its columns to chunk_width, and 
# ensures no space between tiles. It then iterates over the chunk array, creating 
# a tile for each entry. Each tile's metadata is set with global and local positions, 
# and additional data like map files if available. Tiles are added as children to 
# the GridContainer, which is positioned based on chunk_position. The function returns 
# the populated GridContainer. This process visually represents a section of the 
# overmap in a grid format.
func create_and_fill_grid_container(chunk: Array, chunk_position: Vector2):
	var grid_container = GridContainer.new()
	grid_container.columns = chunk_width  # Set the number of columns to chunk_width.
	# Make sure there is no space between the tiles
	grid_container.set("theme_override_constants/h_separation", 0)
	grid_container.set("theme_override_constants/v_separation", 0)

	# Variables to keep track of the row and column position
	var row: int = 0
	var column: int = 0

	# Iterate over the chunk array to create and add TextureRects for each tile.
	for i in range(chunk.size()):
		if i > 0 and i % chunk_width == 0:
			row += 1
			column = 0  # Reset column at the start of a new row
		# Retrieve the texture based on the tile type.
		var tile = overmapTile.instantiate()
		var local_pos = Vector2(column * tile_size, row * tile_size)
		var global_pos = Vector2(chunk[i].global_x, chunk[i].global_y)
		var map_cell = Helper.overmap_manager.get_map_cell_by_local_coordinate(global_pos)
		var texture: Texture = map_cell.get_sprite() if map_cell else null
		tile.set_texture(texture)
		# Assign the tile's row and column information
		tile.set_meta("global_pos", global_pos)
		tile.set_meta("local_pos", local_pos)

		if global_pos == Vector2.ZERO:
			tile.set_color(Color(0.3, 0.3, 1))  # blue color

		tile.tile_clicked.connect(_on_tile_clicked)
		# Add the tile as a child to the grid container
		grid_container.add_child(tile)

		# Increase column count after placing each tile
		column += 1

	# Set the position of the grid container in pixel space.
	grid_container.position = chunk_position

	# Return the filled grid container.
	return grid_container


#This function will be connected to the signal of the tiles
func _on_tile_clicked(clicked_tile):
	if clicked_tile.has_meta("map_file"):
		selected_overmap_tile = clicked_tile
		var mapFile = clicked_tile.get_meta("map_file")
		var tilePos = clicked_tile.get_meta("global_pos")
		var posString: String = "Pos: (" + str(tilePos.x)+","+str(tilePos.y)+")"
		var nameString: String = "\nName: " + mapFile
		var envString: String = clicked_tile.tileData.texture
		envString = envString.replace("res://Mods/Core/OvermapTiles/","")
		envString = "\nEnvironment: " + envString
		var challengeString: String = "\nChallenge: Easy"
		overmapTileLabel.text = posString + nameString + envString + challengeString
	else: 
		selected_overmap_tile = null
		overmapTileLabel.text = "Select a valid target"


func _on_travel_button_button_up():
	change_level_pressed.emit()
	var mapFile = selected_overmap_tile.get_meta("map_file")
	var global_pos: Vector2 = selected_overmap_tile.get_meta("global_pos")
	Helper.switch_level(mapFile, global_pos)


func _on_home_button_button_up():
	# Calculate the screen center offset
	var screen_center_offset = get_viewport_rect().size * 0.5

	# Convert screen center offset to world coordinates based on the tile size
	var halfTileSize = tile_size/12.0
	var world_center_offset = screen_center_offset / halfTileSize

	# Calculate the new position as the negative of the world center offset
	var new_position_coord = -world_center_offset / tile_size

	# Calculate the delta for moving the tiles
	var delta = new_position_coord - Helper.position_coord

	# Update position_coord to the new position
	Helper.position_coord = new_position_coord

	# Emit the signal to update the overmap's position and tiles
	position_coord_changed.emit(delta)
	
	# Optionally, update the position label if it exists
	if positionLabel:
		positionLabel.text = "Position: (0, 0)"


# Function to update the visibility of overmap tile text
func update_overmap_tile_visibility(new_pos: Vector2):
	var current_tile = get_overmap_tile_at_position(new_pos)
	if current_tile:
		if previous_visible_tile and previous_visible_tile != current_tile:
			previous_visible_tile.set_text_visible(false)
		current_tile.set_text_visible(true)
		previous_visible_tile = current_tile


# Function to find the overmap tile at the given position
func get_overmap_tile_at_position(myposition: Vector2) -> Control:
	for chunk_position in grid_chunks.keys():
		var chunk = grid_chunks[chunk_position]
		for tile in chunk.get_children():
			if tile.get_meta("global_pos") == myposition:
				return tile
	return null


# When the player moves a coordinate on the map, i.e. when crossing the chunk border.
# Move ment could be between (0,0) and (0,1) for example
func on_player_coord_changed(_player: CharacterBody3D, _old_pos: Vector2, new_pos: Vector2):
	update_overmap_tile_visibility(new_pos)
