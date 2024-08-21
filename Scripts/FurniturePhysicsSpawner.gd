class_name FurniturePhysicsSpawner
extends Node3D

# Dictionary to map the collider RID to the corresponding FurniturePhysicsSrv
var collider_to_furniture: Dictionary = {}

# Reference to the World3D and Chunk
var world3d: World3D
var chunk: Chunk

# Array that contains the JSON data for furniture to be spawned
var furniture_json_list: Array = []:
	set(value):
		furniture_json_list = value
		await Helper.task_manager.create_task(_spawn_all_furniture).completed
		# INFO Important to connect the signals outside the task_manager.create_task
		# since the furniture will start engaging with the game world when they are connected
		# If they are connected inside task_manager.create_task, there will be a conflict in threads
		for furniture in collider_to_furniture.values():
			furniture.connect_signals()


# Initialize with reference to the chunk
func _init(mychunk: Chunk) -> void:
	chunk = mychunk

func _ready():
	world3d = get_world_3d()
	Helper.signal_broker.player_interacted.connect(_on_player_interacted)
	Helper.signal_broker.body_entered_item_detector.connect(_on_body_entered_item_detector)
	Helper.signal_broker.body_exited_item_detector.connect(_on_body_exited_item_detector)
	Helper.signal_broker.bullet_hit.connect(_on_bullet_hit)
	Helper.signal_broker.melee_attacked_rid.connect(_on_melee_attacked_rid)
	Helper.signal_broker.furniture_changed_chunk.connect(_on_chunk_changed)


# Function to spawn a FurniturePhysicsSrv at a given position with given furniture data
func spawn_furniture(furniture_data: Dictionary) -> void:
	# Get the position using the helper function
	var myposition: Vector3
	var new_furniture: FurniturePhysicsSrv
	
	# Only new furniture has the json property
	if furniture_data.has("json"):
		myposition = chunk.mypos + get_furniture_position_from_mapdata(furniture_data)
		new_furniture = FurniturePhysicsSrv.new(myposition, furniture_data.json, world3d)
	else: # Previously saved furniture does not have the json property
		myposition = get_furniture_position_from_mapdata(furniture_data)
		new_furniture = FurniturePhysicsSrv.new(myposition, furniture_data, world3d)
	
	new_furniture.about_to_be_destroyed.connect(_on_furniture_about_to_be_destroyed)
	
	# Add the collider to the dictionary
	collider_to_furniture[new_furniture.collider] = new_furniture


# Helper function to get the position of the furniture
func get_furniture_position_from_mapdata(furniture_data: Dictionary) -> Vector3:
	# Check if the furniture_data has the "pos" property (for new furniture)
	if furniture_data.has("pos"):
		return furniture_data.pos
	# Otherwise, calculate the position from "global_position_x", "global_position_y", "global_position_z"
	elif furniture_data.has("global_position_x") and furniture_data.has("global_position_y") and furniture_data.has("global_position_z"):
		return Vector3(
			furniture_data.global_position_x,
			furniture_data.global_position_y,
			furniture_data.global_position_z
		)
	# Default to (0,0,0) if no position data is available (fallback)
	return Vector3.ZERO


# Function to remove a furniture instance and clean up the tracking data
func remove_furniture(furniture: FurniturePhysicsSrv) -> void:
	if is_instance_valid(furniture):
		# Remove the furniture from the dictionary
		collider_to_furniture.erase(furniture.collider)
		furniture.free_resources()
		# Queue the furniture for deletion
		furniture.queue_free()


func _on_furniture_about_to_be_destroyed(furniture: FurniturePhysicsSrv) -> void:
	# Remove the furniture from the dictionary
	collider_to_furniture.erase(furniture.collider)


# Function to remove all furniture instances
func remove_all_furniture() -> void:
	for furniture in collider_to_furniture.values():
		remove_furniture(furniture)


# Function to get a FurniturePhysicsSrv instance by its collider RID
func get_furniture_by_collider(collider: RID) -> FurniturePhysicsSrv:
	if collider_to_furniture.has(collider):
		return collider_to_furniture[collider]
	return null


# Function to save the data of all spawned furniture
func get_furniture_data() -> Array:
	var furniture_data: Array = []
	for furniture in collider_to_furniture.values():
		if is_instance_valid(furniture):
			furniture_data.append(furniture.get_data())
	return furniture_data


# Function to load and spawn furniture from saved data
func load_furniture_from_data(furniture_data_array: Array) -> void:
	furniture_json_list = furniture_data_array  # This will automatically trigger spawning


