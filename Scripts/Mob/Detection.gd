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
