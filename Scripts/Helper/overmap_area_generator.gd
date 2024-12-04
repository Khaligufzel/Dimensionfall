class_name OvermapAreaGenerator
extends RefCounted


# This is a stand-alone script that generates an area that can be placed on the overmap, such as a city
# It can be accessed trough OvermapAreaGenerator.new()
# The script has a function that returns the 2d grid on which maps are procedurally placed
# All map data comes from Runtimedata.maps. The maps contain the weights and connections that are used


# Example overmaparea data:
# {
#     "id": "city_00",  // id for the overmap area
#     "name": "Example City",  // Name for the overmap area
#     "description": "A densely populated urban area surrounded by suburban regions and open fields.",  // Description of the overmap area
#     "min_width": 5,  // Minimum width of the overmap area
#     "min_height": 5,  // Minimum height of the overmap area
#     "max_width": 15,  // Maximum width of the overmap area
#     "max_height": 15,  // Maximum height of the overmap area
#     "regions": {
#       "urban": {
#         "spawn_probability": {
#           "range": {
#             "start_range": 0,  // Will start spawning at 0% distance from the center
#             "end_range": 30     // Will stop spawning at 30% distance from the center
#           }
#         },
#         "maps": [
#           {
#             "id": "house_01",
#             "weight": 10  // Higher weight means this map has a higher chance to spawn in this region
#           },
#           {
#             "id": "shop_01",
#             "weight": 5
#           },
#           {
#             "id": "park_01",
#             "weight": 2
#           }
#         ]
#       },
#       "suburban": {
#         "spawn_probability": {
#           "range": {
#             "start_range": 20,  // Will start spawning at 20% distance from the center
#             "end_range": 80     // Will stop spawning at 80% distance from the center
#           }
#         },
#         "maps": [
#           {
#             "id": "house_02",
#             "weight": 8
#           },
#           {
#             "id": "garden_01",
#             "weight": 4
#           },
#           {
#             "id": "school_01",
#             "weight": 3
#           }
#         ]
#       },
#       "field": {
#         "spawn_probability": {
#           "range": {
#             "start_range": 70,  // Will start spawning at 70% distance from the center
#             "end_range": 100     // Will stop spawning at 100% distance from the center
#           }
#         },
#         "maps": [
#           {
#             "id": "field_01",
#             "weight": 12
#           },
#           {
#             "id": "barn_01",
#             "weight": 6
#           },
#           {
#             "id": "tree_01",
#             "weight": 8
#           }
#         ]
#       }
#     }
# }


var grid_width: int = 20
var grid_height: int = 20
var area_grid: Dictionary = {}  # Grid containing the generated area
# Dictionary to store the percentage distance from the center for each grid position
var distance_from_center_map: Dictionary = {}  # Key: Vector2 (position), Value: float (percentage distance)
var dimensions: Vector2 = Vector2.ZERO # The dimensions of the grid
var dovermaparea: ROvermaparea = null
var tile_catalog: Array = []  # List of all tile instances with rotations
var tried_tiles: Dictionary = {}  # Key: (x, y), Value: Set of tried tile IDs
var processed_tiles: Dictionary = {}  # Dictionary to track processed tiles
var noise = FastNoiseLite.new() # Used to create noise to modify distance_from_center_map

# Tiles sorted by key. This can be used to select the right neighbors for the tiles
# We will pick one direction to select the correct neighbor. Let's say "north".
# Each Tile will select a neighbor_key like "urban" or "suburban"
# Then, if the "north" direction of the current tile has a "road" connection, we select those
# Then, we want the neighbor tiles that have a road connection in the south, so we pick "south"
# For example:
#	{
#		"urban": {
#			"road": {
#				"north": {
#					"house_01_urban_0": tile1 <- house_01 has a north road connection at rotation 0
#				}
#				"south": {
#					"house_01_urban_180": tile2 <- house_01 has a south road connection at rotation 180
#				}
#			},
#			"ground": {
#				"south": {
#					"house_01_urban_90": tile3 <- house_01 has a south ground connection at rotation 90
#				}
#			}
#		}
#		"suburban": {
#			"road": {
#				"north": {
#					"house_01_urban_0": tile1
#				}
#				"south": {
#					"house_01_urban_180": tile2
#				}
#			}
#		}
#	}
var tile_dictionary: Dictionary = {}


