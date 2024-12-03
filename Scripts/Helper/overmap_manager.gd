extends Node

# This script manages the overmap, which defines the terrain making up the game world.
# It is part of the Helper singleton and can be accessed by Helper.overmap_manager
# It keeps track of the player's coordinate and which chunks are in the area
# It has algorithms to add and remove chunks from the area
# It has helper functions to manipulate the overmap

# This overmap manager only creates and manipulates data
# It creates a grid of cells based on map noise and decides what map goes where
# This creates as set of coordinates and map locations. Each map is as large
# as the chunk_size, which is 32x32x21 blocks. Each block is 1x1, so the chunks are 32 apart
# Therefore, if we know the player's location, we can calculate which chunk he is in.

# There are multiple coordinate systems that interact with the overmap_manager
# 1. The overmap uses coordinates like (-1,-1), (-1,0), (0,0), (1,0), (0,1), (1,1) for map_cell coordinates
# 	These coordinates are absolute and mark their global position on the overmap
# 2. The overmap gui also uses this coordinate system, but saves them in chunks of 16
#   Which is why we need translation from the overmap gui to the overmap data
# 3. The LevelGenerator.gd also uses this system for loading and unloading chunks
# 4. Then there's the overmap meta positioning. This is used for OvermapGrids The overmap has large chunks of grid_width
#   by grid_height, which holds 10000 cells. This set is what's saved and loaded to disk

# We keep a reference to the level_generator, which holds the chunks
# The level generator will register itself to this variable when it's ready
var level_generator: Node = null

@export var region_seed : String
@export var grid_width : int = 100
@export var grid_height : int = 100
# Cell is represented by a chunk, which is 32x32. This is used to calculate the player's cell position
@export var cell_size : int = 32
@export var chunk_size : int = 1 # Number of tiles per chunk. More makes it less... circular- I would keep it as is.
@export var load_radius : int = 8 # Number of chunks to load around the player. Basically sight radius on world map.

var loaded_grids: Dictionary = {} # Stores grids loaded in memory
var max_grids: int = 9
var grid_load_distance: int = 25 * cell_size  # Load when 25 cells away from the border
var grid_unload_distance: int = 50 * cell_size  # Unload when 50 cells away from the border


# Distance to load and unload data from loaded_chunk_data.chunks. Loading and unloading happens
# in segments, since one big file will be too big and saving each chunk separately will
# result in too many files.
var segment_load_distance: int = 16
var segment_unload_distance: int = 28
# Dictionary to cache loaded segment data to avoid redundant load calls to save_helper
var loaded_segments: Dictionary = {}

# Dictionary to hold data of chunks that are unloaded
# These chunks are the actual 32x32x21 collection of blocks, furniture, mobs and items
# That makes up the map that the player is walking on.
var loaded_chunk_data: Dictionary = {"chunks": {}}

var player
var player_current_cell: Vector2 = Vector2.ZERO # Player's position per cell, updated regularly
var loaded_chunks = {}

var noise: FastNoiseLite

# When the player coordinate changed. player: The player node. 
# old_pos: The old coordinate in the grid. new_pos: The new coordinate in the grid
signal player_coord_changed(player: CharacterBody3D, old_pos: Vector2, new_pos: Vector2)



# Called when the node enters the scene tree for the first time.
func _ready():
	# Connect to the Helper.signal_broker.game_started signal
	Helper.signal_broker.game_started.connect(_on_game_started)
	Helper.signal_broker.game_loaded.connect(_on_game_loaded)
	Helper.signal_broker.game_ended.connect(_on_game_ended)
	Helper.signal_broker.player_spawned.connect(_on_player_spawned)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):

	########## TEMPORARY! We don't want to load chunks so often, we should call load_chunks_around only when
	########## there is a need to (for example moving from one chunk to another)
	if player:
		var player_position = player.position
		load_cells_around(player_position)
		check_grids()
		update_player_position_and_manage_segments()


# Function for handling game started signal
func _on_game_started():
	make_noise()
	load_cells()
	
