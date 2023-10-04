extends Node3D

@export var animation_player : AnimationPlayer

var is_closed : bool = true

# Called when the node enters the scene tree for the first time.
func _ready():
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func interact():
	
	if is_closed && !animation_player.is_playing():
		print("opening")
		animation_player.play("door_animation")
		is_closed = false
	elif !is_closed && !animation_player.is_playing():
		print("closing")
		animation_player.play_backwards("door_animation")
		is_closed = true
	

func try_to_unlock():
	pass
	
func open():
	pass
	
func close():
	pass
