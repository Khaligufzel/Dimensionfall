class_name Detection
extends Node3D

var playerCol: Node3D
var mob: CharacterBody3D # The mob that we want to enable detection for
var spotted_player: CharacterBody3D
var state_machine: StateMachine

signal player_spotted

var sightRange
var senseRange
var hearingRange
var melee_range

# Called when the node enters the scene tree for the first time.
func _ready():
	sightRange = mob.sight_range
	senseRange = mob.sense_range
	hearingRange = mob.hearing_range
	# Connect the detection signal to the state nodes in the statemachine
	for node in state_machine.states.values():
		player_spotted.connect(node._on_detection_player_spotted)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass


# Monitors the physics space each frame to detect nearby players using raycasting.
# - Sets up a raycast from the mob's current position toward the player's position.
# - If the raycast detects a player and the player is within `sightRange`, 
#   the player is assigned to `spotted_player`, and the `player_spotted` signal is emitted.
func _physics_process(_delta):
	if mob.terminated:
		return
	var space_state = get_world_3d().direct_space_state
	# TO-DO Change playerCol to group of players
	var playerInstance: CharacterBody3D = get_tree().get_first_node_in_group("Players")
	if !playerInstance:
		return
	var query = PhysicsRayQueryParameters3D.create(global_position, playerInstance.global_position, int(pow(2, 1-1) + pow(2, 3-1)),[self])

	var result = space_state.intersect_ray(query)
	
	if result and result.collider:
		
		if result.collider.is_in_group("Players") && Vector3(global_position).distance_to(get_tree().get_first_node_in_group("Players").global_position) <= sightRange:
			spotted_player = result.collider
			player_spotted.emit(spotted_player)

	
