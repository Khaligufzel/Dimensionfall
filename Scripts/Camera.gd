extends Camera3D

	
func _input(event):
	if event.is_action_pressed("zoom_in"):
		size -= 2
		
	if event.is_action_pressed("zoom_out"):
		size += 2
