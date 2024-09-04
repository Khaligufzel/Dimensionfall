extends MeshInstance3D

# Reference to the player node
@export var player: Node3D
@export var sceneCam: Camera3D
@export var buildmanager: Node3D

# Settings
var grid_size = 1.0
var y_offset = 0.0  # Offset relative to the player's position in the Y-axis
var build_range = 5.0  # Maximum build range from the player
var construction_data: Dictionary

signal construction_clicked(data: Dictionary)

func _ready():
	# Connect the signal for construction clicks to the build manager
	construction_clicked.connect(buildmanager.on_construction_clicked)


func _process(_delta):
	if !visible:
		return

	# Get the 3D position from the mouse's 2D position on the screen
	var mouse_position = get_mouse_3d_position()
	
	# Ensure the position stays within the build range from the player
	var x_diff = mouse_position.x - player.global_position.x
	var z_diff = mouse_position.z - player.global_position.z
	
	if x_diff > build_range:
		mouse_position.x = player.global_position.x + build_range
	elif x_diff < -build_range:
		mouse_position.x = player.global_position.x - build_range
		
	if z_diff > build_range:
		mouse_position.z = player.global_position.z + build_range
	elif z_diff < -build_range:
		mouse_position.z = player.global_position.z - build_range
	
	# Snap the position to the grid
	var snapped_x = round(mouse_position.x / grid_size) * grid_size
	var snapped_z = round(mouse_position.z / grid_size) * grid_size
	var snapped_y = round(mouse_position.y / grid_size) * grid_size
	
	# Update the position of the constructionghost
	global_transform.origin = Vector3(snapped_x, snapped_y, snapped_z)


# Calculate the 3D position based on the mouse's 2D position and the player's Y offset
func get_mouse_3d_position() -> Vector3:
	var mouse_position_2d = get_viewport().get_mouse_position()
	var plane = Plane(Vector3.UP, player.global_position.y + y_offset)
	var ray_origin = sceneCam.project_ray_origin(mouse_position_2d)
	var ray_direction = sceneCam.project_ray_normal(mouse_position_2d)
	var mouse_position = ray_origin + ray_direction * sceneCam.global_transform.origin.distance_to(plane.project(ray_origin))
	
	return Vector3(mouse_position.x, player.global_position.y + y_offset, mouse_position.z)


func _input(event):
	if !visible:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		construction_data = {"pos": global_transform.origin, "id": "concrete_00"}
		construction_clicked.emit(construction_data)
