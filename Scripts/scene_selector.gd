extends Control

var saved_game_folders : Array
@onready var load_game_button = $VBoxContainer/HBoxContainer/LoadGameButton
@export var load_game_list : OptionButton 

func _ready():
	# Populate the load_game_list with saved game folders
	populate_load_game_list()
	Gamedata.mods.write_default_mods_state()

func _on_load_game_button_pressed():
	Runtimedata.reconstruct() # Load all mod data in the proper way
	var selected_game_id = load_game_list.get_selected_id()
	if try_load_game(selected_game_id):
		Helper.signal_broker.game_loaded.emit()
		# We pass the name of the default map and coordinates
		# If there is a saved game, it will not load the provided map
		# but rather the one that was saved in the game that was loaded
		Helper.initiate_game()


# When the play demo button is pressed
# Create a new folder in the user directory
# The name of the folder should be the current date and time so it's unique
# This unique folder will contain save data for this game and can be loaded later
func _on_play_demo_pressed():
	Runtimedata.reconstruct() # Load all mod data in the proper way
	var rng = RandomNumberGenerator.new()
	Helper.mapseed = rng.randi()
	Helper.save_helper.create_new_save()
	Helper.signal_broker.game_started.emit()
	Helper.initiate_game()

func _on_options_pressed():
	get_tree().change_scene_to_file("res://Scenes/UI/options_menu/master_options_menu_with_tabs.tscn")

func _on_help_button_pressed():
	get_tree().change_scene_to_file("res://documentation.tscn")

func _on_content_manager_button_button_up():
	get_tree().change_scene_to_file("res://Scenes/ContentManager/contentmanager.tscn")

func try_load_game(selected_id: int) -> bool:
	if selected_id < 0 or selected_id >= saved_game_folders.size():
		push_error("Loading failed: selected game ID(%d) is out of saved_game_folders range." % selected_id)
		return false
	var selected_game_folder = saved_game_folders[selected_id]
	Helper.save_helper.load_game_from_folder(selected_game_folder)
	#Helper.save_helper.load_overmap_state()
	Helper.save_helper.load_player_equipment()
	return true

# Populates the load_game_list with saved game folders, sorted in descending order.
func populate_load_game_list() -> void:
	saved_game_folders = Helper.json_helper.folder_names_in_dir("user://save/")
	if saved_game_folders.is_empty():
		load_game_button.disabled = true  # Disable the button if there are no saves
		return

	# Sort the saved_game_folders array in descending order.
	saved_game_folders.sort()
	saved_game_folders.reverse()

	# Enable the load game button
	load_game_button.disabled = false

	# Add saved game folders to the load_game_list
	load_game_list.clear()  # Clear any existing items
	for saved_game in saved_game_folders:
		load_game_list.add_item(saved_game)
