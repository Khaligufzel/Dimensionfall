extends Node

#This script is loaded in to the helper.gd autoload singleton
#It can be accessed trough Helper.save_helper
#This script provides functions to help transitioning between maps
#It has functions to save the current map and the location of items, mobs and tiles
#It also has functions to load saved data and place the items, mobs and tiles on the map

var current_save_folder: String = ""
signal all_chunks_unloaded


#Creates a new save folder. The name of this folder will be the current date and time
#This is to make sure it is unique. The folder name is stored in order to perform
#save and load actions. Also, the map seed is created and stored
func create_new_save():
	var dir = DirAccess.open("user://")
	var unique_folder_path := "save/" + Time.get_datetime_string_from_system()
	var sanitized_path = unique_folder_path.replace(":","")
	if dir.make_dir_recursive(sanitized_path) == OK:
		current_save_folder = "user://" + sanitized_path
		Helper.json_helper.write_json_file(current_save_folder + "/game.json",\
		JSON.stringify({"mapseed": Helper.mapseed}))
	else:
		print_debug("Failed to create a unique folder for the demo.")


# We can only save the data when all chunks are unloaded.
func save_map_data() -> void:
	Helper.map_manager.level_generator.all_chunks_unloaded.connect(_on_chunks_unloaded)
	Helper.map_manager.level_generator.unload_all_chunks()


# The level_generator has unloaded all the chunks. Save the data to disk
func _on_chunks_unloaded():
		print_debug("All chunks are unloaded")
		# Devides the loaded_chunk_data.chunks into segments and saves them to disk
		Helper.overmap_manager.unload_all_remaining_segments()
		all_chunks_unloaded.emit()


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
	save_player_inventory()
	save_player_equipment()
	save_player_state(get_tree().get_first_node_in_group("Players"))


# Function to load game.json from a given saved game folder
func load_game_from_folder(save_folder_name: String) -> void:
	current_save_folder = "user://save/" + save_folder_name
	var gameFileJson: Dictionary = Helper.json_helper.load_json_dictionary_file(\
	current_save_folder + "/game.json")
	if gameFileJson:
		Helper.mapseed = gameFileJson.mapseed


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
	var player_state: Dictionary = {
		"is_alive": player.is_alive,
		"left_arm_health": player.current_left_arm_health,
		"right_arm_health": player.current_right_arm_health,
		"head_health": player.current_head_health,
		"torso_health": player.current_torso_health,
		"left_leg_health": player.current_left_leg_health,
		"right_leg_health": player.current_right_leg_health,
		"stamina": player.current_stamina,
		"hunger": player.current_hunger,
		"thirst": player.current_thirst,
		"nutrition": player.current_nutrition,
		"pain": player.current_pain,
		"skills": player.skills,  # Add skills dictionary
		"global_position_x": player.global_transform.origin.x,
		"global_position_y": player.global_transform.origin.y,
		"global_position_z": player.global_transform.origin.z
	}
	Helper.json_helper.write_json_file(save_path, JSON.stringify(player_state))


# This function loads the player's state from a JSON file, including skills.
func load_player_state(player: CharacterBody3D) -> void:
	var load_path = current_save_folder + "/player_state.json"
	var player_state = Helper.json_helper.load_json_dictionary_file(load_path)

	if player_state:
		player.is_alive = player_state["is_alive"]
		player.current_left_arm_health = player_state["left_arm_health"]
		player.current_right_arm_health = player_state["right_arm_health"]
		player.current_head_health = player_state["head_health"]
		player.current_torso_health = player_state["torso_health"]
		player.current_left_leg_health = player_state["left_leg_health"]
		player.current_right_leg_health = player_state["right_leg_health"]
		player.current_stamina = player_state["stamina"]
		player.current_hunger = player_state["hunger"]
		player.current_thirst = player_state["thirst"]
		player.current_nutrition = player_state["nutrition"]
		player.current_pain = player_state["pain"]
		player.skills = player_state["skills"]  # Load skills dictionary
		player.global_transform.origin.x = player_state["global_position_x"]
		player.global_transform.origin.y = player_state["global_position_y"]
		player.global_transform.origin.z = player_state["global_position_z"]

		# Emit signals to update the HUD
		player.update_doll.emit(player.current_head_health, player.current_right_arm_health, player.current_left_arm_health, player.current_torso_health, player.current_right_leg_health, player.current_left_leg_health)
		player.update_stamina_HUD.emit(player.current_stamina)
	else:
		print_debug("Failed to load player state from: ", load_path)



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

