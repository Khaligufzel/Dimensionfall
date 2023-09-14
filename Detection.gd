extends Node2D

@export var player: Node2D


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _physics_process(delta):
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, (global_position - player.global_position).normalized() * 100, pow(2, 1-1) + pow(2, 3-1),[self])

	var result = space_state.intersect_ray(query)
	
	if result:
		print("Hit at point: ", result.collider)
		
	#print("Player: ", player.global_position)
	
