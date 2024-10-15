extends Node

# This script manages the overmap, the terrain that makes up the world.
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
# 1. The overmap uses coordinates like (-1,-1), (-1,0), (0,0), (1,0), (0,1), (1,1)
# 2. The overmap gui also uses this coordinate system, but saves them in chunks of 16
#   Which is why we need translation from the overmap gui to the overmap data
# 3. The LevelGenerator.gd also uses this system for loading and unloading chunks
# 4. Then there's the overmap meta positioning. The overmap has large chunks of grid_width
#   by grid_height, which holds 10000 cells. This set is what's saved and loaded to disk

# We keep a reference to the level_generator, which holds the chunks
# The level generator will register itself to this variable when it's ready
var level_generator: Node = null

@export_group("Settings")
@export var region_seed : String
@export var grid_width : int = 100
@export var grid_height : int = 100
# Cell is represented by a chunk, which is 32x32. This is used to calculate the player's cell position
@export var cell_size : int = 32
@export var chunk_size : int = 1 # Number of tiles per chunk. More makes it less... circular- I would keep it as is.
@export var load_radius : int = 8 # Number of chunks to load around the player. Basically sight radius on world map.

var loaded_grids: Dictionary = {}
# Dictionary to store lists of area positions sorted by dovermaparea.id
var area_positions: Dictionary = {}
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
var player_current_cell = Vector2.ZERO # Player's position per cell, updated regularly
var loaded_chunks = {}
enum Region {
	FOREST,
	PLAINS
}

const NOISE_VALUE_PLAINS = 0.3

var noise: FastNoiseLite

# When the player coordinate changed. player: The player node. 
# old_pos: The old coordinate in the grid. new_pos: The new coordinate in the grid
signal player_coord_changed(player: CharacterBody3D, old_pos: Vector2, new_pos: Vector2)


# A cell in the grid. This will tell you it's coordinate and if it's part
# of something bigger like the tacticalmap
class map_cell:
	var region = Region.PLAINS
	var coordinate_x: int = 0
	var coordinate_y: int = 0
	var dmap: DMap = null
	var map_id: String = "field_grass_basic_00.json":
		set(value):
			map_id = value
			dmap = Gamedata.maps.by_id(map_id)
	var tacticalmapname: String = "town_00.json"
	var revealed: bool = false # This cell will be obfuscated on the overmap if false (unexplored)
	var rotation: int = 0  # Will be any of [0, 90, 180, 270]

	func get_data() -> Dictionary:
		return {
			"region": region,
			"coordinate_x": coordinate_x,
			"coordinate_y": coordinate_y,
			"map_id": map_id,
			"tacticalmapname": tacticalmapname,
			"revealed": revealed,
			"rotation": rotation
		}

	func set_data(newdata: Dictionary):
		if newdata.is_empty():
			return
		region = newdata.get("region", Region.PLAINS)
		coordinate_x = newdata.get("coordinate_x", 0)
		coordinate_y = newdata.get("coordinate_y", 0)
		map_id = newdata.get("map_id", "field_grass_basic_00.json")
		tacticalmapname = newdata.get("tacticalmapname", "town_00.json")
		revealed = newdata.get("revealed", false)
		rotation = newdata.get("rotation", 0)

	func get_sprite() -> Texture:
		return dmap.sprite

	func reveal():
		revealed = true
	
	# Function to return formatted information about the map cell
	func get_info_string() -> String:
		# If the cell is not revealed, notify the player
		if not revealed:
			return "This area has not \nbeen explored yet."
		
		# If revealed, display the detailed information
		var pos_string: String = "Pos: (" + str(coordinate_x) + ", " + str(coordinate_y) + ")"
		
		# Use dmap's name and description instead of map_id
		var map_name_string: String = "\nName: " + dmap.name
		#var map_description_string: String = "\nDescription: " + dmap.description
		
		var region_string: String = "\nRegion: " + region_type_to_string(region)
		var challenge_string: String = "\nChallenge: Easy"  # Placeholder for now
		
		# Combine all the information into one formatted string
		return pos_string + map_name_string + region_string + challenge_string
		#return pos_string + map_name_string + map_description_string + region_string + challenge_string


	# Helper function to convert Region enum to string
	func region_type_to_string(region_type: int) -> String:
		match region_type:
			Region.PLAINS:
				return "Plains"
			Region.FOREST:
				return "Forest"
		return "Unknown"


