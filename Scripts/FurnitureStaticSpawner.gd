class_name FurnitureStaticSpawner
extends Node3D

# Array to keep track of all spawned furniture instances
var spawned_furniture: Array = []

# Dictionary to map the collider RID to the corresponding FurnitureStaticSrv
var collider_to_furniture: Dictionary = {}
var world3d: World3D
var chunk: Chunk # The chunk we are spawning for


func _init(mychunk: Chunk) -> void:
	chunk = mychunk

func _ready():
	world3d = get_world_3d()

# Function to spawn a FurnitureStaticSrv at a given position with given furniture data
func spawn_furniture(myposition: Vector3, furniture_data: Dictionary) -> FurnitureStaticSrv:
	var new_furniture = FurnitureStaticSrv.new(myposition, furniture_data, world3d)
	
	# Add the new furniture to the tracking array
	spawned_furniture.append(new_furniture)
	
	# Add the collider to the dictionary
	collider_to_furniture[new_furniture.collider] = new_furniture
	
	# Add the furniture to the scene tree
	add_child(new_furniture)
	
	return new_furniture

# Function to remove a furniture instance and clean up the tracking data
func remove_furniture(furniture: FurnitureStaticSrv):
	if is_instance_valid(furniture):
		# Remove from the tracking array and dictionary
		spawned_furniture.erase(furniture)
		collider_to_furniture.erase(furniture.collider)
		
		# Queue the furniture for deletion
		furniture.queue_free()

# Function to remove all furniture instances
func remove_all_furniture():
	for furniture in spawned_furniture:
		remove_furniture(furniture)

# Function to get a FurnitureStaticSrv instance by its collider RID
func get_furniture_by_collider(collider: RID) -> FurnitureStaticSrv:
	if collider_to_furniture.has(collider):
		return collider_to_furniture[collider]
	return null

# Function to save the data of all spawned furniture
func get_furniture_data() -> Array:
	var furniture_data: Array = []
	for furniture in spawned_furniture:
		if is_instance_valid(furniture):
			furniture_data.append(furniture.get_data().duplicate())
	return furniture_data

# Function to load and spawn furniture from saved data
func load_furniture_from_data(furniture_data_array: Array):
	for furniture_data in furniture_data_array:
		var furniture_pos = Vector3(
			furniture_data.global_position_x, 
			furniture_data.global_position_y, 
			furniture_data.global_position_z
		)
		spawn_furniture(furniture_pos, furniture_data)