class Tile:
	var id: String
	var key: String
	var rotation: int
	var weight: float  # Base weight for selection
	# rmap includes:
	# rmap.connections e.g., {"north": "road", "south": "ground", ...}
	# rmap.neighbor_keys e.g., {"urban": 100, "suburban": 50} what type of zone this map can spawn in.
	# This variable holds the neighbor keys that are allowed to spawn next to this map
	# rmap.neighbors e.g., {"north": {"urban": 100, "suburban": 50}, "south": ...}
	var rmap: RMap  # Map data
	var tile_dictionary: Dictionary # Reference to the tile_dictionary variable in the main script
	
	# Define rotation mappings for how the directions shift depending on rotation
	var rotation_map: Dictionary


	# Adjusts the connections based on the rotation
	func rotated_connections(myrotation: int) -> Dictionary:
		var myrotated_connections = {}
		for direction in rmap.connections.keys():
			# Adjust the direction based on the myrotation using the rotation_map
			var new_direction = rotation_map[myrotation][direction]

			# Keep the same connection type but adjust direction, so a road to north is now a road to west, for example
			myrotated_connections[new_direction] = rmap.connections[direction]

		return myrotated_connections

		
	# Function to pick a tile from the list based on the weights
	# tiles: A list of tiles that are limited by neighbor_key, connection and direction
	# For example, it may only contain tiles from "urban", connection "road" and "north" direction
	func pick_tile_from_list(tiles: Array) -> Tile:
		var total_weight: float = 0.0
		var weighted_tiles: Dictionary = {}  # Stores tiles and their corresponding weights

		# Step 1: Register the weight of each tile and count total weight
		for tile in tiles:
			total_weight += tile.weight
			weighted_tiles[tile] = tile.weight

		# Step 2: Randomly select a tile based on the accumulated weights
		var rand_value: float = randf() * total_weight
		for tile in weighted_tiles.keys():
			rand_value -= weighted_tiles[tile]
			if rand_value <= 0:
				return tile  # Return the selected tile based on the weighted probability

		return null  # Return null if no tile is selected, which should not happen if weights are correct


	# Retrieves a list of neighbor tiles based on the direction, connection type, and rotation
	func get_neighbor_tiles(direction: String, neighbor_key: String) -> Array:
		if neighbor_key == "" or not tile_dictionary.has(neighbor_key):
			return []  # Return an empty list if no valid neighbor key is found

		# Step 2: Determine the connection type for the provided direction based on tile rotation
		var myrotated_connections: Dictionary = rotated_connections(rotation)
		var connection_type: String = myrotated_connections.get(direction, "")

		# Step 3: Retrieve the list of tiles from tile_dictionary based on the neighbor key, connection type, and direction
		var reverse_direction = rotation_map[180][direction]  # Get the reverse direction
		if tile_dictionary[neighbor_key].has(connection_type) and tile_dictionary[neighbor_key][connection_type].has(reverse_direction):
			return tile_dictionary[neighbor_key][connection_type][reverse_direction].values()  # Return the list of tiles
		else:
			print_debug("get_neighbor_tiles: No matching tiles found for Neighbor Key:", neighbor_key, " and Connection Type:", connection_type)  # Debug when no tiles are found
			return []  # Return an empty list if no matching tiles are found


	# Retrieves a tile from the neighbor tiles list based on weighted probability
	func get_neighbor_tile(direction: String, neighbor_key: String) -> Tile:
		# Step 1: Get the list of neighbor tiles based on the direction, connection type, and rotation
		var neighbor_tiles: Array = get_neighbor_tiles(direction, neighbor_key)
		if neighbor_tiles.is_empty():
			return null  # Return null if no neighbor tiles are found

		# Step 2: Pick a tile from the neighbor tiles list based on the weight of the picked neighbor key
		return pick_tile_from_list(neighbor_tiles)

	# Checks if this tile and a neighbor tile have compatible connections
	func are_connections_compatible(neighbor: Tile, direction: String) -> bool:
		# Get the adjusted connections for both tiles based on their rotations
		var my_rotated_connections = rotated_connections(rotation)
		var neighbor_rotated_connections = neighbor.rotated_connections(neighbor.rotation)

		# Get the connection type for the current tile in the given direction
		var my_connection_type = my_rotated_connections[direction]

		# Get the reverse direction to check the neighbor's connection in the opposite direction
		var reverse_direction = rotation_map[180][direction] # 180 will get the opposite direction
		var neighbor_connection_type = neighbor_rotated_connections[reverse_direction]

		# Check if the connections are compatible (for example, both should be "road" or "ground")
		return my_connection_type == neighbor_connection_type


