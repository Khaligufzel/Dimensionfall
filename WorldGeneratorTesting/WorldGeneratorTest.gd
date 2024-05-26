extends Node2D



@export var player: Node2D
@export var biome_chunk_parent: Node2D
@export var elevation_chunk_parent: Node2D

@export var biome_seed : String
@export var elevation_seed : String
@export var grid_width : int = 100
@export var grid_height : int = 100
@export var cell_size : int = 16

@export var temperate_sprite : Texture
@export var cold_sprite : Texture
@export var hot_sprite : Texture

@export var flat_sprite : Texture
@export var ocean_sprite : Texture
@export var hills_sprite : Texture
@export var mountains_sprite : Texture

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

var noise : FastNoiseLite

# Called when the node enters the scene tree for the first time.
func _ready():
	noise = FastNoiseLite.new()



	generate_biomes()
	generate_elevation()

	biome_chunk_parent.visible = true
	elevation_chunk_parent.visible = false


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass

#### By using the noise generator we probably don't need this anymore!

# Generate "local hash" based on tile coordinates. We will use it together with world_seed
# func local_hash(x: int, y: int) -> int:
# 	var hash: int = int(x)
# 	hash ^= int(y) << 16
# 	hash ^= int(y) >> 16
# 	return hash


func generate_biomes():

	noise.seed = int(hash(biome_seed)) # Setting the seed for noise
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
	noise.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
	noise.frequency = 0.005 # Adjust frequency as needed

	for x in range(grid_width):
		for y in range(grid_height):
			var biome_type = get_biome_type(x, y)
			var sprite : Sprite2D = Sprite2D.new()
			match biome_type:
				Biome.TEMPERATE:
					sprite.texture = temperate_sprite
				Biome.COLD:
					sprite.texture = cold_sprite
				Biome.HOT:
					sprite.texture = hot_sprite
			sprite.position = Vector2(x * cell_size + cell_size / 2, y * cell_size + cell_size / 2)
			biome_chunk_parent.add_child(sprite)


func get_biome_type(x: int, y: int) -> int:
	var noise_value = noise.get_noise_2d(float(x), float(y))
	if noise_value < -0.5:
		return Biome.COLD
	elif noise_value < 0.5:
		return Biome.TEMPERATE
	else:
		return Biome.HOT


func generate_elevation():

	noise.seed = int(hash(elevation_seed)) # Setting the seed for noise
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
	noise.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
	noise.frequency = 0.005 # Adjust frequency as needed

	for x in range(grid_width):
		for y in range(grid_height):
			var elevation_type = get_elevation_type(x, y)
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
			sprite.position = Vector2(x * cell_size + cell_size / 2, y * cell_size + cell_size / 2)
			elevation_chunk_parent.add_child(sprite)


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


func _input(event):
	if event.is_action_pressed("switch_to_1") :
		biome_chunk_parent.visible = true
		elevation_chunk_parent.visible = false
			
	if event.is_action_pressed("switch_to_2"):
		biome_chunk_parent.visible = false
		elevation_chunk_parent.visible = true
		