# A grid that holds grid_width by grid_height of cells
# This is used to segment the overmap grid for saving and loading
# A maximum of 9 grids can exist at once. Grids that are far away will be unloaded
# Loading a grid will happen when the player is 25 cells away from the border of the next grid
# Unloading will happen if the player is 50 cells away from the border of the previous grid
class map_grid:
	# Should be 100 apart in any direction since it holds 100 cells. Starts at 0,0
	var pos: Vector2 = Vector2.ZERO
	var cells: Dictionary = {}
	# Dictionary to store map_id and their corresponding coordinates
	var map_id_to_coordinates: Dictionary = {}

	func get_data() -> Dictionary:
		var mydata: Dictionary = {"pos": pos, "cells": {}}
		for cell_key in cells.keys():
			mydata["cells"][str(cell_key)] = cells[cell_key].get_data()
		return mydata

	func set_data(mydata: Dictionary) -> void:
		var newpos = mydata.get("pos", "0,0")
		pos = Vector2(newpos.split(",")[0].to_int(), newpos.split(",")[1].to_int())
		cells.clear()
		for cell_key in mydata["cells"].keys():
			var cell = map_cell.new()
			cell.set_data(mydata["cells"][cell_key])
			cells[Vector2(cell_key.split(",")[0].to_int(), cell_key.split(",")[1].to_int())] = cell


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

	# Generate regions
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	#noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
	noise.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
	noise.cellular_jitter = 0.04
	noise.frequency = 0.1 # Adjust frequency as needed
	
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
	var cellpos: Vector2 = get_cell_pos_from_global_pos(Vector2(position.x, position.z))

	for x in range(cellpos.x - load_radius, cellpos.x + load_radius + 1):
		for y in range(cellpos.y - load_radius, cellpos.y + load_radius + 1):
			var distance_to_cell = Vector2(x - cellpos.x, y - cellpos.y).length()
			if distance_to_cell <= load_radius:
				var cell_key = Vector2(x, y)
				var grid_key = get_grid_pos_from_local_pos(cell_key)

				if loaded_grids.has(grid_key):
					var grid = loaded_grids[grid_key]
					if not grid.cells.has(cell_key):
						generate_cells_for_grid(grid)
				else:
					load_grid(grid_key)
					var grid = loaded_grids[grid_key]
					generate_cells_for_grid(grid)



# This function generates chunks for each cell in the grid, ensuring the grid is filled with cells.
func generate_cells_for_grid(grid: map_grid):
	for x in range(grid_width):
		for y in range(grid_height):
			var global_x = grid.pos.x * grid_width + x
			var global_y = grid.pos.y * grid_height + y
			var cell_key = Vector2(global_x, global_y)

			var region_type = get_region_type(global_x, global_y)
			var cell = map_cell.new()
			cell.coordinate_x = global_x
			cell.coordinate_y = global_y
			cell.region = region_type

			var maps_by_category = Gamedata.maps.get_maps_by_category(region_type_to_string(region_type))
			if maps_by_category.size() > 0:
				cell.map_id = pick_random_map_by_weight(maps_by_category)
			else:
				cell.map_id = "field_grass_basic_00.json"  # Fallback if no maps are found

			# Add the cell to the grid's cells dictionary
			grid.cells[cell_key] = cell

	# Place tactical maps on the grid, which may overwrite some cells
	place_overmap_area_on_grid(grid)
	place_tactical_maps_on_grid(grid)
	
	# Select positions for the city area and connect them with roads
	if area_positions.has("city"):
		connect_cities_by_riverlike_path(grid, area_positions["city"])

	# After all modifications, rebuild the map_id_to_coordinates dictionary
	build_map_id_to_coordinates(grid)