# Generates the area from the center to the edge of the grid
# Start out by placing a tile in the center of the grid. In a 20x20 grid, this will be (10,10)
# The starting tile should be picked from the tile_dictionary using these parameters:
# neighbor_key: "urban"
# connection: "road"
# direction: "north"
# This will get a new dictionary from tile_dictionary. We will pick one tile at random from that dictionary's values.
# Now that we have a starting tile, we will loop over the directions "north","west","south","east"
# For each of the directions, we will call the starting tile's get_neighbor_tile(direction) function
# Place the picked tiles next to the starting tile in each direction. We will now have 5 tiles on the grid
# Repeat these steps for the new tiles, starting from the tile in the north, then west, south and east
# We have to make sure that a tile in the north-east will be able to fit to both the north and the east
# tile. We can use tile.are_connections_compatible(tile, direction) for this. If the picked tile is not
# compatible with both tiles at the same time, we will put that tile in an exclusion list and
# pick another tile from tile.get_neighbor_tile(direction). Repeat this process until a tile is placed.
# If no tile can be placed here, place the starting tile here.
# Generates the area from the center to the edge of the grid
# This function will initiate the area generation by placing the starting tile and then expanding
# to its immediate neighbors in a plus pattern (north, west, south, east).
func generate_area(max_iterations: int = 100000) -> Dictionary:
	processed_tiles.clear()
	create_tile_entries()
	# Set the area dimensions before generating the area grid
	set_area_dimensions()

	# Step 1: Populate the distance_from_center_map before generating the area
	populate_distance_from_center_map()
	
	# Step 2: Place the starting tile in the center of the grid
	var center = get_map_center()
	var starting_tile = place_starting_tile(center)

	# Step 3: Initialize a queue to manage tiles to be processed
	var queue = []  # List of tile positions to process
	processed_tiles = {}  # Dictionary to track processed tiles
	var iteration_count = 0  # Counter to track the number of iterations

	if starting_tile:
		queue.append(center)
		processed_tiles[center] = true

	# Step 4: Process the queue until all tiles have been placed or limit is reached
	while not queue.is_empty() and iteration_count < max_iterations:
		var current_position = queue.pop_front()

		# Place neighbors for the current tile position
		place_neighbor_tiles(current_position)

		for direction in Gamedata.DIRECTION_OFFSETS.keys():
			var neighbor_position = current_position + Gamedata.DIRECTION_OFFSETS[direction]

			# Check if the neighbor is within bounds and hasn't been processed yet
			if is_within_grid_bounds(neighbor_position):
				if not processed_tiles.has(neighbor_position) and area_grid.has(neighbor_position):
					queue.append(neighbor_position)
					processed_tiles[neighbor_position] = true  # Mark as processed

		iteration_count += 1  # Increment the iteration counter

	if iteration_count >= max_iterations:
		print_debug("Warning: Maximum iteration limit reached in generate_area. Possible infinite loop detected.")

	return area_grid


# Function to populate the distance_from_center_map with modified percentage distances from the center
func populate_distance_from_center_map() -> void:
	# Clear the distance_from_center_map for fresh generation
	distance_from_center_map.clear()
	
	# Set up FastNoiseLite with a specific seed and frequency
	setup_noise(randi(), 0.3)

	# Loop through all possible positions in the grid
	for x in range(grid_width):
		for y in range(grid_height):
			var position = Vector2(x, y)
			
			# Calculate the linear percentage distance from the center
			var base_percentage = get_distance_from_center_as_percentage(position)

			# Calculate a noise-based modifier to introduce organic variation
			var noise_value = noise.get_noise_2d(float(x), float(y))
			var noise_modifier = noise_value * 25.0  # Adjust the scale of the noise effect as needed

			# Combine the base percentage with the noise modifier
			var modified_percentage = base_percentage + noise_modifier

			# Clamp the modified percentage to ensure it stays within [0, 100] range
			modified_percentage = clamp(modified_percentage, 0.0, 100.0)

			# Store the modified percentage in the distance_from_center_map dictionary
			distance_from_center_map[position] = modified_percentage


