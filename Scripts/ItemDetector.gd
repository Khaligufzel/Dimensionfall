extends Area3D

@export var playernode: CharacterBody3D
var areas_in_proximity = {}  # Dictionary to track areas and their proximity status

# Called when the node is added to the scene.
# Enables the processing of the _process function.
func _ready():
	set_process(true)  # Enable processing

# Called every frame to continuously check for obstacles between the playernode and the areas in proximity.
func _process(_delta):
	for area in areas_in_proximity.keys():
		if areas_in_proximity[area]:  # If previously in proximity
			if not is_clear_path_to_area(area):
				# Obstacle appeared, emit exit proximity signal
				Helper.signal_broker.container_exited_proximity.emit(area.get_owner())
				areas_in_proximity[area] = false
		else:  # If previously not in proximity
			if is_clear_path_to_area(area):
				# Path is clear, emit enter proximity signal
				Helper.signal_broker.container_entered_proximity.emit(area.get_owner())
				areas_in_proximity[area] = true

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
	var player_position = playernode.global_transform.origin
	var area_position = area.global_transform.origin

	# Create a PhysicsRayQueryParameters3D object
	var query = PhysicsRayQueryParameters3D.new()
	query.from = player_position
	query.to = area_position
	query.exclude = [self, playernode, area]  # Exclude the area, playernode, and self from the raycast

	# Perform the raycast
	var space_state = get_world_3d().direct_space_state
	var result = space_state.intersect_ray(query)

	if result.size() != 0:  # Check if the result dictionary is not empty
		# Check if the hit object is an ancestor of the area
		var collider = result.collider
		if collider.is_ancestor_of(area):
			return true
		return false
	else:
		# No hit means there is a clear path
		return true