func build_map_id_to_coordinates(grid: map_grid):
	# Clear the existing dictionary to avoid stale data
	grid.map_id_to_coordinates.clear()

	# Iterate over all cells in the grid
	for cell_key in grid.cells.keys():
		var cell = grid.cells[cell_key]
		var map_id = cell.map_id

		# Initialize the list for this map_id if not already done
		if not grid.map_id_to_coordinates.has(map_id):
			grid.map_id_to_coordinates[map_id] = []

		# Append the cell's key (coordinate) to the list
		grid.map_id_to_coordinates[map_id].append(cell_key)


# Helper function to convert Region enum to string
func region_type_to_string(region_type: int) -> String:
	match region_type:
		Region.PLAINS:
			return "Plains"
		Region.FOREST:
			return "Forest"
	return "Unknown"


func get_region_type(x: int, y: int) -> int:
	var noise_value = noise.get_noise_2d(float(x), float(y))
	if noise_value < NOISE_VALUE_PLAINS:
		return Region.PLAINS
	else:
		return Region.FOREST


# Function to pick a random map based on weight
func pick_random_map_by_weight(maps_by_category: Array[DMap]) -> String:
	var total_weight = 0
	for map: DMap in maps_by_category:
		total_weight += map.weight

	var random_value = randi() % total_weight
	var current_weight = 0

	for map: DMap in maps_by_category:
		current_weight += map.weight
		if random_value < current_weight:
			return map.id

	return "field_grass_basic_00.json"  # Fallback in case of an error



# Function to get a map_cell by global coordinate
# Put in a global coordinate, for example the player position (minus the y coordinate)
# Get the map cell back. Anything between (0,0) and (32,32) returns the cell at (0,0)
func get_map_cell_by_global_coordinate(coord: Vector2) -> map_cell:
	var grid_key = get_grid_pos_from_global_pos(coord)
	var cell_key = get_cell_pos_from_global_pos(coord)

	if loaded_grids.has(grid_key):
		return get_map_cell_by_local_coordinate(cell_key)
	else:
		# If the grid is not loaded, load it
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
# Coordinates between 100,0 and 99,99 return 1,0.
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
func get_map_cell_by_local_coordinate(local_coord: Vector2) -> map_cell:
	var grid_key = get_grid_pos_from_local_pos(local_coord)
	var cell_key = Vector2(local_coord.x, local_coord.y)

	if loaded_grids.has(grid_key):
		var grid = loaded_grids[grid_key]
		if grid.cells.has(cell_key):
			return grid.cells[cell_key]

	return null


# Load a grid based on the grid position
func load_grid(grid_pos: Vector2):
	if loaded_grids.size() >= max_grids:
		unload_furthest_grid()

	if not loaded_grids.has(grid_pos):
		var grid = map_grid.new()
		grid.pos = grid_pos
		#grid.pos = Vector2(grid_pos.split(",")[0].to_int(), grid_pos.split(",")[1].to_int())
		# Assume load_grid_data is a function that loads grid data from storage
		# grid.set_data(load_grid_data(grid_pos))
		loaded_grids[grid_pos] = grid
		load_grid_from_file(grid_pos)


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
	var non_empty_chunk_data = {}  # Dictionary to store non-empty chunk data with chunk_pos as keys
	
	for x_offset in range(4):
		for y_offset in range(4):
			var chunk_pos = segment_pos + Vector2(x_offset, y_offset)
			if loaded_chunk_data.chunks.has(chunk_pos):
				var chunk_data = loaded_chunk_data.chunks[chunk_pos]
				if not chunk_data.is_empty():
					non_empty_chunk_data[chunk_pos] = chunk_data
					loaded_chunk_data.chunks.erase(chunk_pos)
					print("Chunk data at ", chunk_pos, " was not empty and has been erased.")
				else:
					print("Chunk data at ", chunk_pos, " is empty.")
			else:
				print("Chunk data at ", chunk_pos, " does not exist.")
	
	return non_empty_chunk_data


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
		var grid = map_grid.new()
		grid.set_data(grid_data)
		loaded_grids[grid.pos] = grid
		build_map_id_to_coordinates(grid)
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


