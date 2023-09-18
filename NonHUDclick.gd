extends Control


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_mouse_entered():
	General.is_mouse_outside_HUD = true


func _on_mouse_exited():
	General.is_mouse_outside_HUD = false
