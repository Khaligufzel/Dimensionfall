extends Control



func _on_return_button_button_up():
	Helper.reset()
	get_tree().change_scene_to_file("res://scene_selector.tscn")
