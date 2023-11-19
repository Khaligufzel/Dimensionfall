extends Node3D


# Called when the node enters the scene tree for the first time.
func _ready():
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	for level in get_children():
		if level.global_position.y > get_tree().get_first_node_in_group("Players").global_position.y:
			level.visible = false
		else:
			level.visible = true