# Function to find a valid position for placing a tactical map
func find_valid_position(placed_positions: Array, map_width: int, map_height: int) -> Vector2:
	var attempts = 0
	while attempts < 100:
		var random_x = randi() % (grid_width - map_width + 1)
		var random_y = randi() % (grid_height - map_height + 1)
		var valid_position_found = true

		for i in range(map_width):
			for j in range(map_height):
				var local_x = random_x + i
				var local_y = random_y + j
				var cell_key = Vector2(local_x, local_y)
				if cell_key in placed_positions:
					valid_position_found = false
					break
			if not valid_position_found:
				break

		if valid_position_found:
			return Vector2(random_x, random_y)
		
		attempts += 1
	return Vector2(-1, -1)  # Indicate that a valid position was not found


# Function to place tactical maps on a specific grid
func place_tactical_maps_on_grid(grid: map_grid):
	var placed_positions = []
	for n in range(10):  # Loop to place up to 10 tactical maps on the grid
		var dmap: DTacticalmap = Gamedata.tacticalmaps.get_random_map()

		var map_width = dmap.mapwidth
		var map_height = dmap.mapheight
		var chunks = dmap.chunks

		# Find a valid position on the grid to place the tactical map
		var position = find_valid_position(placed_positions, map_width, map_height)
		if position == Vector2(-1, -1):  # If no valid position is found, skip this map placement
			print("Failed to find a valid position for tactical map")
			continue

		var random_x = position.x
		var random_y = position.y

		# Place the tactical map chunks on the grid, overwriting cells as needed
		for i in range(map_width):
			for j in range(map_height):
				var local_x = random_x + i
				var local_y = random_y + j
				if local_x < grid_width and local_y < grid_height:
					var cell_key = Vector2(local_x, local_y)
					var chunk_index = j * map_width + i
					var dchunk: DTacticalmap.TChunk = chunks[chunk_index]
					update_cell_map_id(grid, cell_key, dchunk.id, dchunk.rotation)
					placed_positions.append(cell_key)  # Track the positions that have been occupied


# Function to place an area on the grid and return the valid position where it was placed
func place_area_on_grid(grid: map_grid, area_grid: Dictionary, placed_positions: Array, mapsize: Vector2) -> Vector2:
	var valid_position = find_valid_position(placed_positions, int(mapsize.x), int(mapsize.y))
	# Calculate the center offset
	var center_offset = Vector2(int(mapsize.x / 2), int(mapsize.y / 2))

	# Only if a valid position is found, place the area
	if valid_position != Vector2(-1, -1):
		for local_position in area_grid.keys():
			var adjusted_position = valid_position + local_position
			if area_grid.has(local_position):
				var tile = area_grid[local_position]
				if tile != null:
					update_cell_map_id(grid, adjusted_position, tile.dmap.id, tile.rotation)
					placed_positions.append(adjusted_position)
		# Return the valid position (adusted to the center of the placed area)
		return valid_position + center_offset

	# Return the valid position (the top-left corner of the placed area)
	return valid_position


# Main function to place overmap areas on the grid and track multiple positions per area by its area ID
func place_overmap_area_on_grid(grid: map_grid):
	var placed_positions = []  # Track positions that have already been placed
	area_positions.clear()

	# Loop to place up to 10 overmap areas on the grid
	for n in range(10):
		var mygenerator = OvermapAreaGenerator.new()
		var dovermaparea = Gamedata.overmapareas.by_id(Gamedata.overmapareas.get_random_area().id)
		mygenerator.dovermaparea = dovermaparea

		# Generate the area
		var area_grid: Dictionary = mygenerator.generate_area(10000)
		if area_grid.size() > 0:
			# Use the dimensions from mygenerator after generating the area
			var map_dimensions = mygenerator.dimensions

			# Place the area and get the valid position
			var valid_position = place_area_on_grid(grid, area_grid, placed_positions, map_dimensions)
			if valid_position != Vector2(-1, -1):
				# Ensure the area_positions dictionary has an array for this dovermaparea.id
				if not area_positions.has(dovermaparea.id):
					area_positions[dovermaparea.id] = []
				# Append the valid position to the list for this area's id
				area_positions[dovermaparea.id].append(valid_position)
		else:
			print("Failed to find a valid position for the overmap area.")


