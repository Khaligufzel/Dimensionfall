extends Node

var item_id_to_assign = 0



# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
	
func assign_id():
	item_id_to_assign += 1
	return item_id_to_assign
