# extends Node2D

# @export var world_seed : String


# # Called when the node enters the scene tree for the first time.
# func _ready():

# 	var rng = RandomNumberGenerator.new()
# 	rng.seed = hash(world_seed)

# 	generate_biomes()
# 	generate_elevation()


# # Called every frame. 'delta' is the elapsed time since the previous frame.
# func _process(_delta):
# 	pass

# # Generate "local hash" based on tile coordinates. We will use it together with world_seed
# func local_hash(x: int, y: int) -> int:
# 	var hash: int = int(x)
# 	hash ^= int(y) << 16
# 	hash ^= int(y) >> 16
# 	return hash


# func generate_biomes():
# 	pass

# func generate_elevation():
# 	pass

extends Node2D

@export var world_seed : String
@export var grid_width : int = 100
@export var grid_height : int = 100
@export var cell_size : int = 32

@export var temperate_sprite : Texture
@export var cold_sprite : Texture
@export var hot_sprite : Texture

enum Biome {
    TEMPERATE,
    COLD,
    HOT
}

var noise : FastNoiseLite

# Called when the node enters the scene tree for the first time.
func _ready():
    noise = FastNoiseLite.new()
    noise.seed = int(hash(world_seed)) # Setting the seed for noise
    noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
    noise.frequency = 0.05 # Adjust frequency as needed

    generate_biomes()
    generate_elevation()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
    pass

# Generate "local hash" based on tile coordinates. We will use it together with world_seed
func local_hash(x: int, y: int) -> int:
    var hash: int = int(x)
    hash ^= int(y) << 16
    hash ^= int(y) >> 16
    return hash


func generate_biomes():
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
            add_child(sprite)


func get_biome_type(x: int, y: int) -> int:
    var noise_value = noise.get_noise_2d(float(x), float(y))
    if noise_value < -0.3:
        return Biome.COLD
    elif noise_value < 0.3:
        return Biome.TEMPERATE
    else:
        return Biome.HOT


func generate_elevation():
    pass
