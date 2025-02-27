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
# - If the raycast detects a player and the player is within `sightRange`, 
#   the player is assigned to `spotted_target`, and the `target_spotted` signal is emitted.
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


# Function to select targets for detection.
# Includes the player, all mobs, and checks if a mob is hated by the current mob.
func select_targets() -> Array[CharacterBody3D]:
	# Initialize the targets array
	var targets: Array[CharacterBody3D] = []

	# Always add the player instance as a target
	#var player_instance: CharacterBody3D = Helper.player
	var players = get_tree().get_nodes_in_group("Players") 
	if players.size() > 0:
		targets.append(players[0])

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
	# Step 1: Get the list of potential targets
	var potential_targets = select_targets()
	
	# Step 2: Filter the list to only include visible targets
	var visible_targets = get_visible_targets(potential_targets)
	
	# Step 3: Find and return the closest target from the visible targets
	return find_closest_target(visible_targets)
