extends Node3D

@export var playerCol: Node3D
@export var stats: NodePath

signal player_spotted

var sightRange
var senseRange
var hearingRange
var melee_range


# Called when the node enters the scene tree for the first time.
func _ready():
	sightRange = get_node(stats).sightRange
	senseRange = get_node(stats).senseRange
	hearingRange = get_node(stats).hearingRange


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
	
	#3d
#	queue_redraw()


func _physics_process(delta):
	var space_state = get_world_3d().direct_space_state
	# TO-DO Change playerCol to group of players
	var playerInstance: CharacterBody3D = get_tree().get_first_node_in_group("Players")
	if !playerInstance:
		return
	var query = PhysicsRayQueryParameters3D.create(global_position, playerInstance.global_position, pow(2, 1-1) + pow(2, 3-1),[self])

	var result = space_state.intersect_ray(query)
	
	if result:
		
		if result.collider.is_in_group("Players") && Vector3(global_position).distance_to(get_tree().get_first_node_in_group("Players").global_position) <= sightRange:
			player_spotted.emit(result.collider)

	
