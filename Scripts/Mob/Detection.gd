class_name Detection
extends Node3D

var playerCol: Node3D
var mob: CharacterBody3D # The mob that we want to enable detection for
var spotted_target: CharacterBody3D
var state_machine: StateMachine
var can_detect: bool = true # Control detection state
# Add a Timer node to control detection intervals
@onready var detection_timer: Timer = Timer.new()

signal target_spotted

var sightRange
var senseRange
var hearingRange
var melee_range

# Called when the node enters the scene tree for the first time.
func _ready():
	sightRange = mob.sight_range
	senseRange = mob.sense_range
	hearingRange = mob.hearing_range
	
	# Configure the detection timer
	detection_timer.wait_time = 1.0  # Timer runs every 1 second
	detection_timer.one_shot = false  # Repeat the timer
	detection_timer.timeout.connect(_on_detection_timer_timeout)  # Connect the timer's timeout signal
	add_child(detection_timer)  # Add the timer to the scene tree
	detection_timer.start()  # Start the timer
	
	# Connect the detection signal to the state nodes in the statemachine
	for node in state_machine.states.values():
		target_spotted.connect(node._on_detection_target_spotted)


# Monitors the physics space each frame to detect nearby players using raycasting.
# - Sets up a raycast from the mob's current position toward the player's position.
# - If the raycast detects a player and the player is within `sightRange`, 
#   the player is assigned to `spotted_target`, and the `target_spotted` signal is emitted.
func _physics_process(_delta):
	# Exit early if detection is disabled
	if not can_detect:
		return
	if mob.terminated:
		return
	var space_state = get_world_3d().direct_space_state
	# TO-DO Change playerCol to group of players
	var playerInstance: CharacterBody3D = Helper.player
	if !playerInstance:
		return
	var query = PhysicsRayQueryParameters3D.create(global_position, playerInstance.global_position, int(pow(2, 1-1) + pow(2, 3-1)),[self])

	var result = space_state.intersect_ray(query)
	
	if result and result.collider:
		
		if result.collider.is_in_group("Players") && Vector3(global_position).distance_to(get_tree().get_first_node_in_group("Players").global_position) <= sightRange:
			spotted_target = result.collider
			can_detect = false  # Disable detection until re-enabled elsewhere
			target_spotted.emit(spotted_target)


# Callback for the detection timer's timeout signal
func _on_detection_timer_timeout() -> void:
	can_detect = true # Re-enable detection when the timer runs out


# Function to select targets for detection.
# Includes the player, all mobs, and checks if a mob is hated by the current mob.
func select_targets() -> Array[CharacterBody3D]:
	# Initialize the targets array
	var targets: Array[CharacterBody3D] = []

	# Always add the player instance as a target
	var player_instance: CharacterBody3D = Helper.player
	if player_instance:
		targets.append(player_instance)

	# Get all mobs from the "mobs" group
	var mobs: Array = get_tree().get_nodes_in_group("mobs")
	for mymob in mobs:
		if mymob is CharacterBody3D:  # Ensure the mob is of the correct type
			# Add the mob if its ID is in the "hates_mobs" list of the current mob
			if mob.hates_mobs.has(mymob.rmob.id):
				targets.append(mymob)

	# Return the list of targets
	return targets


# Function to get visible targets from a list of potential targets.
# Performs an intersect_ray query for each target and checks if it's within sight range.
func get_visible_targets(potential_targets: Array[CharacterBody3D]) -> Array[CharacterBody3D]:
	# Initialize an array to store visible targets
	var visible_targets: Array[CharacterBody3D] = []

	# Get the direct space state for raycasting
	var space_state = get_world_3d().direct_space_state

	# Iterate through each target in the potential_targets array
	for target in potential_targets:
		# Skip if the target is the mob itself or null
		if target == mob or target == null:
			continue

		# Check if the target is within sight range
		if global_position.distance_to(target.global_position) > sightRange:
			continue  # Skip targets out of sight range

		# Perform the raycast query
		var query = PhysicsRayQueryParameters3D.create(
			global_position,  # Ray start point (mob's position)
			target.global_position,  # Ray end point (target's position)
			3,  # Layer mask for layer 1 and layer 2
			[self]  # Exclude the mob itself from the query
		)

		var result = space_state.intersect_ray(query)

		# If the ray hits the target and the distance is within sight range, add it to visible_targets
		if result and result.collider == target:
			visible_targets.append(target)

	return visible_targets
