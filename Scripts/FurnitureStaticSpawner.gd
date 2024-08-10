class_name FurnitureStaticSpawner
extends Node3D

# Dictionary to map the collider RID to the corresponding FurnitureStaticSrv
var collider_to_furniture: Dictionary = {}

# Reference to the World3D and Chunk
var world3d: World3D
var chunk: Chunk

# Array that contains the JSON data for furniture to be spawned
var furniture_json_list: Array = []:
	set(value):
		furniture_json_list = value
		_spawn_all_furniture()

# Initialize with reference to the chunk
func _init(mychunk: Chunk) -> void:
	chunk = mychunk

func _ready():
	world3d = get_world_3d()

# Function to spawn a FurnitureStaticSrv at a given position with given furniture data
func spawn_furniture(furniture_data: Dictionary) -> FurnitureStaticSrv:
	var myposition: Vector3 = furniture_data.pos
	var new_furniture = FurnitureStaticSrv.new(myposition, furniture_data.json, world3d)
	
	# Add the collider to the dictionary
	collider_to_furniture[new_furniture.collider] = new_furniture
	
	# Add the furniture to the scene tree
	add_child(new_furniture)
	
	return new_furniture

# Function to remove a furniture instance and clean up the tracking data
func remove_furniture(furniture: FurnitureStaticSrv):
	if is_instance_valid(furniture):
		# Remove the furniture from the dictionary
		collider_to_furniture.erase(furniture.collider)
		
		# Queue the furniture for deletion
		furniture.queue_free()

# Function to remove all furniture instances
func remove_all_furniture():
	for furniture in collider_to_furniture.values():
		remove_furniture(furniture)

# Function to get a FurnitureStaticSrv instance by its collider RID
func get_furniture_by_collider(collider: RID) -> FurnitureStaticSrv:
	if collider_to_furniture.has(collider):
		return collider_to_furniture[collider]
	return null

# Function to save the data of all spawned furniture
func get_furniture_data() -> Array:
	var furniture_data: Array = []
	for furniture in collider_to_furniture.values():
		if is_instance_valid(furniture):
			furniture_data.append(furniture.get_data().duplicate())
	return furniture_data

# Function to load and spawn furniture from saved data
func load_furniture_from_data(furniture_data_array: Array):
	furniture_json_list = furniture_data_array  # This will automatically trigger spawning

# Internal function to spawn all furniture in the list
func _spawn_all_furniture():
	for furniture_data in furniture_json_list:
		spawn_furniture(furniture_data)
