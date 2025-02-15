extends Node

# Autoload singleton that loads all game data required to run the game
# Accessible via Gamedata.property
var mods: DMods

# Only hides the visual instance when it's above the player. Casts no shadow
static var hide_above_player_shader := preload("res://Shaders/HideAbovePlayer.gdshader")
# Hides the visual instance when it's above the player and casts a shadow
static var hide_above_player_shadow := preload("res://Shaders/HideAbovePlayerShadow.gdshader")

# Dictionary to store loaded textures
var textures: Dictionary = {
	"container": load("res://Textures/container_32.png"),
	"container_filled": load("res://Textures/container_filled_32.png"),
	"under_construction": load("res://Textures/under_construction_32.png")
}
var materials: Dictionary = {}

# Rotation mappings for how directions change based on tile rotation
const ROTATION_MAP: Dictionary = {
	0: {"north": "north", "east": "east", "south": "south", "west": "west"},
	90: {"north": "east", "east": "south", "south": "west", "west": "north"},
	180: {"north": "south", "east": "west", "south": "north", "west": "east"},
	270: {"north": "west", "east": "north", "south": "east", "west": "south"}
}

# Define direction offsets for easy neighbor lookups
const DIRECTION_OFFSETS: Dictionary = {
	"north": Vector2(0, -1),
	"east": Vector2(1, 0),
	"south": Vector2(0, 1),
	"west": Vector2(-1, 0)
}

# Dictionary to map content types to Gamedata variables
var gamedata_map: Dictionary = {}

# This function is called when the node is added to the scene.
func _ready():
	# Instantiate the content type instances
	mods = DMods.new()

	materials["container"] = create_item_shader_material(textures.container)
	materials["container_filled"] = create_item_shader_material(textures.container_filled)
	materials["under_construction"] = create_item_shader_material(textures.under_construction)


# Helper function to create a ShaderMaterial for the item
func create_item_shader_material(albedo_texture: Texture) -> ShaderMaterial:
	# Create a new ShaderMaterial
	var shader_material = ShaderMaterial.new()
	shader_material.shader = hide_above_player_shader  # Use the shared shader

	# Assign the texture to the material
	shader_material.set_shader_parameter("texture_albedo", albedo_texture)

	return shader_material