# Helper function to update a cell's map ID if it exists
func update_cell_map_id(grid: map_grid, cell_key: Vector2, map_id: String, rotation: int):
	var adjusted_cell_key = cell_key + grid.pos * grid_width
	if grid.cells.has(adjusted_cell_key):
		grid.cells[adjusted_cell_key].map_id = map_id.replace(".json", "")
		grid.cells[adjusted_cell_key].rotation = rotation  # Update rotation


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

# Function to find the closest map cell to the player that has the specified map_id
func find_closest_map_cell_with_id(map_id: String) -> map_cell:
	var player_position = get_player_cell_position()
	var closest_cell: map_cell = null
	var shortest_distance = INF  # Use a very large number to initialize the shortest distance

	# Iterate through all loaded grids
	for grid in loaded_grids.values():
		# Check if the grid contains the specified map_id in its map_id_to_coordinates dictionary
		if grid.map_id_to_coordinates.has(map_id):
			# Iterate through the coordinates that have this map_id
			for cell_key in grid.map_id_to_coordinates[map_id]:
				var cell = grid.cells[cell_key]
				
				# Calculate the distance to the player's position
				var distance = player_position.distance_to(Vector2(cell.coordinate_x, cell.coordinate_y))

				# If this is the closest cell so far, update the closest cell and shortest distance
				if distance < shortest_distance:
					shortest_distance = distance
					closest_cell = cell

	# Return the closest map cell with the specified map_id (or null if none found)
	return closest_cell

# Function to instantiate and return a new grid with generated cells
# This is used for visualization outside the game
func create_new_grid_with_default_values() -> map_grid:
	# Step 1: Create a new map_grid instance
	var new_grid = map_grid.new()

	# Step 2: Set default position for the grid (this can be customized or passed as an argument)
	new_grid.pos = Vector2(0, 0)

	# Step 3: Initialize the noise generator for terrain generation
	var rng = RandomNumberGenerator.new()
	Helper.mapseed = rng.randi()
	make_noise()
	
	generate_cells_for_grid(new_grid) # Step 4: Generate the grid

	# Step 4: Return the fully generated grid
	return new_grid


# Updated function to connect cities by a straight path
# Also uses the new update_path_on_grid function
func connect_cities_by_road(grid: map_grid, city_positions: Array) -> void:
	for i in range(city_positions.size() - 1):
		var start_pos = city_positions[i]
		var end_pos = city_positions[i + 1]
		
		# Get a straight path between two cities
		var path = get_straight_path(start_pos, end_pos)
		
		# Use the new path update function to mark the road along the path
		update_path_on_grid(grid, path)


# Helper function to get a straight path between two points
func get_straight_path(start: Vector2, end: Vector2) -> Array:
	var path = []
	
	# Get the difference in x and y
	var dx = abs(end.x - start.x)
	var dy = abs(end.y - start.y)
	
	# Get the direction of movement in x and y
	var sx = -1 if start.x > end.x else 1
	var sy = -1 if start.y > end.y else 1
	
	var err = dx - dy
	
	# Use Bresenham's line algorithm to get the straight path
	var current = start
	while current != end:
		path.append(current)
		var e2 = 2 * err
		if e2 > -dy:
			err -= dy
			current.x += sx
		if e2 < dx:
			err += dx
			current.y += sy
	
	path.append(end)
	return path


# Updated function to connect cities by a river-like path including neighbors
func connect_cities_by_riverlike_path(grid: map_grid, city_positions: Array) -> void:
	for i in range(city_positions.size() - 1):
		var start_pos = city_positions[i]
		var end_pos = city_positions[i + 1]
		
		# Generate an organic, winding path between two cities, including diagonal neighbors
		var path = generate_winding_path(start_pos, end_pos)
		
		# Use the new path update function to mark the road along the path
		update_path_on_grid(grid, path)