# Function to check if a given position is within the grid bounds
func is_within_grid_bounds(position: Vector2) -> bool:
	return position.x >= 0 and position.x < dimensions.x and position.y >= 0 and position.y < dimensions.y


# Function to place the neighboring tiles of the specified position on the area_grid
# It checks if there is a tile at the given position and then places neighbor tiles based on the tile's logic
func place_neighbor_tiles(position: Vector2) -> void:
	# Get the current tile at the given position
	var current_tile = get_tile_at_position(position)
	if current_tile == null:
		print_debug("No tile present at the specified position.")
		return

	# Loop through each direction (north, east, south, west) and place neighboring tiles
	for direction in Gamedata.DIRECTION_OFFSETS.keys():
		var neighbor_pos: Vector2 = position + Gamedata.DIRECTION_OFFSETS[direction]
		place_neighbor_tile(current_tile, direction, neighbor_pos)


# Helper function to get the tile at the specified position
func get_tile_at_position(position: Vector2) -> Tile:
	if area_grid.has(position):
		return area_grid[position]
	return null


# Function to place a tile in a neighboring position based on the current tile and direction
func place_neighbor_tile(current_tile: Tile, direction: String, neighbor_pos: Vector2) -> void:
	if not is_within_grid_bounds(neighbor_pos) or area_grid.has(neighbor_pos):
		return  # Skip if out of bounds or already occupied

	# Get potential regions for the neighbor position
	var neighbor_regions: Array = get_regions_for_position(neighbor_pos)
	if neighbor_regions.is_empty():
		return  # No valid regions found for this neighbor position

	# Select and place a suitable neighbor tile
	var neighbor_key = neighbor_regions.pick_random()
	var neighbor_tile = find_suitable_neighbor_tile(current_tile, direction, neighbor_key, neighbor_pos)

	if neighbor_tile != null:
		area_grid[neighbor_pos] = neighbor_tile
	else:
		print_debug("No suitable neighbor tile found for direction: ", direction)


# Function to find a suitable neighbor tile that fits the specified position
func find_suitable_neighbor_tile(current_tile: Tile, direction: String, neighbor_key: String, neighbor_pos: Vector2) -> Tile:
	# Get the list of all potential neighbor tiles
	var potential_tiles: Array = current_tile.get_neighbor_tiles(direction, neighbor_key)

	# Filter out any tiles that have already been tried for this position
	var tried_tiles_for_position = tried_tiles.get(Vector2(int(neighbor_pos.x), int(neighbor_pos.y)), [])
	var filtered_tiles: Array = []
	for tile in potential_tiles:
		if tile not in tried_tiles_for_position:
			filtered_tiles.append(tile)

	# Continue selecting tiles based on weight until a suitable one is found
	while not filtered_tiles.is_empty():
		# Select a tile based on weight using pick_tile_from_list
		var selected_tile: Tile = current_tile.pick_tile_from_list(filtered_tiles)

		# If the selected tile fits, return it
		if can_tile_fit(neighbor_pos, selected_tile):
			return selected_tile

		# If the tile doesn't fit, exclude it and remove it from the list
		exclude_tile_from_cell(int(neighbor_pos.x), int(neighbor_pos.y), selected_tile)
		filtered_tiles.erase(selected_tile)  # Remove the tile from the selection pool

	# If no valid tile was found, return null
	print_debug("No suitable neighbor tile found after trying all weighted possibilities for direction: ", direction)
	return null


# Function to place the starting tile in the center of the grid
# The starting tile is selected from the tile_dictionary using specified parameters
func place_starting_tile(center: Vector2) -> Tile:
	# Parameters for the starting tile: neighbor_key "urban", connection "road", direction "north"
	var starting_tiles = tile_dictionary.get("urban", {}).get("road", {}).get("north", {}).values()
	var starting_tile = starting_tiles.pick_random() if starting_tiles.size() > 0 else null

	if starting_tile:
		area_grid[center] = starting_tile
	else:
		print_debug("Failed to find a suitable starting tile")

	return starting_tile

