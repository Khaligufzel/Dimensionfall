extends Node

# Autoload singleton that loads all game data required to run the game
# Accessible via Gamedata.property
var mods: DMods

# Only hides the visual instance when it's above the player. Casts no shadow
static var hide_above_player_shader := preload("res://Shaders/HideAbovePlayer.gdshader")
# Hides the visual instance when it's above the player and casts a shadow
static var hide_above_player_shadow := preload("res://Shaders/HideAbovePlayerShadow.gdshader")

# Dictionary to store loaded textures
var textures: Dictionary[String,Texture] = {
	"container": load("res://Textures/container_32.png"),
	"container_filled": load("res://Textures/container_filled_32.png"),
	"under_construction": load("res://Textures/under_construction_32.png")
}
var materials: Dictionary[String,StandardMaterial3D] = {}

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

	materials["container"] = _create_container_material(textures.container)
	materials["container_filled"] = _create_container_material(textures.container_filled)
	materials["under_construction"] = _create_container_material(textures.under_construction)


# Helper function to create a StandardMaterial3D for the coontainer sprite
func _create_container_material(tex: Texture) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.flags_transparent = true
	return mat
