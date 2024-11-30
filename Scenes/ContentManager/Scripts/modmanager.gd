extends Control

# This script belongs to the `modmanager.tscn` scene. This is mostly a page for further navigation


func _on_back_button_button_up():
	get_tree().change_scene_to_file("res://Scenes/ContentManager/contentmanager.tscn")


func _on_mod_maintenance_button_button_up():
	get_tree().change_scene_to_file("res://Scenes/ContentManager/ModMaintenance/modmaintenance.tscn")


func _on_add_remove_mods_button_button_up() -> void:
	get_tree().change_scene_to_file("res://Scenes/ContentManager/addremovemods.tscn")