# An algorithm that takes an area id and gets the required maps and instances them into tiles
# 1. Get the DOvermaparea from Runtimedata.overmapareas.by_id(area_id)
# 2. Get the regions from dovermaparea.regions. This will be a dictionary where the region name 
# is the key and the region data is the value. The value will be of the DOvermaparea.Region class
# 3. For each region:
# 3.1 Create a new key in tile_dictionary for the region name
# 3.2 Get the region.maps array. Each item in the array will be something like: {"id": "house_02","weight": 8}
# 3.3. For each map, get the DMap from Runtimedata.maps.by_id(map_id)
# 4. Leave the rest of the function unaltered.
func create_tile_entries() -> void:
	tile_catalog.clear()
	tile_dictionary.clear()

	if dovermaparea == null:
		print_debug("create_tile_entries: Overmap area not found")
		return

	# Step 2: Get the regions from the overmap area
	var regions: Dictionary = dovermaparea.regions
	var rotations: Array = [0, 90, 180, 270]

	# Step 3: Loop through each region to create tile entries
	for region_name in regions.keys():
		var region_data: DOvermaparea.Region = regions[region_name]

		# Step 3.1: Create a new key in the tile_dictionary for the region name
		if not tile_dictionary.has(region_name):
			tile_dictionary[region_name] = {}

		# Step 3.2: Get the maps from the region data
		var maps = region_data.maps
		for map_data in maps:
			var map_id = map_data.get("id", "")
			var map_weight = map_data.get("weight", 1)

			# Step 3.3: Retrieve the DMap from Gamedata using the map_id
			var map: RMap
			if Runtimedata.maps:
				map = Runtimedata.maps.by_id(map_id)
			else:
				var dmap = Gamedata.mods.by_id("Core").maps.by_id(map_id)
				map = RMap.new(null,map_id,dmap.dataPath)
				map.overwrite_from_dmap(dmap)
			if map == null:
				print_debug("create_tile_entries: Map not found for id: ", map_id)
				continue

			# Loop through each rotation to create Tile instances
			for rotation in rotations:
				var tile: Tile = Tile.new()
				tile.rmap = map
				tile.tile_dictionary = tile_dictionary
				tile.rotation_map = Gamedata.ROTATION_MAP
				tile.rotation = rotation
				tile.key = region_name  # The region name serves as the key (e.g., "urban", "suburban")
				tile.weight = map_weight  # Set the tile's weight from the map data
				tile.id = map_id + "_" + region_name + "_" + str(rotation)
				tile_catalog.append(tile)  # Add the tile to the catalog

				# Get the rotated connections for this tile
				var rotated_connections = tile.rotated_connections(rotation)

				# Organize the tile into the tile_dictionary based on its key, connection type, and direction
				for connection_direction in rotated_connections.keys():
					var connection_type = rotated_connections[connection_direction]

					# Ensure the nested dictionary structure exists
					if not tile_dictionary[region_name].has(connection_type):
						tile_dictionary[region_name][connection_type] = {}
					if not tile_dictionary[region_name][connection_type].has(connection_direction):
						tile_dictionary[region_name][connection_type][connection_direction] = {}

					# Store the tile in the dictionary under its key, connection type, and direction
					tile_dictionary[region_name][connection_type][connection_direction][tile.id] = tile


# Check if a tile can fit at the specified position by verifying connections with neighbors
func can_tile_fit(pos: Vector2, tile: Tile) -> bool:
	# Loop over north, east, south, and west to check all adjacent neighbors
	for direction in Gamedata.DIRECTION_OFFSETS.keys():
		var neighbor_pos = pos + Gamedata.DIRECTION_OFFSETS[direction]

		# Skip out-of-bounds or empty neighbors
		if not is_within_grid_bounds(neighbor_pos) or not area_grid.has(neighbor_pos):
			continue

		var neighbor_tile = area_grid[neighbor_pos]
		if not tile.are_connections_compatible(neighbor_tile, direction):
			return false
		if not neighbor_tile.are_connections_compatible(tile, Gamedata.ROTATION_MAP[180][direction]):
			return false

	return true