func make_noise():
	noise = FastNoiseLite.new()
	noise.seed = Helper.mapseed

	# Generate noise for the regions. These settings are delicate and a small adjustement
	# can have a big impact. To easily visualize the pattern:
	# 1. Open any scene and temporarily add a TextureRect and select it
	# 2. In the inspector, add a new 'noisetexture' as the texture property
	# 3. Under 'noise', add a new 'fastnoiselite'. Click on the fastnoiselite and adjust the properties
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.frequency = 0.05 # Increasing this will make smaller cells. Decreasing will create big cells
	
	# Only applies if noise_type equals TYPE_CELLULAR:
	noise.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
	noise.cellular_distance_function = FastNoiseLite.DISTANCE_HYBRID # Sensitivity of the pattern
	noise.cellular_jitter = 0 # Changes the pattern by warping the cells
	
	# Only applies if domain_warp_enabled equals true
	noise.domain_warp_enabled = true # Changing this to false disables the settings below:
	noise.domain_warp_type = FastNoiseLite.DOMAIN_WARP_SIMPLEX # Changing this creates different patterns
	noise.domain_warp_amplitude = 60 # Reducing this number will make the pattern trend towards squares
	noise.domain_warp_frequency = -0.015 # Useful values are between 0.01 and 0.02. Changes the pattern
	noise.domain_warp_fractal_type = FastNoiseLite.DOMAIN_WARP_FRACTAL_PROGRESSIVE # Makes no difference
	noise.domain_warp_fractal_octaves = 1 # Increasing this will destroy the pattern and turn it into noise
	noise.domain_warp_fractal_lacunarity = 16 # Makes no difference
	noise.domain_warp_fractal_gain = 5 # Makes no difference
	
	
func load_cells():
	loaded_grids.clear()
	load_cells_around(Vector3(0, 0, 0))

# Function for handling player spawned signal
func _on_player_spawned(playernode):
	player = playernode
	var player_position = player.position
	load_cells_around(player_position)
	var cellpos: Vector2 = get_cell_pos_from_global_pos(Vector2(player_position.x, player_position.z))
	player_coord_changed.emit(player, player_current_cell, cellpos)
	player_current_cell = cellpos


# Function for handling game loaded signal
func _on_game_loaded():
	make_noise()
	load_cells()
	load_all_grids()


# Function for handling game ended signal
func _on_game_ended():
	save_all_grids()
	player = null


# Takes a global position, like the player's position
# It calculates the cell positions around the cell of the given position
# If the position is (12,3), cellpos will be (0,0), since anything between (0,0) and (32,32) results in (0,0)
# If cellpos is 0,0, it will loop over the cells surrounding it, for example (-8,-8), (-8,-7) up to (8,8)
func load_cells_around(position: Vector3):
	var center_cell: Vector2i = get_cell_pos_from_global_pos(Vector2(position.x, position.z))

	for x in range(center_cell.x - load_radius, center_cell.x + load_radius + 1):
		for y in range(center_cell.y - load_radius, center_cell.y + load_radius + 1):
			var distance = Vector2(x - center_cell.x, y - center_cell.y).length()
			if distance <= load_radius:
				var cell_key = Vector2(x, y)
				var grid_key = get_grid_pos_from_local_pos(cell_key)

				load_grid(grid_key) # Will load a grid if it does not exist
				if loaded_grids[grid_key] and not loaded_grids[grid_key].cells.has(cell_key):
					loaded_grids[grid_key].generate_cells()


# Function to pick a random map based on weight
func pick_random_map_by_weight(maps_by_category: Array[RMap]) -> String:
	var total_weight = 0
	for map: RMap in maps_by_category:
		total_weight += map.weight

	var random_value = randi() % total_weight
	var current_weight = 0

	for map: RMap in maps_by_category:
		current_weight += map.weight
		if random_value < current_weight:
			return map.id

	return "field_grass_basic_00.json"  # Fallback in case of an error


# Function to get a map_cell by global coordinate
# Put in a global coordinate, for example the player position (minus the y coordinate)
# Get the map cell back. Anything between (0,0) and (32,32) returns the cell at (0,0)
func get_map_cell_by_global_coordinate(coord: Vector2i) -> OvermapGrid.map_cell:
	var grid_key: Vector2i = get_grid_pos_from_global_pos(coord)
	var cell_key: Vector2i = get_cell_pos_from_global_pos(coord)

	if not loaded_grids.has(grid_key): # If the grid is not loaded, load it
		load_grid(grid_key)
	return get_map_cell_by_local_coordinate(cell_key)


# Put in a global coordinate, for example the player position (minus the y coordinate)
# Get the grid coordinate back. Anything between (0,0) and (3200,3200) returns (0,0)
func get_grid_pos_from_global_pos(coord: Vector2) -> Vector2:
	var grid_x = int(coord.x * 1.0 / (grid_width * cell_size))
	var grid_y = int(coord.y * 1.0 / (grid_height * cell_size))
	return Vector2(grid_x, grid_y)


