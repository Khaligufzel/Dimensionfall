extends Node2D

@export var inventory: NodePath


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
	

func get_items():
	return get_node(inventory).get_children()
