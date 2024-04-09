extends Node3D

@export var construction_ghost : MeshInstance3D
var is_building = false

@export var player_path: NodePath
@export var hud : NodePath

# Called when the node enters the scene tree for the first time.
func _ready():
#	tile_map = get_node(tile_map_path)
	
	#3D
#	ghost_sprite = get_node(ghost_sprite_path)
#	ghost_sprite.visible = false
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if is_building:
		construction_ghost.visible = true
		
		# 3d
#		ghost_sprite.global_position = get_global_mouse_position()


func _input(_event):
	#3D
	
#	if Input.is_action_pressed("click") && is_building && get_node(hud).try_to_spend_item("plank", 2):
		
#		if get_node(player_path).check_if_visible(get_global_mouse_position()) && Vector2(get_node(player_path).global_position).distance_to(get_global_mouse_position()) <= build_range:
#			tile_map.set_cell(0, tile_map.local_to_map(get_global_mouse_position()), 0, Vector2i(9,3))
		
	if Input.is_action_pressed("click_right") && is_building:
		is_building = false
		General.is_allowed_to_shoot = true
		construction_ghost.visible = false

func make_tile_ghost():
	pass

func _on_hud_construction_chosen(_construction: String):
	print("Building test")
	is_building = true
	General.is_allowed_to_shoot = false

func on_construction_clicked(construction_data: Dictionary):
	print_debug("Block placed at: ", construction_data.pos, "with type ", construction_data.id)
