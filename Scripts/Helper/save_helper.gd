extends Node

#This script is loaded in to the helper.gd autoload singleton
#It can be accessed trough Helper.save_helper
#This script provides functions to help transitioning between maps
#It has functions to save the current map and the location of items, mobs and tiles
#It also has functions to load saved data and place the items, mobs and tiles on the map

var current_save_folder: String = ""


#Creates a new save folder. The name of this folder will be the current date and time
#This is to make sure it is unique. The folder name is stored in order to perform
#save and load actions. Also, the map seed is created and stored
func create_new_save():
	var dir = DirAccess.open("user://")
	var unique_folder_path := "save/" + Time.get_datetime_string_from_system()
	var sanitized_path = unique_folder_path.replace(":", "")
	if dir.make_dir_recursive(sanitized_path) == OK:
		current_save_folder = "user://" + sanitized_path
		Helper.json_helper.write_json_file(current_save_folder + "/game.json", JSON.stringify({
			"mapseed": Helper.mapseed,
			"elapsed_time": Helper.time_helper.get_elapsed_time()  # Save the elapsed time
		}))
	else:
		print_debug("Failed to create a unique folder for the demo.")



# We can only save the data when all chunks are unloaded.
func save_map_data() -> void:
	# Get all chunks in the group "chunks"
	var chunks = get_tree().get_nodes_in_group("chunks")
	for chunk in chunks:
		if is_instance_valid(chunk): # some might be queue_freed at this point
			chunk.save_chunk()
			#await Helper.task_manager.create_task(chunk.save_chunk).completed


# Function to save a map segment to disk. The Helper.overmap_manager will call this
# A segment is a 4x4 area in which chunks are selected if the coordinates fall in this area
# This selection of chunks will be stored in the save file. It may or may not contain all 16 chunks
func save_map_segment_data(non_empty_chunk_data: Dictionary, segment_pos: Vector2) -> void:
	var dir = DirAccess.open(current_save_folder)
	var map_folder = "map_x" + str(segment_pos.x) + "_y" + str(segment_pos.y)
	var target_folder = current_save_folder + "/" + map_folder
	
	# Create the directory if it doesn't exist
	if not dir.dir_exists(map_folder):
		if dir.make_dir(map_folder) != OK:
			print_debug("Failed to create a folder for the segment at ", segment_pos)
			return
	
	# Convert the dictionary to a JSON string
	var json_data = JSON.stringify(non_empty_chunk_data)
	
	# Save the JSON string to a file
	if Helper.json_helper.write_json_file(target_folder + "/segment_data.json", json_data) != OK:
		print_debug("Failed to save chunk data for the segment at ", segment_pos)


# Function to load chunk data from a map file on disk
# This function takes a segment_pos, constructs the path to the map file,
# loads the JSON data from the file, and returns a dictionary of chunk data.
# This dictionary represents a 4x4 segment of chunks
func load_map_segment_data(segment_pos: Vector2) -> Dictionary:
	var map_folder = "map_x" + str(segment_pos.x) + "_y" + str(segment_pos.y)
	var file_path = current_save_folder + "/" + map_folder + "/segment_data.json"
	var chunk_data = {}
	
	# Load the JSON data from the file
	var tactical_map_json = Helper.json_helper.load_json_dictionary_file(file_path)
	if tactical_map_json.is_empty():
		return chunk_data  # Return an empty dictionary if loading fails
	
	# Transform the loaded chunk data back into a dictionary with Vector2 keys
	for key in tactical_map_json.keys():
		var chunk_pos = Vector2(key.split(",")[0].to_int(), key.split(",")[1].to_int())
		chunk_data[chunk_pos] = tactical_map_json[key]
	
	return chunk_data


# This function determines the saved map folder path for the current level. 
# It constructs this path using the current level's position and the current 
# save folder's path. If the map folder for the level exists, it returns 
# the full path to this folder; otherwise, it returns an empty string.
# The current_save_folder is determined when the game is first started
# and does not change unless the user start a new game.
func get_saved_map_folder(level_pos: Vector2) -> String:
	var dir = DirAccess.open(current_save_folder)
	var map_folder = "map_x" + str(level_pos.x) + "_y" + str(level_pos.y)
	var target_folder = current_save_folder+ "/" + map_folder
	# For example, the target_folder could be: "C:\Users\User\AppData\Roaming\Godot\app_userdata\
	# CataX\save\2024-01-08T202236\map_x0_y0"
	if dir and dir.dir_exists(map_folder):
		return target_folder
	return ""


# Save game state
func save_game():
	save_map_data()
	Helper.overmap_manager.save_all_segments()
	save_player_inventory()
	save_player_equipment()
	save_quest_state()
	save_player_state(get_tree().get_first_node_in_group("Players"))
	save_game_state()  # Save the overarching game state


