extends MeshInstance3D

# Reference to the player node
@export var player: Node3D
@export var sceneCam: Camera3D
@export var buildmanager: Node3D

# Settings
var grid_size = 1.0
var y_offset = 0.0  # This is the y-coordinate offset relative to the player's position
var build_range = 5.0  # Maximum build range from the player
var construction_data: Dictionary

signal construction_clicked(data: Dictionary)

func _ready():
	construction_clicked.connect(buildmanager.on_construction_clicked)


func _process(_delta):
	if !visible:
		return

	# Project the mouse position onto the ground plane at the player's Y position
	var mouse_position_2d = get_viewport().get_mouse_position()
	var plane = Plane(Vector3.UP, player.global_position.y + y_offset)
	var mouse_position = sceneCam.project_ray_origin(mouse_position_2d) + sceneCam.project_ray_normal(mouse_position_2d) * sceneCam.global_transform.origin.distance_to(plane.project(sceneCam.project_ray_origin(mouse_position_2d)))

	# Calculate the position relative to the player
	var raw_position = Vector3(
		mouse_position.x,
		player.global_position.y + y_offset,
		mouse_position.z
	)
	
	# Ensure the position stays within the build range from the player
	var x_diff = raw_position.x - player.global_position.x
	var z_diff = raw_position.z - player.global_position.z
	
	if x_diff > build_range:
		raw_position.x = player.global_position.x + build_range
	elif x_diff < -build_range:
		raw_position.x = player.global_position.x - build_range
		
	if z_diff > build_range:
		raw_position.z = player.global_position.z + build_range
	elif z_diff < -build_range:
		raw_position.z = player.global_position.z - build_range
	
	# Snap the position to the grid
	var snapped_x = round(raw_position.x / grid_size) * grid_size
	var snapped_z = round(raw_position.z / grid_size) * grid_size
	var snapped_y = round(raw_position.y / grid_size) * grid_size
	
	# Update the position of the constructionghost
	global_transform.origin = Vector3(snapped_x, snapped_y, snapped_z)



func _input(event):
	if !visible:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		construction_data = {"pos": global_transform.origin, "id": "concrete_00"}
		construction_clicked.emit(construction_data)
