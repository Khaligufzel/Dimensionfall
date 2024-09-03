extends Area3D

@export var playernode: CharacterBody3D
var areas_in_proximity = {}  # Dictionary to track areas and their proximity status
var bodies_in_proximity = {}  # Dictionary to track bodies and their proximity status

# Called when the node is added to the scene.
# Enables the processing of the _process function.
func _ready():
	set_process(true)  # Enable processing

# Called every frame to continuously check for obstacles between the playernode and the areas in proximity.
func _process(_delta):
	for area in areas_in_proximity.keys():
		if areas_in_proximity[area]:  # If previously in proximity
			if not is_clear_path_to_area(area) and is_instance_valid(area):
				# Obstacle appeared, emit exit proximity signal
				Helper.signal_broker.container_exited_proximity.emit(area.get_owner())
				areas_in_proximity[area] = false
		else:  # If previously not in proximity
			if is_clear_path_to_area(area):
				# Path is clear, emit enter proximity signal
				Helper.signal_broker.container_entered_proximity.emit(area.get_owner())
				areas_in_proximity[area] = true

	# Check bodies in proximity
	for body_rid in bodies_in_proximity.keys():
		if bodies_in_proximity[body_rid]:
			if not is_clear_path_to_body(body_rid):
				Helper.signal_broker.body_exited_item_detector.emit(body_rid)
				bodies_in_proximity[body_rid] = false
		else:
			if is_clear_path_to_body(body_rid):
				Helper.signal_broker.body_entered_item_detector.emit(body_rid)
				bodies_in_proximity[body_rid] = true

# Called when an area enters the Area3D.
# Adds the area to the dictionary and checks initial proximity status.
func _on_area_entered(area):
	if area.get_owner().is_in_group("Containers"):
		# Add area to the dictionary and check initial proximity status
		areas_in_proximity[area] = is_clear_path_to_area(area)
		if areas_in_proximity[area]:
			Helper.signal_broker.container_entered_proximity.emit(area.get_owner())

# Called when an area exits the Area3D.
# Removes the area from the dictionary and emits exit proximity signal if necessary.
func _on_area_exited(area):
	var areaowner = area.get_owner()
	if areaowner:
		if areaowner.is_in_group("Containers"):
			# Remove area from the dictionary and emit exit proximity signal if necessary
			if areas_in_proximity.has(area) and areas_in_proximity[area]:
				Helper.signal_broker.container_exited_proximity.emit(area.get_owner())
			areas_in_proximity.erase(area)

# Checks if there is a clear path between the playernode and the specified area.
# Returns true if there is a clear path, false otherwise.
func is_clear_path_to_area(area) -> bool:
	if not is_instance_valid(area):
		# If the area is no longer valid, return false
		areas_in_proximity[area] = false
		return false

	var player_position = playernode.global_transform.origin
	var area_position = area.global_transform.origin

	# Use the reusable raycast function
	var result = cast_ray_between_points(player_position, area_position, [self, playernode, area])

	if result.size() != 0:  # Check if the result dictionary is not empty
		# Check if the hit object is an ancestor of the area
		var collider = result.collider
		if collider and not collider is RID and collider.is_ancestor_of(area):
			return true
		return false
	else:
		# No hit means there is a clear path
		return true

# Checks if there is an obstacle in the way of the body that entered
func is_clear_path_to_body(body_rid: RID) -> bool:
	# Get the transform of the body using the body_rid
	var body_transform = PhysicsServer3D.body_get_state(body_rid, PhysicsServer3D.BODY_STATE_TRANSFORM)
	if not body_transform:
		return false
	var body_position = body_transform.origin
	
	var player_position = playernode.global_transform.origin

	# Use the reusable raycast function
	var result = cast_ray_between_points(player_position, body_position, [self, playernode])

	if result.size() != 0:
		var collider = result.rid
		# Check if the hit object is the same body
		if collider is RID and collider == body_rid:
			return true
		return false
	else:
		return true

# When a collisionshape enters this area. Most likely a collider of a FurnitureStaticSrv
func _on_body_shape_entered(body_rid: RID, _body: Node3D, _body_shape_index: int, _local_shape_index: int) -> void:
	bodies_in_proximity[body_rid] = is_clear_path_to_body(body_rid)
	if bodies_in_proximity[body_rid]:
		Helper.signal_broker.body_entered_item_detector.emit(body_rid)


# When a collisionshape exits this area. Most likely a collider of a FurnitureStaticSrv
func _on_body_shape_exited(body_rid: RID, _body: Node3D, _body_shape_index: int, _local_shape_index: int) -> void:
	if bodies_in_proximity.has(body_rid) and bodies_in_proximity[body_rid]:
		Helper.signal_broker.body_exited_item_detector.emit(body_rid)
	bodies_in_proximity.erase(body_rid)


# Cast a ray between two points and return the result
# Parameters:
# - from: The starting point of the ray (Vector3)
# - to: The ending point of the ray (Vector3)
# - exclude_nodes: An array of nodes (or RIDs) to exclude from the raycast (Array)
# Returns: A Dictionary with the raycast result, or an empty dictionary if nothing is hit.
func cast_ray_between_points(from: Vector3, to: Vector3, exclude_nodes: Array) -> Dictionary:
	var query = PhysicsRayQueryParameters3D.new()
	query.from = from
	query.to = to
	query.exclude = exclude_nodes

	var space_state = get_world_3d().direct_space_state
	return space_state.intersect_ray(query)