# Function to get a grid key from local coordinates
# Coordinates between 0,0 and 99,99 return 0,0.
# Coordinates between 100,0 and 199,99 return 1,0.
# Coordinates between -100,-100 and -1,-1 return -1,-1.
func get_grid_pos_from_local_pos(local_coord: Vector2) -> Vector2:
	var grid_x = floor(local_coord.x / grid_width)
	var grid_y = floor(local_coord.y / grid_height)
	return Vector2(grid_x, grid_y)


# Put in a global coordinate, for example the player position (minus the y coordinate)
# Get the cell coordinate back. For example (22,0) would return (0,0) and (34,0) would return (1,0)
func get_cell_pos_from_global_pos(coord: Vector2) -> Vector2:
	var local_x = floor(coord.x / cell_size)
	var local_y = floor(coord.y / cell_size)
	var cell_pos = Vector2(local_x, local_y)
	return cell_pos


# Function to get a map_cell by local coordinate within a specific grid
# A local coord will start at (0,0), the next cell will be (0,1) and so on
# It will return the map cell from the grid. 
# The grid can contain grid_width x grid_height amount of cells
# If the grid's position is in the negative range, for example (-1,-1) it will
# contain cells from (-100,100) up to (-1,-1)
func get_map_cell_by_local_coordinate(local_coord: Vector2) -> OvermapGrid.map_cell:
	var grid_key = get_grid_pos_from_local_pos(local_coord)
	var cell_key = Vector2(local_coord.x, local_coord.y)

	if loaded_grids.has(grid_key):
		var grid = loaded_grids[grid_key]
		if grid.cells.has(cell_key):
			return grid.cells[cell_key]

	return null


# Load a grid based on the grid position
# grid_pos: absolute vector2 relative to the other grids. Even though each grid contains 100x100 map_cells,
# they are only one space apart in their "meta" coordinate system. So the grid containing cells 
# (-100,100) to (-1,-1) is positioned at (-1,-1). The other grids may be (-1,0), (0,0), (1,0), (1,1)
func load_grid(grid_pos: Vector2):
	if loaded_grids.size() >= max_grids:
		unload_furthest_grid()

	if not loaded_grids.has(grid_pos):
		var grid = OvermapGrid.new()
		grid.pos = grid_pos
		loaded_grids[grid_pos] = grid
		load_grid_from_file(grid_pos) # Loads grid data from storage if available


# Unload the furthest grid from the player
func unload_furthest_grid():
	var player_grid_pos = get_player_grid_position()
	var furthest_grid_key = ""
	var max_distance = 0

	for key in loaded_grids.keys():
		var grid_pos = loaded_grids[key].pos
		var distance = player_grid_pos.distance_to(grid_pos)
		if distance > max_distance:
			max_distance = distance
			furthest_grid_key = key

	if furthest_grid_key:
		save_grid_to_file(loaded_grids[furthest_grid_key].get_data(), furthest_grid_key)
		loaded_grids.erase(furthest_grid_key)


# Get the current grid position of the player
func get_player_grid_position() -> Vector2:
	return get_grid_pos_from_global_pos(Vector2(player.position.x, player.position.z))

# Get the current cell position of the player
func get_player_cell_position() -> Vector2:
	return get_cell_pos_from_global_pos(Vector2(player.position.x, player.position.z))


# Check and load/unload grids based on player position
func check_grids():
	var player_grid_pos = get_player_grid_position()
	for dx in range(-1, 1):
		for dy in range(-1, 1):
			var grid_pos = Vector2(player_grid_pos.x + dx, player_grid_pos.y + dy)
			
			var grid_key = grid_pos
			
			if not loaded_grids.has(grid_key):
				load_grid(grid_pos)

	for key in loaded_grids.keys():
		var grid_pos = loaded_grids[key].pos
		var distance = player_grid_pos.distance_to(grid_pos) * cell_size
		if distance > grid_unload_distance:
			unload_furthest_grid()

	
# Selects segment coordinates to load within the specified distance from the player
func load_segments_around_player() -> Array:
	var segments_to_load = []
	var player_cell_pos = get_player_cell_position()

	for x in range(player_cell_pos.x - segment_load_distance, player_cell_pos.x + segment_load_distance + 1, 4):
		for y in range(player_cell_pos.y - segment_load_distance, player_cell_pos.y + segment_load_distance + 1, 4):
			var segment_pos = get_segment_pos(Vector2(x, y))
			segments_to_load.append(segment_pos)
	
	return segments_to_load


