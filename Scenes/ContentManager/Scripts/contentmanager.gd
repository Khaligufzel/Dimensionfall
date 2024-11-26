extends Control


func _on_back_button_button_up():
	get_tree().change_scene_to_file("res://scene_selector.tscn")


func _on_content_editor_button_button_up():
	get_tree().change_scene_to_file("res://Scenes/ContentManager/contenteditor.tscn")


func _on_mod_manager_button_button_up():
	get_tree().change_scene_to_file("res://Scenes/ContentManager/modmanager.tscn")


func _on_other_tools_button_button_up() -> void:
	get_tree().change_scene_to_file("res://Scenes/ContentManager/othertools.tscn")
