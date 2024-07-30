class_name Detection
extends Node3D

var playerCol: Node3D
var mob: CharacterBody3D # The mob that we want to enable detection for
var spotted_player: CharacterBody3D
var state_nodes: Array # The state nodes i.e. MobAttack, MobFollow, MobIdle

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
	for node in state_nodes:
		player_spotted.connect(node._on_detection_player_spotted)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass
	
	#3d
#	queue_redraw()


func _physics_process(_delta):
	var space_state = get_world_3d().direct_space_state
	# TO-DO Change playerCol to group of players
	var playerInstance: CharacterBody3D = get_tree().get_first_node_in_group("Players")
	if !playerInstance:
		return
	var query = PhysicsRayQueryParameters3D.create(global_position, playerInstance.global_position, int(pow(2, 1-1) + pow(2, 3-1)),[self])

	var result = space_state.intersect_ray(query)
	
	if result:
		
		if result.collider.is_in_group("Players") && Vector3(global_position).distance_to(get_tree().get_first_node_in_group("Players").global_position) <= sightRange:
			spotted_player = result.collider
			player_spotted.emit(spotted_player)

	
