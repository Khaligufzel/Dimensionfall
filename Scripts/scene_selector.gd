extends Control

var saved_game_folders : Array
@export var load_game_list : OptionButton 

# Called when the node enters the scene tree for the first time.
func _ready():
	saved_game_folders = Helper.json_helper.folder_names_in_dir("user://save/")
	for saved_game in saved_game_folders:
		load_game_list.add_item(saved_game)

func _on_load_game_button_pressed():
	#Helper.switch_level(level_files[load_game_list.get_selected_id()],Vector2(0,0))
	var selected_game_folder = saved_game_folders[load_game_list.get_selected_id()]
	# Here you can call the function to load the game using the selected folder
	# Example: Helper.load_game(selected_game_folder)

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
