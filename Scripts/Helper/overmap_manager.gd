extends Node

# This script manages the overmap, the terrain that makes up the world.
# It is part of the Helper singleton and can be accessed by Helper.overmap_manager
# It keeps track of the player's coordinate and which chunks are in the area
# It has algorithms to add and remove chunks from the area
# It has helper functions to manipulate the overmap

# We keep a reference to the level_generator, which holds the chunks
# The level generator will register itself to this variable when it's ready
var level_generator: Node = null

@export_group("Settings")
@export var region_seed : String
@export var grid_width : int = 100
@export var grid_height : int = 100
@export var cell_size : int = 16
@export var chunk_size : int = 1 # Number of tiles per chunk. More makes it less... circular- I would keep it as is.
@export var load_radius : int = 8 # Number of chunks to load around the player. Basically sight radius on world map.

var player
var loaded_chunks = {}
# Cache to store loaded map data
var map_data_cache: Dictionary = {}
enum Region {
	CITY,
	FOREST,
	PLAINS
}

var noise : FastNoiseLite


class map_cell:
	var region = Region.PLAINS
	var coordinate_x: int = 0
	var coordinate_y: int = 0
	var mapname: String = "field_grass_basic_00.json"
	var tacticalmapname: String = "town_00.json"
	
	func get_data() -> Dictionary:
		return {
			"region": region,
			"coordinate_x": coordinate_x,
			"coordinate_y": coordinate_y,
			"mapname": mapname,
			"tacticalmapname": tacticalmapname
		}
		
	func set_data(newdata: Dictionary):
		if newdata.is_empty():
			return
		region = newdata.get("region", Region.PLAINS)
		coordinate_x = newdata.get("coordinate_x", 0)
		coordinate_y = newdata.get("coordinate_y", 0)
		mapname = newdata.get("mapname", "field_grass_basic_00.json")
		tacticalmapname = newdata.get("tacticalmapname", "town_00.json")
	
	func get_sprite() -> Texture:
		return Gamedata.get_sprite_by_id(Gamedata.data.maps, mapname.replace(".json", ""))


# Called when the node enters the scene tree for the first time.
func _ready():
	noise = FastNoiseLite.new()
	var rng = RandomNumberGenerator.new()
	noise.seed = rng.randi()
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

	# Generate regions
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
	noise.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
	noise.cellular_jitter = 0.01
	noise.frequency = 0.04 # Adjust frequency as needed

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
				cell.mapname = maps_by_category.pick_random()
			else:
				cell.mapname = "field_grass_basic_00.json"  # Fallback if no maps are found

			loaded_chunks[chunk_key].append(cell)


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


# Function to get maps by category
func get_maps_by_category(category: String) -> Array:
	var mapsList: Array = Gamedata.data.maps.data
	var matching_maps: Array = []
	
	for mapname in mapsList:
		var map_data: Dictionary
		
		if map_data_cache.has(mapname):
			map_data = map_data_cache[mapname]
		else:
			map_data = Gamedata.load_map_by_id(mapname)
			map_data_cache[mapname] = map_data
		
		if map_data.has("categories") and category in map_data["categories"]:
			matching_maps.append(mapname)
	
	return matching_maps



# Function to get a map_cell by global coordinate
func get_map_cell_by_global_coordinate(coord: Vector2) -> map_cell:
	var chunk_x = int(coord.x / (chunk_size * cell_size))
	var chunk_y = int(coord.y / (chunk_size * cell_size))
	var chunk_key = Vector2(chunk_x, chunk_y)
	
	if loaded_chunks.has(chunk_key):
		return get_map_cell_by_local_coordinate(chunk_key)
	else:
		# If the chunk is not loaded, generate it
		generate_chunk(chunk_key)
		return get_map_cell_by_local_coordinate(chunk_key)


# Function to get a map_cell by local coordinate within a specific chunk
func get_map_cell_by_local_coordinate(chunk_key: Vector2) -> map_cell:
	if loaded_chunks.has(chunk_key):
		return loaded_chunks[chunk_key][0]
	else:
		# If the chunk is not loaded, generate it
		generate_chunk(chunk_key)
		return get_map_cell_by_local_coordinate(chunk_key)