# Unload segments that are too far from the player. This is only to keep loaded_chunk_data limted in size
# This function calculates which segments should be unloaded based on the player's current cell position.
# It loops over the keys of loaded_chunk_data.chunks to get the chunk positions.
# For each chunk position, it calculates the corresponding segment position using get_segment_pos.
# It checks if the segment position is not already in segments_to_unload to avoid duplicates.
# It calculates the distance from the player's cell position to the segment position.
# If the distance is greater than segment_unload_distance, it adds the segment position to segments_to_unload.
func unload_distant_segments() -> Array:
	var segments_to_unload = []
	var player_cell_pos = get_player_cell_position()

	for chunk_pos in loaded_chunk_data.chunks.keys():
		var segment_pos = get_segment_pos(chunk_pos)
		if not segments_to_unload.has(segment_pos):
			var distance = player_cell_pos.distance_to(segment_pos)
			if distance > segment_unload_distance:
				segments_to_unload.append(segment_pos)
	
	return segments_to_unload


# Helper function to get the top-left coordinate of the 4x4 segment
# This function calculates the top-left coordinate of a 4x4 segment for a given chunk position.
# It uses the floor function to ensure the coordinates are properly aligned to the segment grid.
# The segment's top-left coordinate is calculated by flooring the chunk position divided by 4, then multiplying back by 4.
func get_segment_pos(chunk_pos: Vector2) -> Vector2:
	var segment_x = floor(chunk_pos.x / 4) * 4
	var segment_y = floor(chunk_pos.y / 4) * 4
	return Vector2(segment_x, segment_y)


# Function to check player's position and trigger load/unload of segments
# This function checks if the player's position has changed by comparing the new position to the stored player position.
# If the player's position has changed, it updates the player position and calls functions to load and unload segments.
func update_player_position_and_manage_segments(force_update: bool = false):
	var new_position = get_player_cell_position()
	if new_position != player_current_cell or force_update:
		var last_cell: Vector2 = player_current_cell
		player_current_cell = new_position
		player_coord_changed.emit(player, last_cell, player_current_cell)
		
		# Call visit() on the map cell corresponding to the new position
		var new_cell = get_map_cell_by_global_coordinate(player_current_cell)
		if new_cell:
			new_cell.visit()
		
		# Load segments around the player
		var segments_to_load = load_segments_around_player()
		
		for segment_pos in segments_to_load:
			if not loaded_segments.has(segment_pos):
				var loaded_segment_data = Helper.save_helper.load_map_segment_data(segment_pos)
				loaded_segments[segment_pos] = loaded_segment_data
				# Merge loaded segment data into loaded_chunk_data.chunks
				for chunk_pos in loaded_segment_data.keys():
					if not loaded_chunk_data.chunks.has(chunk_pos):
						loaded_chunk_data.chunks[chunk_pos] = loaded_segment_data[chunk_pos]

		# Unload segments that are too far from the player
		var segments_to_unload = unload_distant_segments()
		
		for segment_pos in segments_to_unload:
			if loaded_segments.has(segment_pos):
				loaded_segments.erase(segment_pos)
			var non_empty_chunk_data = process_and_clear_segment(segment_pos)
			if not non_empty_chunk_data.is_empty():
				Helper.save_helper.save_map_segment_data(non_empty_chunk_data, segment_pos)


# Function to process and clear each segment
# This function takes a segment position and loops over every possible coordinate in the 4x4 range.
# For each coordinate, it checks the chunk data from loaded_chunk_data.chunks.
# If the chunk data is not empty, it is erased from loaded_chunk_data.chunks and added to a dictionary.
# The function returns the dictionary of non-empty chunk data.
func process_and_clear_segment(segment_pos: Vector2) -> Dictionary:
	var non_empty_data: Dictionary = {} # Dictionary to store non-empty chunk data with chunk_pos as keys
	for x_offset in range(4):
		for y_offset in range(4):
			var chunk_key: Vector2i = segment_pos + Vector2(x_offset, y_offset)
			if loaded_chunk_data.chunks.has(chunk_key) and not loaded_chunk_data.chunks[chunk_key].is_empty():
				non_empty_data[chunk_key] = loaded_chunk_data.chunks[chunk_key]
				loaded_chunk_data.chunks.erase(chunk_key)
	return non_empty_data


