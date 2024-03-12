extends Node

#This script is loaded in to the helper.gd autoload singleton
#It can be accessed trough Helper.save_helper
#This script provides functions to help transitioning between maps
#It has functions to save the current map and the location of items, mobs and tiles
#It also has functions to load saved data and place the items, mobs and tiles on the map

var current_save_folder: String = ""
var number_of_chunks_unloaded: int = 0

# Function to save the current map state
func save_current_level(global_pos: Vector2) -> void:
	var dir = DirAccess.open(current_save_folder)
	var map_folder = "map_x" + str(global_pos.x) + "_y" + str(global_pos.y)
	var target_folder = current_save_folder+ "/" + map_folder
	if !dir.dir_exists(map_folder):
		if !dir.make_dir(map_folder) == OK:
			print_debug("Failed to create a folder for the current map")
			return
	
	save_map_data(target_folder)


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
		JSON.stringify({"mapseed": randi()}))
	else:
		print_debug("Failed to create a unique folder for the demo.")


func save_map_data(target_folder: String) -> void:
	var tree: SceneTree = get_tree()
	var mapChunks = tree.get_nodes_in_group("chunks")
	number_of_chunks_unloaded = 0
	print_debug("unloading all chunks")

	# Get the chunk data before we save them
	for chunk: Node3D in mapChunks:
		#var chunkdata: Dictionary = chunk.get_chunk_data({})
		chunk.chunk_unloaded.connect(_on_chunk_unloaded.bind(mapChunks.size(), target_folder))
		chunk.unload_chunk()
		# We save the chunks by their coordinates on the tacticalmap, so 0,0 and 0,1 etc
		# That's why we need to devide by map width/height which is 32
		#Helper.loaded_chunk_data.chunks[Vector2(int(chunkdata.chunk_x/32),int(chunkdata.chunk_z/32))] = chunkdata
	


func _on_chunk_unloaded(numchunks: int, target_folder: String):
	number_of_chunks_unloaded += 1
	print_debug("number_of_chunks_unloaded = " + str(number_of_chunks_unloaded) + "/" + str(numchunks))
	if numchunks == number_of_chunks_unloaded:
		print_debug("All chunks are unloaded")
		Helper.json_helper.write_json_file(target_folder + "/map.json", \
		JSON.stringify(Helper.loaded_chunk_data))
		Helper.loaded_chunk_data = {"chunks": {}, "mapheight": 0, "mapwidth": 0} # Reset the data
		print_debug("Setting chunks_unloaded to true")
		Helper.ready_to_switch_level.chunks_unloaded = true


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
	if dir.dir_exists(map_folder):
		return target_folder
	return ""


# Function to load game.json from a given saved game folder
func load_game_from_folder(save_folder_name: String) -> void:
	current_save_folder = "user://save/" + save_folder_name


# Function to save the current state of the overmap
func save_overmap_state() -> void:
	var save_path = current_save_folder + "/overmap_state.json"
	var save_data: Dictionary = {
		"position_coord_x": Helper.position_coord.x,
		"position_coord_y": Helper.position_coord.y,
		"chunk_data": {}
	}

	# Convert Vector2 keys to strings
	for key in Helper.chunks:
		var key_str = str(key.x) + "," + str(key.y)
		save_data["chunk_data"][key_str] = Helper.chunks[key]

	Helper.json_helper.write_json_file(save_path, JSON.stringify(save_data))

# Function to load the saved state of the overmap
func load_overmap_state() -> void:
	var overmap_path = current_save_folder + "/overmap_state.json"
	var overmap_state_data = Helper.json_helper.load_json_dictionary_file(overmap_path)

	if overmap_state_data:
		Helper.position_coord = Vector2(overmap_state_data["position_coord_x"],\
		overmap_state_data["position_coord_y"])
		Helper.chunks.clear()

		# Convert string keys back to Vector2
		var chunk_data = overmap_state_data["chunk_data"]
		for key_str in chunk_data:
			var key_parts = key_str.split(",")
			if key_parts.size() == 2:
				var key = Vector2(float(key_parts[0]), float(key_parts[1]))
				Helper.chunks[key] = chunk_data[key_str]

		print_debug("Overmap state loaded from: ", overmap_path)
	else:
		print_debug("Failed to parse overmap state file: ", overmap_path)


# Function to save the player's inventory to a JSON file.
func save_player_inventory() -> void:
	var save_path = current_save_folder + "/player_inventory.json"
	var inventory_data = JSON.stringify(ItemManager.playerInventory.serialize())
	Helper.json_helper.write_json_file(save_path, inventory_data)


# Function to save the player's equipment to a JSON file.
func save_player_equipment() -> void:
	var save_path = current_save_folder + "/player_equipment.json"
	var equipment_data = JSON.stringify(General.player_equipment_dict)
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
		# Update the General.player_inventory_dict with the loaded data
		General.player_equipment_dict = loaded_equipment_data
		print_debug("Player equipment loaded from: " + load_path)
	else:
		print_debug("Failed to load player equipment from: " + load_path)


# Function to save the player's state to a JSON file.
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
		"pain": player.current_pain
	}
	Helper.json_helper.write_json_file(save_path, JSON.stringify(player_state))


# Function to load the player's state from a JSON file.
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
		# Emit signals to update the HUD
		player.update_doll.emit(player.current_head_health, player.current_right_arm_health, player.current_left_arm_health, player.current_torso_health, player.current_right_leg_health, player.current_left_leg_health)
		player.update_stamina_HUD.emit(player.current_stamina)
	else:
		print_debug("Failed to load player state from: ", load_path)
