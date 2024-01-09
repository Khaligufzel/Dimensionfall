extends Control

var level_files : Array
@export var load_game_list : OptionButton 


# Called when the node enters the scene tree for the first time.
func _ready():
	level_files = Helper.json_helper.file_names_in_dir("./Mods/Core/Maps/")
	for level_file in level_files:
		load_game_list.add_item(level_file)

func _on_view_level_pressed():
	Helper.switch_level(level_files[load_game_list.get_selected_id()],Vector2(0,0))

# When the play demo button is pressed
# Create a new folder in the user directory
# The name of the folder should be the current date and time so it's unique
# This unique folder will contain save data for this game and can be loaded later
func _on_play_demo_pressed():
	Helper.save_helper.create_new_save()
	Helper.switch_level("Generichouse.json", Vector2(0, 0))

func _on_help_button_pressed():
	get_tree().change_scene_to_file("res://documentation.tscn")

func _on_content_manager_button_button_up():
	get_tree().change_scene_to_file("res://Scenes/ContentManager/contentmanager.tscn")
