class_name Detection
extends Node3D

var playerCol: Node3D
var mob: CharacterBody3D # The mob that we want to enable detection for
var spotted_target: CharacterBody3D # This mob's current target for combat
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
# - If the raycast detects an enemy (player or mob) and the enemy is within `sightRange`, 
#   the enemy is assigned to `spotted_target`, and the `target_spotted` signal is emitted.
func _physics_process(_delta):
	# Exit early if detection is disabled
	if not can_detect:
		return
	if mob.terminated:
		return
	
	if can_detect:
		var target = pick_target()
		if target:
			spotted_target = target
			target_spotted.emit(spotted_target)
			can_detect = false  # Disable detection temporarily


# Callback for the detection timer's timeout signal
func _on_detection_timer_timeout() -> void:
	can_detect = true # Re-enable detection when the timer runs out


# Function to get visible targets from a list of potential targets.
# Performs an intersect_ray query for each target and checks if it's within sight range.
# Helper function to check if a target is visible using raycasting
func _is_target_visible(target: CharacterBody3D) -> bool:
	# Skip if target is the mob itself or null
	if target == mob or target == null:
		return false
	
	# Check if the target is within sight range
	if global_position.distance_to(target.global_position) > sightRange:
		return false
	
	# Perform the raycast query
	var query = PhysicsRayQueryParameters3D.create(
		global_position,  # Ray start point (mob's position)
		target.global_position,  # Ray end point (target's position)
		(1 << 0) | (1 << 1) | (1 << 2), # Layer mask for layers 1 (player), 2 (mobs), and 3 (walls)
		[self]  # Exclude the mob itself from the query
	)

	var result = get_world_3d().direct_space_state.intersect_ray(query)

	# Return true if the ray hits the target
	return result and result.collider == target


# Function to get visible targets from a list of potential targets
func get_visible_targets(potential_targets: Array) -> Array[CharacterBody3D]:
	var visible_targets: Array[CharacterBody3D] = []
	
	# Check if the player is visible and add to targets if visible
	var players = get_tree().get_nodes_in_group("Players")
	if players.size() > 0:
		var player = players[0]
		if _is_target_visible(player):
			visible_targets.append(player)

	# Check visibility for mobs
	for target in potential_targets:
		if is_instance_valid(target) and _is_target_visible(target):
			visible_targets.append(target)

	return visible_targets


# Function to find the closest target from a list of potential targets
func find_closest_target(potential_targets: Array[CharacterBody3D]) -> CharacterBody3D:
	# Initialize variables to track the closest target and minimum distance
	var closest_target: CharacterBody3D = null
	var min_distance: float = INF  # Start with a very large distance

	# Iterate through the list of potential targets
	for target in potential_targets:
		# Skip if the target is the mob itself or null
		if target == mob or target == null:
			continue

		# Calculate the distance to the target
		var distance = global_position.distance_to(target.global_position)

		# If the distance is smaller than the current minimum, update the closest target
		if distance < min_distance:
			min_distance = distance
			closest_target = target

	return closest_target


# Function to pick the best target for the mob
# Combines target selection, visibility checks, and finding the closest target
func pick_target() -> CharacterBody3D:
	if not mob.target_manager:
		mob.target_manager = get_tree().get_first_node_in_group("target_manager")
		return
	# Step 1: Get the list of potential targets
	var potential_targets: Array = mob.target_manager.get_mobs_by_faction(mob.get_faction())
	
	# Step 2: Filter the list to only include visible targets
	var visible_targets = get_visible_targets(potential_targets)
	
	# Step 3: Find and return the closest target from the visible targets
	return find_closest_target(visible_targets)