# Function to unload all remaining segments from loaded_chunk_data.chunks without saving
# This function processes and clears each segment, ensuring that no chunk data remains in memory.
func unload_all_remaining_segments():
	var all_segments_to_unload = []
	# Collect all unique segment positions
	for chunk_pos in loaded_chunk_data.chunks.keys():
		var segment_pos = get_segment_pos(chunk_pos)
		if not all_segments_to_unload.has(segment_pos):
			all_segments_to_unload.append(segment_pos)

	# Process and clear each segment
	for segment_pos in all_segments_to_unload:
		process_and_clear_segment(segment_pos)  # Erase chunks without saving
	loaded_segments.clear()


# Function to save the current state of the grid
func save_grid_to_file(grid_data: Dictionary, grid_key: Vector2) -> void:
	Helper.save_helper.save_overmap_grid_to_file(grid_data, grid_key)


# Function to load the state of the grid
func load_grid_from_file(grid_key: Vector2) -> void:
	var grid_data: Dictionary = Helper.save_helper.load_overmap_grid_from_file(grid_key)
	process_loaded_grid_data(grid_data)


# Creates a new grid from grid data loaded from disk 
func process_loaded_grid_data(grid_data: Dictionary):
	if grid_data:
		var grid = OvermapGrid.new()
		grid.set_data(grid_data)
		loaded_grids[grid.pos] = grid
		grid.build_map_id_to_coordinates()
		print_debug("Grid loaded from file at " + str(grid.pos))
	else:
		print_debug("Failed to parse grid file")


# Function to save all remaining grids
func save_all_grids() -> void:
	for gridkey in loaded_grids.keys():
		save_grid_to_file(loaded_grids[gridkey].get_data(), gridkey)


func load_all_grids():
	var loaded_grids_array: Array = Helper.save_helper.load_all_overmap_grids_from_file()
	for loadedgrid: Dictionary in loaded_grids_array:
		process_loaded_grid_data(loadedgrid)


# Function to save all remaining segments without unloading
func save_all_segments():
	var all_segments_to_save = []
	# Collect all unique segment positions
	for chunk_pos in loaded_chunk_data.chunks.keys():
		var segment_pos = get_segment_pos(chunk_pos)
		if not all_segments_to_save.has(segment_pos):
			all_segments_to_save.append(segment_pos)

	# Process and save each segment
	for segment_pos in all_segments_to_save:
		var non_empty_chunk_data = collect_segment_data(segment_pos)
		if not non_empty_chunk_data.is_empty():
			Helper.save_helper.save_map_segment_data(non_empty_chunk_data, segment_pos)


# Function to collect data for each segment without clearing it
func collect_segment_data(segment_pos: Vector2) -> Dictionary:
	var non_empty_chunk_data = {}  # Dictionary to store non-empty chunk data with chunk_pos as keys
	
	for x_offset in range(4):
		for y_offset in range(4):
			var chunk_pos = segment_pos + Vector2(x_offset, y_offset)
			if loaded_chunk_data.chunks.has(chunk_pos):
				var chunk_data = loaded_chunk_data.chunks[chunk_pos]
				if not chunk_data.is_empty():
					non_empty_chunk_data[chunk_pos] = chunk_data
					print("Chunk data at ", chunk_pos, " was not empty and has been collected.")
				else:
					print("Chunk data at ", chunk_pos, " is empty.")
			else:
				print("Chunk data at ", chunk_pos, " does not exist.")
	
	return non_empty_chunk_data