func generate_winding_path(start: Vector2, end: Vector2) -> Array:
	var path = []
	var current = start
	var max_deviation = 2  # Maximum allowed deviation from the direct path

	while current.distance_to(end) > 1:
		# Add the current position to the path only if it's not already included
		if not path.has(current):
			path.append(current)

		# Determine the next position based on direction toward the goal
		var next_position = (end - current).normalized() + current

		# Round to nearest grid position to ensure alignment with the grid
		next_position = next_position.round()

		# Check if the next step is diagonal
		if is_diagonal(current, next_position):
			# Randomly pick between a vertical or horizontal neighbor for diagonal movement
			if randi() % 2 == 0:
				var vertical_neighbor = current + Vector2(0, next_position.y - current.y)
				if not path.has(vertical_neighbor):
					path.append(vertical_neighbor)
			else:
				var horizontal_neighbor = current + Vector2(next_position.x - current.x, 0)
				if not path.has(horizontal_neighbor):
					path.append(horizontal_neighbor)

		# Prevent path from deviating too much from the straight line
		if next_position.distance_to(start) > max_deviation or next_position.distance_to(end) > max_deviation:
			next_position = current + (end - current).normalized().round()

		# Move to the next position
		current = next_position
		if not path.has(current):  # Avoid adding duplicates
			path.append(current)

	path.append(end)  # Add the final point
	return path


func update_path_on_grid(grid: map_grid, path: Array) -> void:
	var road_maps = Gamedata.maps.get_maps_by_category("Road")
	
	if road_maps.size() == 0:
		print("No road maps found in the 'Road' category!")
		return

	# Remove duplicate positions from the path manually
	path = remove_duplicates_from_path(path)

	for i in range(path.size() - 1):  # Loop through the path except the last point
		var position = path[i]
		var next_position = path[i + 1]  # Next position in the path

		if grid.cells.has(position):
			var cell = grid.cells[position]

			# Ensure we're not overwriting existing urban areas
			if not Gamedata.maps.is_map_in_category(cell.map_id, "Urban"):
				var dmap = road_maps.pick_random()

				# Get the correct rotation for the dmap based on its connections
				var correct_rotation = get_correct_rotation(dmap, position, next_position)

				# Update the cell with the correctly rotated dmap
				update_cell_map_id(grid, position, dmap.id, correct_rotation)


# Helper function to remove duplicates from the path
func remove_duplicates_from_path(path: Array) -> Array:
	var unique_path = []
	var visited_positions = {}
	
	for position in path:
		if not visited_positions.has(position):
			unique_path.append(position)
			visited_positions[position] = true
	
	return unique_path


# Function to check if the direction between two positions is diagonal
func is_diagonal(pos1: Vector2, pos2: Vector2) -> bool:
	var direction = pos2 - pos1
	return abs(direction.x) == 1 and abs(direction.y) == 1


# Updated get_correct_rotation function to use get_rotations_with_connection
# This function calculates the correct rotation for a dmap to match the intended direction.
# pos1 is the current position, and pos2 is the next position in the path.
func get_correct_rotation(dmap: DMap, pos1: Vector2, pos2: Vector2) -> int:
	# Determine the intended direction (e.g., "north", "east", "south", "west")
	var intended_direction: String = get_intended_direction(pos1, pos2)
	
	# Use the get_rotations_with_connection function to find valid rotations where "road" aligns with the intended direction
	var valid_rotations = get_rotations_with_connection(dmap, intended_direction)
	
	# If there are valid rotations, pick a random one
	if valid_rotations.size() > 0:
		return valid_rotations.pick_random()
	
	# Default to no rotation (0) if no valid rotation is found
	return 0


# Function to determine the intended direction based on the difference between two positions
func get_intended_direction(pos1: Vector2, pos2: Vector2) -> String:
	var direction = pos2 - pos1
	
	if direction == Vector2(0, -1):
		return "north"
	elif direction == Vector2(0, 1):
		return "south"
	elif direction == Vector2(-1, 0):
		return "west"
	elif direction == Vector2(1, 0):
		return "east"
	
	return ""


