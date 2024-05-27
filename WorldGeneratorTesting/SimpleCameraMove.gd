extends CharacterBody2D

# Speed of the character
@export var speed : float = 2000.0

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	var input_dir = Input.get_vector("left", "right", "up", "down")
	velocity = input_dir.normalized() * speed
	move_and_slide()


func _input(event):
	if event.is_action_pressed("zoom_in") :
		get_viewport().get_camera_2d().zoom.x += 0.1
		get_viewport().get_camera_2d().zoom.y += 0.1
			
	if event.is_action_pressed("zoom_out"):
		get_viewport().get_camera_2d().zoom.x -= 0.1
		get_viewport().get_camera_2d().zoom.y -= 0.1