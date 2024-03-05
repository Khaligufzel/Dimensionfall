extends Control

var level_files : Array
@export var option_levels : OptionButton 


# Called when the node enters the scene tree for the first time.
func _ready():
	dir_contents("./Mods/Core/Maps/")
	
	for level_file in level_files:
		option_levels.add_item(level_file)
	
	
func dir_contents(path):
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				print("Found directory: " + file_name)
			else:
				print("Found file: " + file_name)
				level_files.append(file_name)
			file_name = dir.get_next()
	else:
		print("An error occurred when trying to access the path.")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_view_level_pressed():
	Helper.switch_level(level_files[option_levels.get_selected_id()],Vector2(0,0))

#When the play demo button is pressed
#Create a new folder in the user directory
#The name of the folder should be the current date and time so it's unique
#This unique folder will contain save data for this game and can be loaded later
func _on_play_demo_pressed():
	Helper.save_helper.create_new_save()
	Helper.switch_level("Generichouse.json", Vector2(0, 0))

func _on_help_button_pressed():
	get_tree().change_scene_to_file("res://documentation.tscn")


func _on_content_manager_button_button_up():
	get_tree().change_scene_to_file("res://Scenes/ContentManager/contentmanager.tscn")