# Internal function to spawn all furniture in the list
func _spawn_all_furniture() -> void:
	for furniture_data in furniture_json_list:
		spawn_furniture(furniture_data)


# The player has interacted with some furniture. 
# Handle the interaction if the collider is in the dictionary
func _on_player_interacted(_pos: Vector3, collider: RID) -> void:
	if collider_to_furniture.has(collider):
		var furniturenode = collider_to_furniture[collider]
		if furniturenode.has_method("interact"):
			print("interacting with furniturenode")
			furniturenode.interact()


# Function to handle the event when a body enters the item detector
func _on_body_entered_item_detector(body_rid: RID) -> void:
	if collider_to_furniture.has(body_rid):
		# furniturenode is a FurniturePhysicsSrv but we need to cast it as a Node3D here
		# because that's what the signal will send
		var furniturenode: Node3D = collider_to_furniture[body_rid]
		if furniturenode.is_container():
			Helper.signal_broker.container_entered_proximity.emit(furniturenode)


# Function to handle the event when a body exits the item detector
func _on_body_exited_item_detector(body_rid: RID) -> void:
	if collider_to_furniture.has(body_rid):
		# furniturenode is a FurniturePhysicsSrv but we need to cast it as a Node3D here
		# because that's what the signal will send
		var furniturenode: Node3D = collider_to_furniture[body_rid]
		if furniturenode.is_container():
			Helper.signal_broker.container_exited_proximity.emit(furniturenode)


# A bullet has hit something. We check if one of the furnitures was hit and pass the attack
func _on_bullet_hit(body_rid: RID, attack: Dictionary) -> void:
	if collider_to_furniture.has(body_rid):
		print_debug("a furniture was hit by a bullet")
		var furniturenode: FurniturePhysicsSrv = collider_to_furniture[body_rid]
		if furniturenode.has_method("get_hit"):
			furniturenode.get_hit(attack)


# A bullet has hit something. We check if one of the furnitures was hit and pass the attack
func _on_melee_attacked_rid(body_rid: RID, attack: Dictionary) -> void:
	if collider_to_furniture.has(body_rid):
		print_debug("a furniture was attacked with melee")
		var furniturenode: FurniturePhysicsSrv = collider_to_furniture[body_rid]
		if furniturenode.has_method("get_hit"):
			furniturenode.get_hit(attack)


# Function to handle chunk changes in furniture. The furniture might be spawned
# by this furniturespawner or another one. We have to handle each case.
# furniture: The FurniturePhysicsSrv that crossed the chunk boundary
# new_chunk_pos: a vector2 with global chunk positions, like (-1,-1),(0,0) or (1,3)
func _on_chunk_changed(furniture: FurniturePhysicsSrv, new_chunk_pos: Vector2) -> void:
	# Separate the Vector2 into x and z coordinates
	var chunk_x = new_chunk_pos.x
	var chunk_z = new_chunk_pos.y
	
	# Multiply x and z coordinates by 32 to get the correct chunk position
	var x_pos = chunk_x * 32
	var z_pos = chunk_z * 32
	
	# Create a Vector3 with the x and z coordinates, y should be 0
	var calculated_chunk_pos = Vector3(x_pos, 0, z_pos)
	
	# Get the collider RID from the furniture
	var collider = furniture.collider
	
	# Case 1: The calculated_chunk_pos equals chunk.mypos and the collider is present in collider_to_furniture
	if calculated_chunk_pos == chunk.mypos and collider_to_furniture.has(collider):
		# Do nothing, everything is as expected
		print("Chunk position matches and furniture is already in the dictionary. No action needed.")
	
	# Case 2: The calculated_chunk_pos equals chunk.mypos and the collider is not present in collider_to_furniture
	elif calculated_chunk_pos == chunk.mypos and not collider_to_furniture.has(collider):
		# Add the furniture to collider_to_furniture
		collider_to_furniture[collider] = furniture
		print("Furniture added to collider_to_furniture as it moved into the current chunk.")

	# Case 3: The calculated_chunk_pos does not equal chunk.mypos and the collider is present in collider_to_furniture
	elif calculated_chunk_pos != chunk.mypos and collider_to_furniture.has(collider):
		# Remove the furniture from collider_to_furniture but do not destroy it
		collider_to_furniture.erase(collider)
		print("Furniture removed from collider_to_furniture as it moved out of the current chunk.")

	# Case 4: The calculated_chunk_pos does not equal chunk.mypos and the collider is not present in collider_to_furniture
	elif calculated_chunk_pos != chunk.mypos and not collider_to_furniture.has(collider):
		# Do nothing, everything is as expected
		print("Furniture is not in the current chunk and not in the dictionary. No action needed.")
