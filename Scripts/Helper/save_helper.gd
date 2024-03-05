extends Node

#This script is loaded in to the helper.gd autoload singleton
#It can be accessed trough Helper.save_helper
#This script provides functions to help transitioning between maps
#It has functions to save the current map and the location of items, mobs and tiles
#It also has functions to load saved data and place the items, mobs and tiles on the map

var current_save_folder: String = ""

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
	save_mob_data(target_folder)
	save_item_data(target_folder)

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

#Save the type and position of all mobs on the map
func save_mob_data(target_folder: String) -> void:
	var mobData: Array = []
	var defaultMob: Dictionary = {"id": "scrapwalker", \
	"global_position_x": 0, "global_position_y": 0, "global_position_z": 0}
	var mapMobs = get_tree().get_nodes_in_group("mobs")
	var newMobData: Dictionary
	for mob in mapMobs:
		mob.remove_from_group("mobs")
		newMobData = defaultMob.duplicate()
		newMobData["global_position_x"] = mob.global_position.x
		newMobData["global_position_y"] = mob.global_position.y
		newMobData["global_position_z"] = mob.global_position.z
		newMobData["id"] = mob.id
		mobData.append(newMobData.duplicate())
		mob.queue_free()
	Helper.json_helper.write_json_file(target_folder + "/mobs.json",\
	JSON.stringify(mobData))

#Save the type and position of all mobs on the map
func save_item_data(target_folder: String) -> void:
	var itemData: Array = []
	var defaultItem: Dictionary = {"itemid": "item1", \
	"global_position_x": 0, "global_position_y": 0, "global_position_z": 0, "inventory": []}
	var mapitems = get_tree().get_nodes_in_group("mapitems")
	var newitemData: Dictionary
	for item in mapitems:
		item.remove_from_group("mapitems")
		newitemData = defaultItem.duplicate()
		newitemData["global_position_x"] = item.global_position.x
		newitemData["global_position_y"] = item.global_position.y
		newitemData["global_position_z"] = item.global_position.z
		newitemData["inventory"] = item.get_node(item.inventory).serialize()
		itemData.append(newitemData.duplicate())
		item.queue_free()
	Helper.json_helper.write_json_file(target_folder + "/items.json",\
	JSON.stringify(itemData))

#The current state of the map is saved to disk
#Starting from the bottom level (-10), loop over every level
#Not every level is fully populated with blocks, so we need 
#to use the position of the block to store the map information
#If the level is fully populated by blocks, it will save all 
#the blocks with a value in the "texture" field
#If the level is not fully populated (for example, the level only contains
#the walls of a house), we check every possible position where a block
#could be and check if the position matches the position of the first
#child in the level. If it matches, we move on to the next child.
#If it does not match, we save information about the empty block instead.
#If a level has no children, it will remain an empty array []
func save_map_data(target_folder: String) -> void:
	var level_width : int = 32
	var level_height : int = 32
	var mapData: Dictionary = {"mapwidth": 32, "mapheight": 32, "levels": [[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[]]}
	#During map generation, the levels were added to the maplevels group
	var tree: SceneTree = get_tree()
	var mapLevels = tree.get_nodes_in_group("maplevels")
	var block: StaticBody3D
	var current_block: int = 0
	var level_y: int = 0
	var level_block_count: int = 0
	for level: Node3D in mapLevels:
		#The level will be destroyed after saving so we remove them from the group
		level.remove_from_group("maplevels")
		#The bottom level will have y set at -10. The first item in the mapData
		#array will be 0 so in this way we add the levels fom -10 to 10
		level_y = int(level.global_position.y+10)
		level_block_count = level.get_child_count()
		if level_block_count > 0:
			current_block = 0
			# Loop over every row one by one
			for h in level_height:
				# this loop will process blocks from West to East
				for w in level_width:
					block = level.get_child(current_block)
					if block.global_position.z == h and block.global_position.x == w:
						
						# if the rotation is 90 it is facing north
						# In that case we subtract 90 so it is saved as 0
						# If the rotation is 0 it is facing east
						# In that case we add 90, the same for 90 and 180 degrees
						var blockRotation: int = block.rotation_degrees.y
						var myRotation: int
						if blockRotation == 90:
							myRotation = blockRotation-90
						else:
							myRotation = blockRotation+90
						mapData.levels[level_y].append({ "id": block.id,\
						"rotation": myRotation })
						if current_block < level_block_count-1:
							current_block += 1
					else:
						mapData.levels[level_y].append({})
	#Overwrite the file if it exists and otherwise create it
	Helper.json_helper.write_json_file(target_folder + "/map.json", JSON.stringify(mapData))


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
	var inventory_data = JSON.stringify(General.player_inventory_dict)
	Helper.json_helper.write_json_file(save_path, inventory_data)


	# Function to load the player's inventory data
func load_player_inventory() -> void:
	var load_path = current_save_folder + "/player_inventory.json"

	# Load the inventory data from the file
	var loaded_inventory_data = Helper.json_helper.load_json_dictionary_file(load_path)

	if loaded_inventory_data:
		# Update the General.player_inventory_dict with the loaded data
		General.player_inventory_dict = loaded_inventory_data
		print_debug("Player inventory loaded from: " + load_path)
	else:
		print_debug("Failed to load player inventory from: " + load_path)

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