# Function to load game.json from a given saved game folder
func load_game_from_folder(save_folder_name: String) -> void:
	current_save_folder = "user://save/" + save_folder_name
	var gameFileJson: Dictionary = Helper.json_helper.load_json_dictionary_file(current_save_folder + "/game.json")
	if gameFileJson:
		Helper.mapseed = gameFileJson.get("mapseed", Helper.mapseed)  # Load the mapseed
		var elapsed_time = gameFileJson.get("elapsed_time", 0.0)  # Default to 0 if not present
		Helper.time_helper.set_elapsed_time(elapsed_time)  # Load elapsed time into TimeHelper


# Function to save the player's inventory to a JSON file.
func save_player_inventory() -> void:
	var save_path = current_save_folder + "/player_inventory.json"
	var inventory_data = JSON.stringify(ItemManager.playerInventory.serialize())
	Helper.json_helper.write_json_file(save_path, inventory_data)


# Function to save the player's equipment to a JSON file.
func save_player_equipment() -> void:
	var save_path = current_save_folder + "/player_equipment.json"
	var equipment_data = JSON.stringify(ItemManager.player_equipment.serialize())
	Helper.json_helper.write_json_file(save_path, equipment_data)


	# Function to load the player's inventory data
func load_player_inventory() -> void:
	var load_path = current_save_folder + "/player_inventory.json"

	# Load the inventory data from the file
	var loaded_inventory_data = Helper.json_helper.load_json_dictionary_file(load_path)

	if loaded_inventory_data:
		# Update the General.player_inventory_dict with the loaded data
		ItemManager.playerInventory.deserialize(loaded_inventory_data)
		print_debug("Player inventory loaded from: " + load_path)
	else:
		print_debug("Failed to load player inventory from: " + load_path)


# Function to load the player's inventory data
func load_player_equipment() -> void:
	var load_path = current_save_folder + "/player_equipment.json"

	# Load the equipment data from the file
	var loaded_equipment_data = Helper.json_helper.load_json_dictionary_file(load_path)

	if loaded_equipment_data:
		# Update the ItemManager.player_equipment with the loaded data
		ItemManager.player_equipment.deserialize(loaded_equipment_data)
		print_debug("Player equipment loaded from: " + load_path)
	else:
		print_debug("Failed to load player equipment from: " + load_path)


# This function saves the player's state to a JSON file, including skills.
func save_player_state(player: CharacterBody3D) -> void:
	if !player:
		return
	var save_path = current_save_folder + "/player_state.json"
	var player_state: Dictionary = player.get_state()
	Helper.json_helper.write_json_file(save_path, JSON.stringify(player_state))


# This function loads the player's state from a JSON file, including skills.
func load_player_state(player: CharacterBody3D) -> void:
	var load_path = current_save_folder + "/player_state.json"
	var player_state = Helper.json_helper.load_json_dictionary_file(load_path)

	if player_state:
		player.set_state(player_state)
	else:
		print_debug("Failed to load player state from: ", load_path)

# This function saves the player's quest state to a JSON file.
func save_quest_state() -> void:
	var save_path = current_save_folder + "/quest_state.json"
	var quest_state: Dictionary = Helper.quest_helper.get_state()
	Helper.json_helper.write_json_file(save_path, JSON.stringify(quest_state))

# This function loads the player's quest state from a JSON file.
func load_quest_state() -> void:
	var load_path = current_save_folder + "/quest_state.json"
	var quest_state = Helper.json_helper.load_json_dictionary_file(load_path)

	if quest_state:
		Helper.quest_helper.set_state(quest_state)
	else:
		print_debug("Failed to load quest state from: ", load_path)


# Function to save the current state of the grid
func save_overmap_grid_to_file(grid_data: Dictionary, grid_key: Vector2) -> void:
	var save_path = current_save_folder + "/overmap/grid_" + str(grid_key.x) + "_" + str(grid_key.y) + ".json"
	Helper.json_helper.write_json_file(save_path, JSON.stringify(grid_data))


# Function to load the state of the grid
func load_overmap_grid_from_file(grid_key: Vector2) -> Dictionary:
	var load_path = current_save_folder + "/overmap/grid_" + str(grid_key.x) + "_" + str(grid_key.y) + ".json"
	return Helper.json_helper.load_json_dictionary_file(load_path)


# Loads all files in the /overmap folder and returns the contents as an array
func load_all_overmap_grids_from_file() -> Array:
	var loaded_overmap_grids: Array = []
	var load_path = current_save_folder + "/overmap"
	var overmap_grid_files: Array = Helper.json_helper.file_names_in_dir(load_path)
	for overmap in overmap_grid_files:
		var file_path = load_path + "/" + overmap
		loaded_overmap_grids.append(Helper.json_helper.load_json_dictionary_file(file_path))
	return loaded_overmap_grids


func save_game_state():
	# Ensure the save folder exists
	if current_save_folder == "":
		print_debug("No save folder set. Cannot save game state.")
		return

	# Save the game state to game.json
	var game_state = {
		"mapseed": Helper.mapseed,
		"elapsed_time": Helper.time_helper.get_elapsed_time()  # Include elapsed time
	}
	var save_path = current_save_folder + "/game.json"
	if Helper.json_helper.write_json_file(save_path, JSON.stringify(game_state)) != OK:
		print_debug("Failed to save game state to:", save_path)
	else:
		print_debug("Game state saved to:", save_path)