# Function to check which rotations allow the dmap to have a connection to the specified direction.
# The function returns an array of valid rotations (0, 90, 180, 270).
# dmap.connections example: {"north": "road", "south": "ground", ...}
# rotation_map specifies how the directions change with rotation.
func get_rotations_with_connection(dmap: DMap, target_direction: String) -> Array:
	var valid_rotations = []
	
	# Iterate over possible rotations (0, 90, 180, 270 degrees)
	for rotation in Gamedata.ROTATION_MAP.keys():
		# Get the connections after applying the current rotation
		var rotated_connections = Gamedata.ROTATION_MAP[rotation]

		# Check if the connection in the rotated direction matches the target direction
		if dmap.connections[rotated_connections[target_direction]] == "road":
			# Add this rotation to the valid rotations list if the connection matches
			valid_rotations.append(rotation)

	return valid_rotations


# Function to determine the required connections for a road tile
# based on neighboring cells in all four cardinal directions.
# Returns an array of directions that need road or ground connections.
func get_needed_connections(grid: map_grid, position: Vector2) -> Array:
	var directions = ["north", "east", "south", "west"]
	var connections = []

	# Iterate over each direction (north, east, south, west)
	for direction in directions:
		var neighbor_pos = position + Gamedata.DIRECTION_OFFSETS[direction]

		# Check if the neighbor exists in the grid
		if grid.cells.has(neighbor_pos):
			var neighbor_cell = grid.cells[neighbor_pos]

			# If the neighbor is a road tile, we need a road connection
			if Gamedata.maps.is_map_in_category(neighbor_cell.map_id, "Road"):
				connections.append(direction)

			# If the neighbor is an urban tile, we need a road connection
			elif Gamedata.maps.is_map_in_category(neighbor_cell.map_id, "Urban"):
				connections.append(direction)

			# If the neighbor is anything else, we need a ground connection
			else:
				# Add a ground connection if needed (optional handling, could be separate)
				# connections.append(direction)
				pass
		else:
			# If no neighbor exists, treat it as needing ground (optional)
			# connections.append(direction)
			pass

	return connections


# Function to get all road maps that can match the given connection directions (north, east, south, west)
# Takes into account rotations for each road map and returns a list of maps that match the provided connections.
func get_road_maps_with_connections(road_maps: Array[DMap], required_directions: Array[String]) -> Array[DMap]:
	var matching_maps = []

	# Iterate through each road map
	for road_map in road_maps:
		# Check all possible rotations (0, 90, 180, 270)
		for rotation in [0, 90, 180, 270]:
			var rotated_connections = get_rotated_connections(road_map.connections, rotation)

			# Check if the rotated connections match the required directions
			if are_connections_matching(rotated_connections, required_directions):
				matching_maps.append(road_map)
				break  # Stop checking other rotations for this road_map once a match is found

	return matching_maps

# Function to check if the rotated connections match the required directions
# rotated_connections is a dictionary mapping directions (north, east, etc.) to connection types (road, ground, etc.)
# required_directions is a list of directions that need to have "road" as the connection type.
func are_connections_matching(rotated_connections: Dictionary[String, String], required_directions: Array[String]) -> bool:
	for direction in required_directions:
		if rotated_connections.get(direction, "none") != "road":
			return false  # If any required direction doesn't have a road connection, return false
	return true

# Function to return a dictionary of connections after applying the rotation
# rotation can be 0, 90, 180, or 270 degrees, and connections map directions to connection types.
func get_rotated_connections(connections: Dictionary[String, String], rotation: int) -> Dictionary[String, String]:
	var rotated_connections = {}
	
	# Direction mappings based on the rotation
	var rotation_map = {
		0: {"north": "north", "east": "east", "south": "south", "west": "west"},
		90: {"north": "east", "east": "south", "south": "west", "west": "north"},
		180: {"north": "south", "east": "west", "south": "north", "west": "east"},
		270: {"north": "west", "east": "north", "south": "east", "west": "south"}
	}

	# Apply the rotation map to the connections
	for direction in connections.keys():
		var rotated_direction = rotation_map[rotation][direction]
		rotated_connections[rotated_direction] = connections[direction]

	return rotated_connections
