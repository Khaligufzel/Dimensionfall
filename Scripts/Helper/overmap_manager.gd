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
var player_last_cell = Vector2.ZERO # Player's position per cell, updated regularly
var loaded_chunks = {}
enum Region {
	CITY,
	FOREST,
	PLAINS
}

const NOISE_VALUE_CITY = -0.2
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
	var map_id: String = "field_grass_basic_00.json"
	var tacticalmapname: String = "town_00.json"
	var revealed: bool = false
	var rotation: int = 0  # Will be any of [0, 90, 180, 270]

	func get_data() -> Dictionary:
		return {
			"region": region,
			"coordinate_x": coordinate_x,
			"coordinate_y": coordinate_y,
			"map_id": map_id,
			"tacticalmapname": tacticalmapname,
			"revealed": revealed,
			"rotation": rotation  # Include rotation in data
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
		rotation = newdata.get("rotation", 0)  # Set rotation from data

	func get_sprite() -> Texture:
		return Gamedata.maps.by_id(map_id).sprite

	func reveal():
		revealed = true


# A grid that holds grid_width by grid_height of cells
# This is used to segment the overmap grid for saving and loading
# A maximum of 9 grids can exist at once. Grids that are far away will be unloaded
# Loading a grid will happen when the player is 25 cells away from the border of the next grid
# Unloading will happen if the player is 50 cells away from the border of the previous grid
class map_grid:
	# Should be 100 apart in any direction since it holds 100 cells. Starts at 0,0
	var pos: Vector2 = Vector2.ZERO
	var cells: Dictionary = {}

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
	make_noise_and_load_cells()
	
func make_noise_and_load_cells():
	noise = FastNoiseLite.new()
	noise.seed = Helper.mapseed

	# Generate regions
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	#noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
	noise.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
	noise.cellular_jitter = 0.04
	noise.frequency = 0.1 # Adjust frequency as needed
	
	loaded_grids.clear()
	load_cells_around(Vector3(0, 0, 0))

# Function for handling player spawned signal
func _on_player_spawned(playernode):
	player = playernode
	var player_position = player.position
	load_cells_around(player_position)
	var cellpos: Vector2 = get_cell_pos_from_global_pos(Vector2(player_position.x, player_position.z))
	player_coord_changed.emit(player, player_last_cell, cellpos)


# Function for handling game loaded signal
func _on_game_loaded():
	make_noise_and_load_cells()
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

			grid.cells[cell_key] = cell

	place_tactical_maps_on_grid(grid)


# Helper function to convert Region enum to string
func region_type_to_string(region_type: int) -> String:
	match region_type:
		Region.PLAINS:
			return "Plains"
		Region.CITY:
			return "City"
		Region.FOREST:
			return "Forest"
	return ""

func get_region_type(x: int, y: int) -> int:
	var noise_value = noise.get_noise_2d(float(x), float(y))
	if noise_value < NOISE_VALUE_CITY:
		return Region.CITY
	elif noise_value < NOISE_VALUE_PLAINS:
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
	if new_position != player_last_cell or force_update:
		player_coord_changed.emit(player, player_last_cell, new_position)
		player_last_cell = new_position
		
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


# Function to unload and save all remaining segments from loaded_chunk_data.chunks
# This function processes and clears each segment, ensuring that no chunk data remains in memory
# and all segments are saved to the disk.
func unload_all_remaining_segments():
	var all_segments_to_unload = []
	# Collect all unique segment positions
	for chunk_pos in loaded_chunk_data.chunks.keys():
		var segment_pos = get_segment_pos(chunk_pos)
		if not all_segments_to_unload.has(segment_pos):
			all_segments_to_unload.append(segment_pos)

	# Process and save each segment
	for segment_pos in all_segments_to_unload:
		var non_empty_chunk_data = process_and_clear_segment(segment_pos)
		if not non_empty_chunk_data.is_empty():
			Helper.save_helper.save_map_segment_data(non_empty_chunk_data, segment_pos)
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


# Function to randomly load and return a tactical map
func load_random_tactical_map() -> Dictionary:
	var tacticalmaps = Helper.json_helper.file_names_in_dir(Gamedata.data.tacticalmaps.dataPath)
	var random_tactical_map = tacticalmaps[randi() % tacticalmaps.size()]
	print_debug("Picked taclcalmap: " + random_tactical_map)
	return Helper.json_helper.load_json_dictionary_file(Gamedata.data.tacticalmaps.dataPath + random_tactical_map)


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
	print_debug("Failed to find a position")
	return Vector2(-1, -1)  # Indicate that a valid position was not found


# Function to place tactical maps on a specific grid
func place_tactical_maps_on_grid(grid: map_grid):
	var placed_positions = []
	for n in range(10):
		var tactical_map_data = load_random_tactical_map()

		var map_width = tactical_map_data.get("mapwidth", 0)
		var map_height = tactical_map_data.get("mapheight", 0)
		var chunks = tactical_map_data.get("chunks", [])

		var position = find_valid_position(placed_positions, map_width, map_height)
		if position == Vector2(-1, -1):
			print("Failed to find a valid position for tactical map")
			continue
		print_debug("Placing chunk " + chunks[0].id + ", at position " + str(position))

		var random_x = position.x
		var random_y = position.y

		for i in range(map_width):
			for j in range(map_height):
				var local_x = random_x + i
				var local_y = random_y + j
				if local_x < grid_width and local_y < grid_height:
					var cell_key = Vector2(local_x, local_y)
					var chunk_index = j * map_width + i
					var chunk_data = chunks[chunk_index]
					update_cell_map_id(grid, cell_key, chunk_data["id"], chunk_data.get("rotation", 0))
					placed_positions.append(cell_key)


# Helper function to update a cell's map ID if it exists
func update_cell_map_id(grid: map_grid, cell_key: Vector2, map_id: String, rotation: int):
	if grid.cells.has(cell_key):
		grid.cells[cell_key].map_id = map_id.replace(".json", "")
		grid.cells[cell_key].rotation = rotation  # Update rotation
