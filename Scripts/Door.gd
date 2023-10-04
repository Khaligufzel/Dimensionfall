extends Node2D

var is_locked = false
var is_open = false

var is_NS = true

@export var sprite : NodePath

@export var open_NS : Texture2D
@export var closed_NS: Texture2D

@export var open_WE : Texture2D
@export var closed_WE : Texture2D


# Called when the node enters the scene tree for the first time.
func _ready():
	var space_state = get_world_2d().direct_space_state
	# TO-DO Change playerCol to group of players
	var query = PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2(-5, 0), pow(2, 3-1),[self])
	var result = space_state.intersect_ray(query)
	
	if result:
		is_NS = false
		get_node(sprite).texture = closed_WE

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func interact():
	print("Interacting with a door")
	if !is_open:
		open()
	else:
		close()
	

func try_to_unlock():
	pass
	
func open():
	pass
	
func close():
	pass
