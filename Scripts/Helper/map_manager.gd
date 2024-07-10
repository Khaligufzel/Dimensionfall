extends Node

# This script manages the tacticalmap, where the player is playing in.
# It is part of the Helper singleton and can be accessed by Helper.map_manager
# It keeps track of entities on the map
# It can add and remove entities on the map
# It can check what's around the player in terms of blocks and furniture

# We keep a reference to the level_generator, which holds the chunks
# The level generator will register itself to this variable when it's ready
var level_generator: Node = null
	
func get_chunk_from_position(position_in_3d_space: Vector3) -> Chunk:
	return level_generator.get_chunk_from_position(position_in_3d_space)


# Function to process area data and assign to tile
func process_area_data(area_data: Dictionary, original_tile_id: String) -> Dictionary:
	var result = {}

	# Process and assign tile ID
	var tiles_data = area_data.get("tiles", [])
	if not tiles_data.is_empty():
		var picked_tile = pick_item_based_on_count(tiles_data)
		# Check if the picked tile is "null"
		if picked_tile["id"] == "null":
			result["id"] = original_tile_id  # Keep the original tile ID
		else:
			result["id"] = picked_tile["id"]

	# Calculate the total count of tiles
	var total_tiles_count: int = calculate_total_count(tiles_data)

	# Duplicate the entities_data and add the "None" entity
	var entities_data = area_data.get("entities", []).duplicate()
	# We add an extra item to the entities list 
	# which will affect the proportion of entities that will spawn
	# If you have an area of grass with a grass tile with a count of 100
	# and a tree furniture with a count of 1, the entities_data will contain
	# the tree furniture with a count of 1 and the "None" with a count of 100
	# This results in the tree being picked every 1 in 100 tiles.
	entities_data.append({"id": "None", "type": "None", "count": total_tiles_count})

	# Pick an entity from the duplicated entities_data
	if not entities_data.is_empty():
		var selected_entity = pick_item_based_on_count(entities_data)
		if selected_entity["type"] != "None":
			match selected_entity["type"]:
				"furniture":
					result["furniture"] = {"id":selected_entity["id"]}
				"mob":
					result["mob"] = {"id":selected_entity["id"]}
				"itemgroup":
					result["itemgroups"] = [selected_entity["id"]]

	return result


# Function to pick an item based on its count property
func pick_item_based_on_count(items: Array) -> Dictionary:
	var total_count: int = calculate_total_count(items)
	var random_pick: int = randi() % total_count
	for item in items:
		if random_pick < item["count"]:
			return item
		random_pick -= item["count"]

	return {}  # In case no item is selected, though this should not happen if the input is valid


# Function to calculate the total count of items
func calculate_total_count(items: Array) -> int:
	var total_count: int = 0
	for item in items:
		total_count += item["count"]
	return total_count


# Applie an area to a tile, overwriting it's id based on a picked tile
# It will loop over all selected areas from mapdata in order, from top to bottom
# Each area will pick a new tile id for this tile, so it may be overwritten more then once
# This only happens if the tile has more then one are (i.e. overlapping areas)
# The order of areas in the tile doesn't matter, onlt the order of areas in the mapdata.
func apply_area_to_tile(tile: Dictionary, selected_areas: Array, mapData: Dictionary) -> void:
	# Store the areas property from the tile data into a variable
	var tile_areas = tile.get("areas", [])
	var original_tile_id = tile.get("id", "")  # Store the original tile ID
	
	# Loop over every area from the selected areas
	for area in selected_areas:
		# Check if the area ID is present in the tile's areas list
		for tile_area in tile_areas:
			if area["id"] == tile_area["id"]:
				var area_data = get_area_data_by_id(area["id"], mapData)
				var processed_data = process_area_data(area_data, original_tile_id)
				
				# Erase all keys from the tile dictionary
				for key in tile.keys():
					tile.erase(key)
				
				# Update the original tile dictionary with the processed data
				for key in processed_data.keys():
					tile[key] = processed_data[key]


# Function to loop over every tile in every level and apply the area to relevant tiles
func apply_areas_to_tiles(selected_areas: Array, generated_mapdata: Dictionary) -> void:
	if generated_mapdata.has("levels"):
		for level in generated_mapdata["levels"]:
			for tile in level:
				if tile.has("areas"):
					apply_area_to_tile(tile, selected_areas, generated_mapdata)


# Function to get area data by ID
func get_area_data_by_id(area_id: String, mapData: Dictionary) -> Dictionary:
	if mapData.has("areas"):
		for area in mapData["areas"]:
			if area["id"] == area_id:
				return area
	return {}


# Function to apply spawn modifications to areas in mapData
func apply_spawn_modifications(spawn_modifications: Array, mapData: Dictionary) -> void:
	for mod in spawn_modifications:
		var mod_id = mod["id"]
		var mod_chance = mod["chance"]
		# Find the area in mapData and modify its spawn_chance
		for map_area in mapData["areas"]:
			if map_area["id"] == mod_id:
				# Allow spawn_chance to go below 0 or above 100 to provide flexibility
				map_area["spawn_chance"] += mod_chance


# Function to check if mapData has areas and return their data based on spawn chance
func get_area_data_based_on_spawn_chance(mapData: Dictionary) -> Array:
	var selected_areas = []
	if mapData.has("areas"):
		for area in mapData["areas"]:
			if randi() % 100 < area.get("spawn_chance", 0):
				selected_areas.append(area)
				# Check for spawn_modifications
				if area.has("spawn_modifications"):
					apply_spawn_modifications(area["spawn_modifications"], mapData)
	return selected_areas


# Processes a map and applies areas in that map to the mapdata
# The provided dictionary will be modified by this function, so send a duplicate if you don't want changes
# If no areas exist in the mapdata, no changes are made
func process_areas_in_map(mapdata: Dictionary):
	if not mapdata.has("areas"):
		return
	# Check and get area data in mapData based on spawn chance
	var selected_areas = get_area_data_based_on_spawn_chance(mapdata)
	apply_areas_to_tiles(selected_areas, mapdata)