# Exclude a tile from being selected again for the specified position
func exclude_tile_from_cell(x: int, y: int, tile: Tile) -> void:
	var key = Vector2(x, y)
	if not tried_tiles.has(key):
		tried_tiles[key] = []
	tried_tiles[key].append(tile)


# Function to calculate and return the center of the map as whole numbers
func get_map_center() -> Vector2:
	# Calculate the center coordinates and round them to whole numbers
	var center_x = int(round(dimensions.x / 2))
	var center_y = int(round(dimensions.y / 2))
	return Vector2(center_x, center_y)


# Function to calculate the distance of a given position from the center of the map as a percentage
# This function uses the radius to perform the calculations
func get_distance_from_center_as_percentage(position: Vector2) -> float:
	# Get the center of the map
	var center = get_map_center()

	# Calculate the maximum possible distance (radius) from the center to the edge of the map
	var max_radius = max(center.distance_to(Vector2(0, 0)),
						 center.distance_to(Vector2(dimensions.x - 1, 0)),
						 center.distance_to(Vector2(0, dimensions.y - 1)),
						 center.distance_to(Vector2(dimensions.x - 1, dimensions.y - 1)))

	# Calculate the distance from the given position to the center
	var mydistance_to_center = center.distance_to(position)

	# Calculate the percentage distance relative to the maximum distance (radius)
	var percentage_distance = (mydistance_to_center / max_radius) * 100.0
	return percentage_distance


# Function to calculate the Euclidean distance from a given position to the center of the map
func distance_to_center(position: Vector2) -> float:
	# Calculate the center of the map
	var center = get_map_center()
	
	# Calculate the Euclidean distance from the position to the center
	var distance = position.distance_to(center)
	
	return distance


# Function to find regions that overlap with a given percentage
func get_regions_for_percentage(percentage: float) -> Array:
	var overlapping_regions: Array = []

	# Ensure the overmap area data is available
	if dovermaparea == null or not dovermaparea.regions:
		print_debug("get_regions_for_percentage: Overmap area data not found or has no regions.")
		return overlapping_regions

	# Loop through each region in the overmap area
	for region_name in dovermaparea.regions.keys():
		var region_data = dovermaparea.regions[region_name]
		var start_range = region_data.spawn_probability.range.start_range
		var end_range = region_data.spawn_probability.range.end_range

		# Check if the percentage is within the range of the current region
		if percentage >= start_range and percentage <= end_range:
			overlapping_regions.append(region_name)

	return overlapping_regions


# Function to get the list of region IDs for a given position
# It calculates the percentage distance from the center to the position and finds regions that overlap with this percentage
func get_regions_for_position(position: Vector2) -> Array:
	if not is_within_grid_bounds(position) or not distance_from_center_map.has(position):
		return []
	# Step 1: Calculate the percentage distance from the center for the given position
	var percentage_distance = distance_from_center_map[position]

	# Step 2: Use the calculated percentage to get the list of overlapping region IDs
	var overlapping_regions = get_regions_for_percentage(percentage_distance)

	return overlapping_regions


# Function to set up the FastNoiseLite properties
func setup_noise(myseed: int = 1234, frequency: float = 0.05) -> void:
	noise.seed = myseed
	noise.noise_type = FastNoiseLite.TYPE_PERLIN  # Using Perlin noise for natural variation
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM  # Fractal Brownian Motion for layered noise
	noise.fractal_octaves = 5  # Number of noise layers
	noise.fractal_gain = 0.5  # Influence of each octave
	noise.fractal_lacunarity = 2.0  # Detail level between octaves
	noise.frequency = frequency  # Frequency of the noise for overall pattern


# Function to set the dimensions for the area generator based on the dovermaparea data
func set_area_dimensions() -> void:
	if dimensions != Vector2.ZERO or dovermaparea == null:
		print_debug("set_area_dimensions: Dimensions already set or no overmap area data.")
		return
	# Randomly set dimensions using the min and max width/height from the dovermaparea data
	dimensions = Vector2(
		randi() % (dovermaparea.max_width - dovermaparea.min_width + 1) + dovermaparea.min_width,
		randi() % (dovermaparea.max_height - dovermaparea.min_height + 1) + dovermaparea.min_height
	)
