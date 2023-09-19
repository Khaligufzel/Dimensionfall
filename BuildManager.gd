extends Node2D

@export var tile_map_path : NodePath
var tile_map : TileMap

@export var ghost_sprite_path : NodePath
var ghost_sprite : Sprite2D

var is_building = false

# Called when the node enters the scene tree for the first time.
func _ready():
	tile_map = get_node(tile_map_path)
	ghost_sprite = get_node(ghost_sprite_path)
	ghost_sprite.visible = false


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if is_building:
		ghost_sprite.visible = true
		#ghost_sprite.global_position = get_global_mouse_position()
		ghost_sprite.global_position = get_global_mouse_position()
		#ghost_sprite.global_position = tile_map.map_to_local()

func _input(event):
	if Input.is_action_pressed("click"):
		tile_map.set_cell(0, tile_map.local_to_map(get_global_mouse_position()), 0, Vector2i(9,3))

func make_tile_ghost():
	pass

func _on_hud_construction_chosen(construction: String):
	print("Building test")
	is_building = true
