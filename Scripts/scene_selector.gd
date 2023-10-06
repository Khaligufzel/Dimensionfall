extends Control

var level_files : Array
@export var option_levels : OptionButton 


# Called when the node enters the scene tree for the first time.
func _ready():
	dir_contents("user://levels")
	
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
	Helper.switch_level(level_files[option_levels.get_selected_id()])


func _on_play_demo_pressed():
	Helper.switch_level("")
