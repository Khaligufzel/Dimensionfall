extends Node3D

@export var level_generator: Node3D
@export var player: Node3D
@export var biome_chunk_parent: Node3D
@export var elevation_chunk_parent: Node3D
@export var region_chunk_parent : Node3D

@export_group("Settings")
@export var biome_seed : String
@export var elevation_seed : String
@export var region_seed : String
@export var grid_width : int = 100
@export var grid_height : int = 100
@export var cell_size : int = 16
@export var chunk_size : int = 1 # Number of tiles per chunk. More makes it less... circular- I would keep it as is.
@export var load_radius : int = 8 # Number of chunks to load around the player. Basically sight radius on world map.

@export_group("Biome")
@export var temperate_sprite : Texture
@export var cold_sprite : Texture
@export var hot_sprite : Texture

@export_group("Elevation")
@export var flat_sprite : Texture
@export var ocean_sprite : Texture
@export var hills_sprite : Texture
@export var mountains_sprite : Texture

@export_group("Region")
@export var city_sprite : Texture
@export var plains_sprite : Texture
@export var forest_sprite : Texture
@export var city_map_name : String
@export var plains_map_name : String
@export var forest_map_name : String



var loaded_chunks = {}

enum Biome {
	TEMPERATE,
	COLD,
	HOT
}

enum Elevation {
	FLAT,
	OCEAN,
	HILLS,
	MOUNTAINS
}

enum Region {
	CITY,
	FOREST,
	PLAINS
}

var noise : FastNoiseLite

# Called when the node enters the scene tree for the first time.
func _ready():
	noise = FastNoiseLite.new()

	var player_position = player.position
	load_chunks_around(player_position)


	biome_chunk_parent.visible = false
	elevation_chunk_parent.visible = false
	region_chunk_parent.visible = true


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):


	########## TEMPORARY! We don't want to load chunks so often, we should call load_chunks_around only when
	########## there is a need to (for example moving from one chunk to another)
	var player_position = player.position
	load_chunks_around(player_position)


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

#### By using the noise generator we probably don't need this anymore!

# Generate "local hash" based on tile coordinates. We will use it together with world_seed
# func local_hash(x: int, y: int) -> int:
# 	var hash: int = int(x)
# 	hash ^= int(y) << 16
# 	hash ^= int(y) >> 16
# 	return hash


func generate_chunk(chunk_key: Vector2):
	loaded_chunks[chunk_key] = []
	
	var chunk_x = int(chunk_key.x)
	var chunk_y = int(chunk_key.y)

	# Generate biomes
	noise.seed = int(hash(biome_seed))
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
	noise.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
	noise.frequency = 0.005 # Adjust frequency as needed

	for x in range(chunk_size):
		for y in range(chunk_size):
			var global_x = chunk_x * chunk_size + x
			var global_y = chunk_y * chunk_size + y

			var biome_type = get_biome_type(global_x, global_y)
			var sprite : Sprite2D = Sprite2D.new()
			match biome_type:
				Biome.TEMPERATE:
					sprite.texture = temperate_sprite
				Biome.COLD:
					sprite.texture = cold_sprite
				Biome.HOT:
					sprite.texture = hot_sprite
			sprite.position = Vector2(global_x * cell_size + cell_size / 2, global_y * cell_size + cell_size / 2)
			biome_chunk_parent.add_child(sprite)
			loaded_chunks[chunk_key].append(sprite)
	
	# Generate elevation
	noise.seed = int(hash(elevation_seed))
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
	noise.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
	noise.frequency = 0.005 # Adjust frequency as needed

	for x in range(chunk_size):
		for y in range(chunk_size):
			var global_x = chunk_x * chunk_size + x
			var global_y = chunk_y * chunk_size + y

			var elevation_type = get_elevation_type(global_x, global_y)
			var sprite : Sprite2D = Sprite2D.new()
			match elevation_type:
				Elevation.FLAT:
					sprite.texture = flat_sprite
				Elevation.OCEAN:
					sprite.texture = ocean_sprite
				Elevation.HILLS:
					sprite.texture = hills_sprite
				Elevation.MOUNTAINS:
					sprite.texture = mountains_sprite
			sprite.position = Vector2(global_x * cell_size + cell_size / 2, global_y * cell_size + cell_size / 2)
			elevation_chunk_parent.add_child(sprite)
			loaded_chunks[chunk_key].append(sprite)

	# # Generate regions
	# noise.seed = int(hash(region_seed))
	# noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	# noise.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
	# noise.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
	# noise.cellular_jitter = 0.01
	# noise.frequency = 0.04 # Adjust frequency as needed

	# for x in range(chunk_size):
	# 	for y in range(chunk_size):
	# 		var global_x = chunk_x * chunk_size + x
	# 		var global_y = chunk_y * chunk_size + y

	# 		var region_type = get_region_type(global_x, global_y)
	# 		var sprite : Sprite2D = Sprite2D.new()
	# 		match region_type:
	# 			Region.PLAINS:
	# 				sprite.texture = plains_sprite
	# 			Region.CITY:
	# 				sprite.texture = city_sprite
	# 			Region.FOREST:
	# 				sprite.texture = forest_sprite
	# 		sprite.position = Vector2(global_x * cell_size + cell_size / 2, global_y * cell_size + cell_size / 2)
	# 		region_chunk_parent.add_child(sprite)
	# 		loaded_chunks[chunk_key].append(sprite)

	# Generate regions
	noise.seed = int(hash(region_seed))
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
			var sprite : Sprite2D = Sprite2D.new()
			match region_type:
				Region.PLAINS:
					sprite.texture = plains_sprite
					#level_generator.initialize_map_data_from_world_generator(Vector2(chunk_x, chunk_y), plains_map_name)
				Region.CITY:
					sprite.texture = city_sprite
				Region.FOREST:
					sprite.texture = forest_sprite
			sprite.position = Vector2(global_x * cell_size + cell_size / 2, global_y * cell_size + cell_size / 2)
			region_chunk_parent.add_child(sprite)
			loaded_chunks[chunk_key].append(sprite)


func get_biome_type(x: int, y: int) -> int:
	var noise_value = noise.get_noise_2d(float(x), float(y))
	if noise_value < -0.5:
		return Biome.COLD
	elif noise_value < 0.5:
		return Biome.TEMPERATE
	else:
		return Biome.HOT

func get_elevation_type(x: int, y: int) -> int:
	var noise_value = noise.get_noise_2d(float(x), float(y))
	if noise_value < -0.4:
		return Elevation.OCEAN
	elif noise_value < 0.5:
		return Elevation.FLAT
	elif noise_value < 0.7:
		return Elevation.HILLS
	else:
		return Elevation.MOUNTAINS

func get_region_type(x: int, y: int) -> int:
	var noise_value = noise.get_noise_2d(float(x), float(y))
	if noise_value < -0.6:
		return Region.CITY
	elif noise_value < 0.4:
		return Region.PLAINS
	else:
		return Region.FOREST


func _input(event):
	if event.is_action_pressed("switch_to_1") :
		biome_chunk_parent.visible = true
		elevation_chunk_parent.visible = false
		region_chunk_parent.visible = false
			
	if event.is_action_pressed("switch_to_2"):
		biome_chunk_parent.visible = false
		elevation_chunk_parent.visible = true
		region_chunk_parent.visible = false

	if event.is_action_pressed("switch_to_3") :
		biome_chunk_parent.visible = false
		elevation_chunk_parent.visible = false
		region_chunk_parent.visible = true
		
