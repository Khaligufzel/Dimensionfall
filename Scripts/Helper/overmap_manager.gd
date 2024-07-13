
extends Node

# This script manages the overmap, the terrain that makes up the world.
# It is part of the Helper singleton and can be accessed by Helper.overmap_manager
# It keeps track of the player's coordinate and which chunks are in the area
# It has algorithms to add and remove chunks from the area
# It has helper functions to manipulate the overmap

# This overmap manager only creates and manipulates data
# It creates a grid of cells based on map noise and decides what map goes where
# This creates as set of coordinates and map locations. Each map is as large
# as the cunk_size, which is 32x32x21 blocks. Each block is 1x1, so the chunks are 32 apart
# Therefore, if we know the player's location, we can calculate which chunk he is in.

# There are multiple coordinate systems that interact with the overmap_manager
# 1. The overmap uses coordinates like (-1,-1), (-1,0), (0,0), (1,0), (0,1), (1,1)
# 2. The overmap gui also uses this coordinate system, but saves them in chunks of 16
# 	Which is why we need translation from the overmap gui to the overmap data
# 3. The LevelGenerator.gd also uses this system for loading and unloading chunks
# 4. Then there's the overmap meta positioning. The overmap has large chunks of grid_width
#	by grid_height, which holds 10000 cells. This set is what's saved and loaded to disk

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


var player
var loaded_chunks = {}
# Cache to store loaded map data
# TODO: Have Gamedata load all map files at start and get the map data from there.
var map_data_cache: Dictionary = {}
enum Region {
	CITY,
	FOREST,
	PLAINS
}

var noise : FastNoiseLite


# A cell in the grid. This will tell you it's coordinate and if it's part
# of something bigger like the tacticalmap
class map_cell:
	var region = Region.PLAINS
	var coordinate_x: int = 0
	var coordinate_y: int = 0
	var map_id: String = "field_grass_basic_00.json"
	var tacticalmapname: String = "town_00.json"
	var revealed: bool = false
	
	func get_data() -> Dictionary:
		return {
			"region": region,
			"coordinate_x": coordinate_x,
			"coordinate_y": coordinate_y,
			"map_id": map_id,
			"tacticalmapname": tacticalmapname
		}
		
	func set_data(newdata: Dictionary):
		if newdata.is_empty():
			return
		region = newdata.get("region", Region.PLAINS)
		coordinate_x = newdata.get("coordinate_x", 0)
		coordinate_y = newdata.get("coordinate_y", 0)
		map_id = newdata.get("map_id", "field_grass_basic_00.json")
		tacticalmapname = newdata.get("tacticalmapname", "town_00.json")
	
	func get_sprite() -> Texture:
		return Gamedata.get_sprite_by_id(Gamedata.data.maps, map_id.replace(".json", ""))
	
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
		var mydata: Dictionary = {}
		mydata["pos"] = pos
		mydata["cells"] = cells
		return mydata
		
	func set_data(mydata: Dictionary) -> void:
		pos = mydata.get("pos", Vector2i.ZERO)
		cells = mydata.get("cells", {})


# Called when the node enters the scene tree for the first time.
func _ready():
	noise = FastNoiseLite.new()
	var rng = RandomNumberGenerator.new()
	noise.seed = rng.randi()

	# Generate regions
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
	noise.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
	noise.cellular_jitter = 0.01
	noise.frequency = 0.04 # Adjust frequency as needed
	# Connect to the Helper.signal_broker.game_started signal
	Helper.signal_broker.game_started.connect(_on_game_started)
	Helper.signal_broker.game_ended.connect(_on_game_ended)
	Helper.signal_broker.player_spawned.connect(_on_player_spawned)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):

	########## TEMPORARY! We don't want to load chunks so often, we should call load_chunks_around only when
	########## there is a need to (for example moving from one chunk to another)
	if player:
		var player_position = player.position
		load_chunks_around(player_position)
		check_grids()


# Function for handling game started signal
func _on_game_started():
	pass

