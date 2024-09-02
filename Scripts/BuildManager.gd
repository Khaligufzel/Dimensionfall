extends Node3D

@export var construction_ghost : MeshInstance3D
var is_building = false

@export var LevelGenerator: Node3D
@export var hud : NodePath

# Called when the node enters the scene tree for the first time.
func _ready():
	# Connect the build menu visibility_changed signal to a local method
	Helper.signal_broker.build_window_visibility_changed.connect(_on_build_menu_visibility_change)
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
	var chunk: Chunk = LevelGenerator.get_chunk_from_position(construction_data.pos)
	if chunk:
		# Calculate local position within the chunk
		var local_x = int(construction_data.pos.x - chunk.position.x) % 32
		var local_z = int(construction_data.pos.z - chunk.position.z) % 32
		var local_position = Vector3(local_x, construction_data.pos.y, local_z)
		
		# Pass the local position to the add_block function
		chunk.add_block(construction_data.id, local_position)
		print_debug("Block placed at local position: ", local_position, " in chunk at ", chunk.position, " with type ", construction_data.id)


# Respond to visibility changes of this node
func _on_build_menu_visibility_change(buildmenu):
	if !is_building:
		return
	# Set the visibility of the construction_ghost to match the building menu's visibility
	construction_ghost.visible = buildmenu.is_visible()
	is_building = buildmenu.is_visible()
	if not buildmenu.is_visible():
		General.is_allowed_to_shoot = true 
