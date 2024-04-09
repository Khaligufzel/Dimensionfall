extends MeshInstance3D

# Reference to the player node
@export var player: Node3D
@export var sceneCam: Camera3D
@export var buildmanager: Node3D

# Settings
var grid_size = 1.0
var y_offset = 1.0  # This is the y-coordinate offset relative to the player's position
var build_range = 5.0  # Maximum build range from the player
var construction_data: Dictionary

signal construction_clicked(data: Dictionary)

func _ready():
	construction_clicked.connect(buildmanager.on_construction_clicked)


func _process(_delta):
	if !visible:
		return
	var mouse_position = sceneCam.project_position(get_viewport().get_mouse_position(), sceneCam.global_transform.origin.z)
	
	# Calculate the raw x, y, and z positions
	var raw_x = mouse_position.x
	var raw_z = mouse_position.z
	var raw_y = player.global_position.y + y_offset  # Adjust y by a fixed offset
	
	# Limit x and z to be within the build range from the player before snapping
	var x_diff = raw_x - player.global_position.x
	var z_diff = raw_z - player.global_position.z
	
	if x_diff > build_range:
		raw_x = player.global_position.x + build_range
	elif x_diff < -build_range:
		raw_x = player.global_position.x - build_range
		
	if z_diff > build_range:
		raw_z = player.global_position.z + build_range
	elif z_diff < -build_range:
		raw_z = player.global_position.z - build_range
	
	# Snap the adjusted positions to the grid
	var snapped_x = floor(raw_x / grid_size) * grid_size
	var snapped_z = floor(raw_z / grid_size) * grid_size
	var snapped_y = floor(raw_y / grid_size) * grid_size  # Snap y-position
	
	# Assign the snapped positions
	var snapped_position = Vector3(snapped_x, snapped_y, snapped_z)
	global_transform.origin = snapped_position


func _input(event):
	if !visible:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		construction_data = {"pos": global_transform.origin, "id": "concrete_00"}
		emit_signal("construction_clicked", construction_data)
		#construction_clicked.emit()