# Function for handling player spawned signal
func _on_player_spawned(playernode):
	player = playernode
	var player_position = player.position
	load_chunks_around(player_position)

# Function for handling game loaded signal
func _on_game_loaded():
	# To be developed later
	pass

# Function for handling game ended signal
func _on_game_ended():
	player = null


func load_chunks_around(position: Vector3):
	var chunk_x = int(position.x / (chunk_size * cell_size))
	var chunk_z = int(position.z / (chunk_size * cell_size))

	for x in range(chunk_x - load_radius, chunk_x + load_radius + 1):
		for z in range(chunk_z - load_radius, chunk_z + load_radius + 1):
			var distance_to_chunk_center = Vector2(x - chunk_x, z - chunk_z).length()
			if distance_to_chunk_center <= load_radius:
				var chunk_key = Vector2(x, z)
				if not loaded_chunks.has(chunk_key):
					generate_chunk(chunk_key)


func generate_chunk(chunk_key: Vector2):
	loaded_chunks[chunk_key] = []
	
	var chunk_x = int(chunk_key.x)
	var chunk_y = int(chunk_key.y)

	for x in range(chunk_size):
		for y in range(chunk_size):
			var global_x = chunk_x * chunk_size + x
			var global_y = chunk_y * chunk_size + y

			var region_type = get_region_type(global_x, global_y)
			var cell = map_cell.new()
			cell.coordinate_x = global_x
			cell.coordinate_y = global_y
			cell.region = region_type
			
			var maps_by_category = get_maps_by_category(region_type_to_string(region_type))
			if maps_by_category.size() > 0:
				cell.map_id = pick_random_map_by_weight(maps_by_category)
			else:
				cell.map_id = "field_grass_basic_00.json"  # Fallback if no maps are found

			loaded_chunks[chunk_key].append(cell)


# This function generates chunks for each cell in the grid, ensuring the grid is filled with cells.
func generate_chunks_for_grid(grid: map_grid):
	for x in range(grid_width):
		for y in range(grid_height):
			var cell_key = Vector2i(x, y)
			var global_x = grid.pos.x * grid_width + x
			var global_y = grid.pos.y * grid_height + y

			var region_type = get_region_type(global_x, global_y)
			var cell = map_cell.new()
			cell.coordinate_x = global_x
			cell.coordinate_y = global_y
			cell.region = region_type

			var maps_by_category = get_maps_by_category(region_type_to_string(region_type))
			if maps_by_category.size() > 0:
				cell.map_id = pick_random_map_by_weight(maps_by_category)
			else:
				cell.map_id = "field_grass_basic_00.json"  # Fallback if no maps are found

			grid.cells[cell_key] = cell


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
	if noise_value < -0.6:
		return Region.CITY
	elif noise_value < 0.4:
		return Region.PLAINS
	else:
		return Region.FOREST


# Function to get maps by category, considering their weights
func get_maps_by_category(category: String) -> Array:
	var maps_list: Array = Gamedata.data.maps.data
	var matching_maps: Array = []

	for mapname in maps_list:
		var map_data: Dictionary

		if map_data_cache.has(mapname):
			map_data = map_data_cache[mapname]
		else:
			map_data = Gamedata.load_map_by_id(mapname)
			map_data_cache[mapname] = map_data

		if map_data.has("categories") and category in map_data["categories"]:
			matching_maps.append(map_data)

	return matching_maps


# Function to pick a random map based on weight
func pick_random_map_by_weight(maps_by_category: Array) -> String:
	var total_weight = 0
	for map_data in maps_by_category:
		total_weight += int(map_data.get("weight", 1000))  # Default weight is 1000

	var random_value = randi() % total_weight
	var current_weight = 0

	for map_data in maps_by_category:
		current_weight += map_data.get("weight", 1000)
		if random_value < current_weight:
			return get_key_from_value(map_data)  # Fallback mapname

	return "field_grass_basic_00.json"  # Fallback in case of an error


