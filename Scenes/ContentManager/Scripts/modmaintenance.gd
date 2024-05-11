extends Control

# This script is meant to be used with the mod maintenance inteface
# This script allows the user to erase the selected property from the selected type


@export var scriptOptionButton: OptionButton
@export var removePropertyScript: Control


func _on_back_button_button_up():
	get_tree().change_scene_to_file("res://Scenes/ContentManager/modmanager.tscn")


func _on_script_option_button_item_selected(index):
	hide_scripts()
	if index == 0:
		removePropertyScript.visible = true


func hide_scripts():
	removePropertyScript.visible = false