# Function to find the closest map cell to the player for a list of map IDs
# map_ids: Array of map IDs to search for.
# target_properties: A dictionary containing:
#   - reveal_condition (String): One of "HIDDEN", "REVEALED", "EXPLORED", "VISITED".
#     Determines how the target is selected based on its reveal state.
#   - exact_match (bool, default: false): If true, only exact matches for the reveal_condition are valid.
# Returns the closest map cell, or null if no suitable cell is found.
func find_closest_map_cell_with_ids(map_ids: Array, target_properties: Dictionary = {}) -> OvermapGrid.map_cell:
	var player_position = get_player_cell_position()
	var closest_cell: OvermapGrid.map_cell = null
	var shortest_distance = INF  # Use a very large number to initialize the shortest distance
	var exact_match: bool = target_properties.get("exact_match", false)

	# Define the priority order of reveal conditions
	var reveal_priority = get_revealed_priority(target_properties.get("reveal_condition", "HIDDEN"))

	# Iterate through reveal conditions in priority order
	for condition in reveal_priority:
		# Iterate through all loaded grids
		for grid in loaded_grids.values():
			# Check if the grid contains any of the specified map IDs
			for map_id in map_ids:
				if not grid.map_id_to_coordinates.has(map_id):
					continue

				# Iterate through the coordinates that have this map ID
				for cell_key in grid.map_id_to_coordinates[map_id]:
					var cell: OvermapGrid.map_cell = grid.cells[cell_key]

					# Check if the cell matches the current reveal condition
					if not cell.matches_reveal_condition(condition, exact_match):
						continue

					# Calculate the distance to the player's position
					var distance = player_position.distance_to(Vector2(cell.coordinate_x, cell.coordinate_y))

					# If this is the closest cell so far, update the closest cell and shortest distance
					if distance < shortest_distance:
						shortest_distance = distance
						closest_cell = cell

		# If we found a closest cell for this condition, return it
		if closest_cell:
			return closest_cell

	# Return the closest map cell (if any), or null if no cells exist for the map IDs
	return closest_cell



func get_revealed_priority(reveal_condition: String) -> Array:
	# Convert reveal_condition to uppercase for case-insensitive matching
	var condition_upper = reveal_condition.to_upper()

	# Define the priority order of reveal conditions
	var reveal_priority: Array = ["HIDDEN"]
	match condition_upper:
		"VISITED":
			reveal_priority = ["VISITED", "EXPLORED", "REVEALED", "HIDDEN"]
		"EXPLORED":
			reveal_priority = ["EXPLORED", "REVEALED", "HIDDEN"]
		"REVEALED":
			reveal_priority = ["REVEALED", "HIDDEN"]
		"HIDDEN":
			reveal_priority = ["HIDDEN"]
		_:
			reveal_priority = ["HIDDEN"]  # Default fallback in case of unknown reveal_condition
	return reveal_priority


# Function to instantiate and return a new grid with generated cells
# This is used for visualization outside the game
func create_new_grid_with_default_values() -> OvermapGrid:
	# Step 1: Create a new OvermapGrid instance
	var new_grid = OvermapGrid.new()

	# Step 2: Set default position for the grid (this can be customized or passed as an argument)
	new_grid.pos = Vector2(0, 0)

	# Step 3: Initialize the noise generator for terrain generation
	var rng = RandomNumberGenerator.new()
	Helper.mapseed = rng.randi()
	make_noise()
	
	new_grid.generate_cells()

	# Step 4: Return the fully generated grid
	return new_grid



# Function to get a grid from it's meta position
# Coordinates 0,0 returns the OvermapGrid at 0,0.
# Coordinates 1,0 returns the OvermapGrid at 1,0.
# Coordinates -1,-1 returns the OvermapGrid at -1,-1.
func get_grid_from_meta_pos(meta_coord: Vector2) -> OvermapGrid:
	if loaded_grids.has(meta_coord):
		return loaded_grids[meta_coord]
	return null


# Function to get a grid from local coordinates
# Coordinates between 0,0 and 99,99 return the OvermapGrid at 0,0.
# Coordinates between 100,0 and 199,99 return the OvermapGrid at 1,0.
# Coordinates between -100,-100 and -1,-1 return the OvermapGrid at -1,-1.
func get_grid_from_local_pos(local_coord: Vector2) -> OvermapGrid:
	var grid_pos: Vector2 = get_grid_pos_from_local_pos(local_coord)
	if loaded_grids.has(grid_pos):
		return loaded_grids[grid_pos]
	return null


# Function to get a map_cell from local coordinates
# Coordinates between 0,0 and 99,99 return the cell at that position from the OvermapGrid at 0,0.
# Coordinates between 100,0 and 199,99 return the cell at that position from the OvermapGrid at 1,0.
# Coordinates between -100,-100 and -1,-1 return the cell at that position from the OvermapGrid at -1,-1.
func get_grid_cell_from_local_pos(local_coord: Vector2) -> OvermapGrid.map_cell:
	var grid: OvermapGrid = get_grid_from_local_pos(local_coord)
	return grid.get_cell_from_global_pos(local_coord)


# Function to check if the player is at a specific position
# position: A Vector2 representing the target position in cell coordinates.
# Returns true if the player's current cell position matches the given position, otherwise false.
func is_player_at_position(position: Vector2) -> bool:
	return player_current_cell == position