# Function to get the key from map_data_cache given the map_data dictionary
func get_key_from_value(map_data: Dictionary) -> String:
	for key in map_data_cache.keys():
		if map_data_cache[key] == map_data:
			return key
	return "field_grass_basic_00.json"  # Fallback in case of an error


# Function to get a map_cell by global coordinate
func get_map_cell_by_global_coordinate(coord: Vector2) -> map_cell:
	var global_x = int(coord.x)
	var global_y = int(coord.y)
	var grid_x = int(global_x*1.0 / (grid_width * cell_size))
	var grid_y = int(global_y*1.0 / (grid_height * cell_size))
	var grid_key = Vector2(grid_x, grid_y)
	var local_x = global_x % (grid_width * cell_size)
	var local_y = global_y % (grid_height * cell_size)

	if loaded_grids.has(str(grid_key)):
		return get_map_cell_by_local_coordinate(grid_key, Vector2(local_x, local_y))
	else:
		# If the grid is not loaded, load it
		load_grid(Vector2i(grid_x, grid_y))
		return get_map_cell_by_local_coordinate(grid_key, Vector2(local_x, local_y))


# Function to get a map_cell by local coordinate within a specific grid
func get_map_cell_by_local_coordinate(grid_key: Vector2, local_coord: Vector2) -> map_cell:
	var local_x = int(local_coord.x / cell_size)
	var local_y = int(local_coord.y / cell_size)
	var cell_key = Vector2i(local_x, local_y)

	if loaded_grids.has(str(grid_key)):
		var grid = loaded_grids[str(grid_key)]
		if grid.cells.has(cell_key):
			return grid.cells[cell_key]
		else:
			# If the cell is not present in the grid, generate it
			var cell = map_cell.new()
			grid.cells[cell_key] = cell
			return cell
	else:
		# If the grid is not loaded, load it
		load_grid(Vector2(grid_key.x, grid_key.y))
		return get_map_cell_by_local_coordinate(grid_key, local_coord)



# Load a grid based on the grid position
func load_grid(grid_pos: Vector2i):
	if loaded_grids.size() >= max_grids:
		unload_furthest_grid()
	
	var grid_key = str(grid_pos.x) + "_" + str(grid_pos.y)
	if not loaded_grids.has(grid_key):
		var grid = map_grid.new()
		grid.pos = grid_pos
		# Assume load_grid_data is a function that loads grid data from storage
		#grid.set_data(load_grid_data(grid_pos))
		loaded_grids[grid_key] = grid


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
		# Assume save_grid_data is a function that saves grid data to storage
		#save_grid_data(loaded_grids[furthest_grid_key].get_data())
		loaded_grids.erase(furthest_grid_key)


# Get the current grid position of the player
# 
# This function calculates which grid the player is currently in, based on their position.
# The overmap is divided into multiple grids, each consisting of `grid_width` by `grid_height` cells.
# Each cell has a size defined by `cell_size`, which represents the 
# length of one side of a cell in world units.
# The player's position is divided by the total size of a 
# grid (in world units) to determine the grid coordinates.
# These grid coordinates are returned as a Vector2, representing the x and y indices of the grid.
#
# Returns:
#   Vector2i: The grid coordinates (x, y) of the player's current position.
func get_player_grid_position() -> Vector2:
	var player_pos = player.position
	var grid_x = int(player_pos.x / (grid_width * cell_size))
	var grid_y = int(player_pos.z / (grid_height * cell_size))
	return Vector2(grid_x, grid_y)


# Check and load/unload grids based on player position
func check_grids():
	var player_grid_pos = get_player_grid_position()

	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var grid_pos = Vector2(player_grid_pos.x + dx, player_grid_pos.y + dy)
			var grid_key = str(grid_pos.x) + "_" + str(grid_pos.y)
			
			if not loaded_grids.has(grid_key):
				load_grid(grid_pos)

	for key in loaded_grids.keys():
		var grid_pos = loaded_grids[key].pos
		var distance = player_grid_pos.distance_to(grid_pos) * cell_size
		if distance > grid_unload_distance:
			unload_furthest_grid()
