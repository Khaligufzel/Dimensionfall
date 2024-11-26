extends Control


func _on_back_button_button_up() -> void:
	get_tree().change_scene_to_file("res://Scenes/ContentManager/contentmanager.tscn")


func _on_overmap_visualisation_button_button_up() -> void:
	get_tree().change_scene_to_file("res://Scenes/ContentManager/OtherTools/overmap_grid_visualization.tscn")
