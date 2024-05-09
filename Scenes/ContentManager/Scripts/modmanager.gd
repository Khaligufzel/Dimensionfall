extends Control


func _on_back_button_button_up():
	get_tree().change_scene_to_file("res://scene_selector.tscn")


func _on_mod_maintenance_button_button_up():
	get_tree().change_scene_to_file("res://Scenes/ContentManager/contenteditor.tscn")
