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
	save_furniture_data(target_folder)

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

# Save all the mobs and their current stats to the mobs file for this map
func save_mob_data(target_folder: String) -> void:
	var mobData: Array = []
	var mapMobs = get_tree().get_nodes_in_group("mobs")
	var newMobData: Dictionary
	for mob in mapMobs:
		mob.remove_from_group("mobs")
		newMobData = {
			"id": mob.id,
			"global_position_x": mob.global_position.x,
			"global_position_y": mob.global_position.y,
			"global_position_z": mob.global_position.z,
			"rotation": mob.rotation_degrees.y,
			"melee_damage": mob.melee_damage,
			"melee_range": mob.melee_range,
			"health": mob.health,
			"current_health": mob.current_health,
			"move_speed": mob.moveSpeed,
			"current_move_speed": mob.current_move_speed,
			"idle_move_speed": mob.idle_move_speed,
			"current_idle_move_speed": mob.current_idle_move_speed,
			"sight_range": mob.sightRange,
			"sense_range": mob.senseRange,
			"hearing_range": mob.hearingRange
		}
		mobData.append(newMobData.duplicate())
		mob.queue_free()
	Helper.json_helper.write_json_file(target_folder + "/mobs.json", JSON.stringify(mobData))

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
	
	
func save_furniture_data(target_folder: String) -> void:
	var furnitureData: Array = []
	var mapFurniture = get_tree().get_nodes_in_group("furniture")
	var newFurnitureData: Dictionary
	var newRot: int
	for furniture in mapFurniture:
		furniture.remove_from_group("furniture")
		if furniture is RigidBody3D:
			newRot = furniture.rotation_degrees.y
		else:
			newRot = furniture.get_my_rotation()
		newFurnitureData = {
			"id": furniture.id,
			"moveable": furniture is RigidBody3D,
			"global_position_x": furniture.global_position.x,
			"global_position_y": furniture.global_position.y,
			"global_position_z": furniture.global_position.z,
			"rotation": newRot,  # Save the Y-axis rotation
			"sprite_rotation": furniture.get_sprite_rotation()
		}
		furnitureData.append(newFurnitureData.duplicate())
		furniture.queue_free()
	Helper.json_helper.write_json_file(target_folder + "/furniture.json", JSON.stringify(furnitureData))


# Saves all of the maplevels to disk
# A maplevel is one 32x32 layer at a certain x,y and z position
# This layer will contain 1024 blocks
func save_map_data(target_folder: String) -> void:
	var level_width: int = 32
	var level_height: int = 32
	var tacticalmapData: Dictionary = {"maplevels": []}
	var tree: SceneTree = get_tree()
	var mapLevels = tree.get_nodes_in_group("maplevels")

	for level: Node3D in mapLevels:
		level.remove_from_group("maplevels")
		var level_node_data: Array = []
		var level_node_dict: Dictionary = {
			"map_x": level.global_position.x, 
			"map_y": level.global_position.y, 
			"map_z": level.global_position.z, 
			"blocks": level_node_data
		}

		# Iterate over each possible block position in the level
		for h in range(level_height):
			for w in range(level_width):
				var block_data: Dictionary = get_block_data_at_position(level, Vector3(w, 0, h))
				level_node_data.append(block_data)

		tacticalmapData.maplevels.append(level_node_dict)

	Helper.json_helper.write_json_file(target_folder + "/map.json", \
	JSON.stringify(tacticalmapData))

# Helper function to get block data at a specific position
func get_block_data_at_position(level: Node3D, position: Vector3) -> Dictionary:
	var block: StaticBody3D = find_block_at_position(level, position)
	if block:
		var blockRotation: int = int(block.rotation_degrees.y)
		var myRotation: int
		if blockRotation == 90:
			myRotation = blockRotation-90
		else:
			myRotation = blockRotation+90
		return {"id": block.id, "rotation": myRotation}
	return {}

# Helper function to find a block at a specific position
func find_block_at_position(level: Node3D, position: Vector3) -> StaticBody3D:
	for child in level.get_children():
		if child is StaticBody3D and child.position == position:
			return child
	return null


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

