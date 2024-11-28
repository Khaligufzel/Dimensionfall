extends Node3D

# Contains the navigationmap for each chunk, used to give mobs the proper navigationmap
# When crossing chunk boundary
var chunk_navigation_maps: Dictionary = {}
var test_map_name: String # Used for testing in the test_environment

# Overmap data
var position_coord: Vector2 = Vector2(0, 0)
var mapseed: int # Is generated once per game. Defines the unique map!

# Dictionary to store meshes for each block ID
var navigationmap: RID

# Helper scripts
const json_Helper_Class = preload("res://Scripts/Helper/json_helper.gd")
const save_Helper_Class = preload("res://Scripts/Helper/save_helper.gd")
const signal_broker_Class = preload("res://Scripts/Helper/signal_broker.gd")
const task_manager_Class = preload("res://Scripts/Helper/task_manager.gd")
const map_manager_Class = preload("res://Scripts/Helper/map_manager.gd")
const overmap_manager_Class = preload("res://Scripts/Helper/overmap_manager.gd")
const quest_helper_Class = preload("res://Scripts/Helper/quest_helper.gd")
const time_helper_Class = preload("res://Scripts/Helper/time_helper.gd")

var json_helper: RefCounted = null
var time_helper: Node = null
var save_helper: Node = null
var signal_broker: Node = null
var task_manager: Node = null
var map_manager: Node = null
var overmap_manager: Node = null
var quest_helper: Node = null

# Called when the node enters the scene tree for the first time.
func _ready():
	initialize_helpers()
	add_child(save_helper)
	add_child(quest_helper)
	add_child(time_helper)
	add_child(overmap_manager)
	signal_broker.game_ended.connect(_on_game_ended)


func initialize_helpers():
	json_helper = json_Helper_Class.new()
	save_helper = save_Helper_Class.new()
	signal_broker = signal_broker_Class.new()
	task_manager = task_manager_Class.new()
	map_manager = map_manager_Class.new()
	overmap_manager = overmap_manager_Class.new()
	quest_helper = quest_helper_Class.new()
	time_helper = time_helper_Class.new()


func _process(_delta: float) -> void:
	# task_manager can't _process on it's own so we call it from here
	task_manager._process(_delta)


# Called when the game is over and everything will need to be reset to default
func reset():
	overmap_manager.loaded_chunk_data = {"chunks": {}}
	mapseed = 0
	position_coord = Vector2(0, 0)
	save_helper.current_save_folder = ""
	chunk_navigation_maps.clear()
	ItemManager.player_equipment.reset_to_default()


# When the player quits without saving (i.e. game over)
func exit_game():
	Helper.overmap_manager.player.axis_lock_linear_y = true # Stop vertical movement
	Helper.map_manager.level_generator.unload_all_chunks()
	await Helper.map_manager.level_generator.all_chunks_unloaded
	# Devides the loaded_chunk_data.chunks into segments and saves them to disk
	Helper.overmap_manager.unload_all_remaining_segments()
	Helper.signal_broker.game_ended.emit()
	get_tree().change_scene_to_file("res://scene_selector.tscn")


# When the player saves and quits (i.e. return to main menu)
func save_and_exit_game():
	Helper.save_helper.save_game()
	exit_game()


#Level_name is a filename in /mods/core/maps
#global_pos is the absolute position on the overmap
#see overmap.gd for how global_pos is used there
func initiate_game() -> void:
	chunk_navigation_maps.clear()
	get_tree().change_scene_to_file.bind("res://level_generation.tscn").call_deferred()


# Function to draw a line in the 3D space
func line(pos1: Vector3, pos2: Vector3, color = Color.WHITE_SMOKE) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var immediate_mesh := ImmediateMesh.new()
	var material := ORMMaterial3D.new()
	
	mesh_instance.mesh = immediate_mesh
	mesh_instance.cast_shadow = mesh_instance.SHADOW_CASTING_SETTING_OFF

	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	immediate_mesh.surface_add_vertex(pos1)
	immediate_mesh.surface_add_vertex(pos2)
	immediate_mesh.surface_end()
	
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	
	get_tree().get_root().add_child(mesh_instance)

	return mesh_instance

# Function to perform a raycast from the mouse position
func raycast_from_mouse(m_pos, collision_mask) -> Dictionary:
	var camera = get_tree().get_first_node_in_group("Camera")
	var ray_start = camera.project_ray_origin(m_pos)
	var ray_end = ray_start + camera.project_ray_normal(m_pos) * 1000
	var space_state = get_world_3d().direct_space_state

	if space_state:
		var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end, collision_mask)
		query.collide_with_areas = true
		return space_state.intersect_ray(query)
	return {}

# Function to perform a raycast between two points
func raycast(start_position: Vector3, end_position: Vector3, layer: int, object_to_ignore):
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(start_position, end_position, layer, object_to_ignore)
	return space_state.intersect_ray(query)


# Called when a chunk emits its loaded signal. We save the navigationmap RID to a dictionary
# This can then be used by navigationagents that are present on the chunk
func on_chunk_loaded(data: Dictionary):
	# `mypos` is a Vector3, we only use the x and z since y is constant 0
	var chunk_position = Vector2(data["mypos"].x, data["mypos"].z)
	chunk_navigation_maps[chunk_position] = data["map"]


# Called when a chunk emits its unloaded signal. We remove the chunk from the navigationmaps
# Dictionary. The chunk is responsible for unloading the navigationmap itself
func on_chunk_unloaded(data: Dictionary):
	var chunk_position = Vector2(data["mypos"].x, data["mypos"].z)
	if chunk_navigation_maps.has(chunk_position):
		var navigation_map_id = chunk_navigation_maps[chunk_position]
		NavigationServer3D.free_rid(navigation_map_id)
		chunk_navigation_maps.erase(chunk_position)


# When the user exits the game and returns to the main menu
func _on_game_ended():
	reset() # Resets the game, as though you re-started it


# Utility function to clear all children in a node
func free_all_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()
