class_name OvermapAreaGenerator
extends RefCounted


# This is a stand-alone script that generates an area that can be placed on the overmap, such as a city
# It can be accessed trough OvermapAreaGenerator.new()
# The script has a function that returns the 2d grid on which maps are procedurally placed
# All map data comes from Gamedata.maps. The maps contain the weights and connections that are used


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
var area_grid: Dictionary = {}  # The resulting grid
# Dictionary to store the percentage distance from the center for each grid position
var distance_from_center_map: Dictionary = {}  # Key: Vector2 (position), Value: float (percentage distance)
var dimensions: Vector2 = Vector2(20,20) # The dimensions of the grid
var dovermaparea: DOvermaparea = null
var tile_catalog: Array = []  # List of all tile instances with rotations
var tried_tiles: Dictionary = {}  # Key: (x, y), Value: Set of tried tile IDs
var processed_tiles: Dictionary = {}  # Dictionary to track processed tiles
# Import the noise module for Perlin noise generation
var noise = FastNoiseLite.new()
# Define rotation mappings for how the directions shift depending on rotation
var rotation_map = {
	0: {"north": "north", "east": "east", "south": "south", "west": "west"},
	90: {"north": "east", "east": "south", "south": "west", "west": "north"},
	180: {"north": "south", "east": "west", "south": "north", "west": "east"},
	270: {"north": "west", "east": "north", "south": "east", "west": "south"}
}
# Define the direction offsets for neighboring positions
var direction_offsets: Dictionary = {
	"north": Vector2(0, -1),
	"east": Vector2(1, 0),
	"south": Vector2(0, 1),
	"west": Vector2(-1, 0)
}

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
	# dmap includes:
	# dmap.connections e.g., {"north": "road", "south": "ground", ...}
	# dmap.neighbor_keys e.g., {"urban": 100, "suburban": 50} what type of zone this map can spawn in.
	# This variable holds the neighbor keys that are allowed to spawn next to this map
	# dmap.neighbors e.g., {"north": {"urban": 100, "suburban": 50}, "south": ...}
	var dmap: DMap  # Map data
	var tile_dictionary: Dictionary # Reference to the tile_dictionary variable in the main script
	
	# Define rotation mappings for how the directions shift depending on rotation
	var rotation_map: Dictionary


	# Adjusts the connections based on the rotation
	func rotated_connections(rotation: int) -> Dictionary:
		var rotated_connections = {}
		for direction in dmap.connections.keys():
			# Adjust the direction based on the rotation using the rotation_map
			var new_direction = rotation_map[rotation][direction]

			# Keep the same connection type but adjust direction, so a road to north is now a road to west, for example
			rotated_connections[new_direction] = dmap.connections[direction]

		return rotated_connections

		
	# Function to pick a tile from the list based on the weights
	# tiles: A list of tiles that are limited by neighbor_key, connection and direction
	# For example, it may only contain tiles from "urban", connection "road" and "north" direction
	func pick_tile_from_list(tiles: Array) -> Tile:
		var total_weight: float = 0.0
		var weighted_tiles: Dictionary = {}  # Stores tiles and their corresponding weights

		# Step 1: Register the weight of each tile and count total weight
		for tile in tiles:
			var weight: float = tile.weight
			total_weight += weight
			weighted_tiles[tile] = weight

		# Step 2: Randomly select a tile based on the accumulated weights
		var rand_value: float = randf() * total_weight
		for tile in weighted_tiles.keys():
			rand_value -= weighted_tiles[tile]
			if rand_value <= 0:
				return tile  # Return the selected tile based on the weighted probability

		return null  # Return null if no tile is selected, which should not happen if weights are correct

	# Helper function to pick a neighbor key probabilistically based on weights from dmap.neighbors for the given direction
	func pick_neighbor_key(direction: String) -> String:
		# Ensure the direction exists in dmap.neighbors
		if not dmap.neighbors.has(direction):
			return ""  # Return an empty string if no valid direction is found

		var total_weight: float = 0.0
		var neighbor_weights = dmap.neighbors[direction]  # Get neighbor weights for the specified direction

		# Calculate the total weight for the neighbor keys in this direction
		for weight in neighbor_weights.values():
			total_weight += weight

		# Pick a key based on the weights
		var rand_value: float = randf() * total_weight
		for key in neighbor_weights.keys():
			rand_value -= neighbor_weights[key]
			if rand_value <= 0:
				return key  # Return the selected key based on weighted probability

		return ""  # Return an empty string if no key is picked, which shouldn't happen if weights are correct

	# Retrieves a list of neighbor tiles based on the direction, connection type, and rotation
	func get_neighbor_tiles(direction: String, neighbor_key: String) -> Array:
		if neighbor_key == "" or not tile_dictionary.has(neighbor_key):
			return []  # Return an empty list if no valid neighbor key is found

		# Step 2: Determine the connection type for the provided direction based on tile rotation
		var rotated_connections: Dictionary = rotated_connections(rotation)
		var connection_type: String = rotated_connections.get(direction, "")

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
	
	# Check if neighbor can be a neighbor of this tile based on the neighbor keys
	# neighbor: The neighbor of this tile that you want to test for compatibility
	func are_neighbor_keys_compatible(neighbor: Tile) -> bool:
		# Loop over directions north, east, south, west
		for direction: String in dmap.neighbors.keys():
			# Test if neighbor.key can be a neighbor in this direction
			# for example, this check will exclude all "field" tiles for the "north" direction
			# if the "north" direcation only wants to neighbor to "urban" or "suburban"
			if dmap.neighbors[direction].has(neighbor.key):
				return true
		return false
	
	# Adjusts weights for neighboring tiles based on neighbor keys
	func adjust_weights_based_on_neighbors(neighbors: Array, x: int, y: int) -> void:
		# Dictionary to group neighbors by their keys (e.g., urban, suburban, etc.)
		var neighbor_groups: Dictionary = {}
		var neighbor_key_weights = dmap.neighbor_keys  # Get current tile's neighbor key weights
		
		# Step 1: Group neighbors by their key
		for neighbor in neighbors:
			var key = neighbor.key
			if not neighbor_groups.has(key):
				neighbor_groups[key] = []
			neighbor_groups[key].append(neighbor)
		
		# Step 2: Adjust weights for each group
		for key in neighbor_groups.keys():
			var group = neighbor_groups[key]
			var total_weight: float = 0.0
			
			# Step 3: Normalize the weights within each group
			for neighbor in group:
				total_weight += neighbor.weight  # Sum all original weights
				
			# Apply normalized weights
			for neighbor in group:
				var normalized_weight = float(neighbor.weight) / total_weight  # Normalize
				var adjusted_weight = normalized_weight * neighbor_key_weights.get(key, 0)  # Apply key weight
				
				# Update the neighbor's weight


func generate_grid() -> Dictionary:
	area_grid.clear()
	#create_tile_entries()
	for i in range(grid_width):
		for j in range(grid_height):
			var cell_key = Vector2(i, j)
			area_grid[cell_key] = tile_catalog.pick_random()
	return area_grid


func generate_city():
	var cell_order = get_cell_processing_order()
	for cell in cell_order:
		var success = place_tile_at(cell.x, cell.y)
		if not success:
			# Implement backtracking if placement fails
			if not backtrack(cell.x, cell.y):
				print_debug("Failed to generate city. No valid tile placements available.")
				return


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

		for direction in direction_offsets.keys():
			var neighbor_position = current_position + direction_offsets[direction]

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
	# Get the tile at the specified position, if present
	var current_tile = null
	if area_grid.has(position):
		current_tile = area_grid[position]
	else:
		print_debug("No tile present at the specified position.")
		return  # If there's no tile at the starting position, exit the function

	# Loop over each direction, get the neighboring tile using the tile's get_neighbor_tile function, and place it on the area_grid
	if current_tile != null:
		for direction: String in direction_offsets.keys():
			var neighbor_pos: Vector2 = position + direction_offsets[direction]
			var neighbor_regions: Array = get_regions_for_position(neighbor_pos)

			# Check if the neighbor position is within bounds and has not been processed yet
			if is_within_grid_bounds(neighbor_pos) and not area_grid.has(neighbor_pos) and neighbor_regions.size() > 0:
				var neighbor_key: String = neighbor_regions.pick_random()
				var neighbor_tile: Tile = current_tile.get_neighbor_tile(direction, neighbor_key)

				# Retry mechanism to ensure the tile fits with all adjacent neighbors
				if not neighbor_tile == null and not can_tile_fit(neighbor_pos, neighbor_tile):
					# Exclude the incompatible tile and try a different one
					exclude_tile_from_cell(neighbor_pos.x, neighbor_pos.y, neighbor_tile)
					neighbor_tile = current_tile.get_neighbor_tile(direction, neighbor_key)

				if neighbor_tile != null:
					area_grid[neighbor_pos] = neighbor_tile
				else:
					print_debug("No suitable neighbor tile found for direction: ", direction)


# Function to place the starting tile in the center of the grid
# The starting tile is selected from the tile_dictionary using specified parameters
func place_starting_tile(center: Vector2) -> Tile:
	# Parameters for the starting tile: neighbor_key "urban", connection "road", direction "north"
	var starting_tiles = tile_dictionary.get("urban", {}).get("road", {}).get("north", {}).values()
	var starting_tile = starting_tiles.pick_random() if starting_tiles.size() > 0 else null

	if starting_tile:
		area_grid[center] = starting_tile
		print_debug("Placed starting tile at the center:", center)
	else:
		print_debug("Failed to find a suitable starting tile")

	return starting_tile

# An algorithm that takes an area id and gets the required maps and instances them into tiles
# 1. Get the DOvermaparea from Gamedata.overmapareas.by_id(area_id)
# 2. Get the regions from dovermaparea.regions. This will be a dictionary where the region name 
# is the key and the region data is the value. The value will be of the DOvermaparea.Region class
# 3. For each region:
# 3.1 Create a new key in tile_dictionary for the region name
# 3.2 Get the region.maps array. Each item in the array will be something like: {"id": "house_02","weight": 8}
# 3.3. For each map, get the DMap from Gamedata.maps.by_id(map_id)
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
			var map: DMap = Gamedata.maps.by_id(map_id)
			if map == null:
				print_debug("create_tile_entries: Map not found for id: ", map_id)
				continue

			# Loop through each rotation to create Tile instances
			for rotation in rotations:
				var tile: Tile = Tile.new()
				tile.dmap = map
				tile.tile_dictionary = tile_dictionary
				tile.rotation_map = rotation_map
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




# Used to place a tile at this coordinate
# Gets a list of tiles that fit here, picks one based on the weight,
# And assigns it to the grid
func place_tile_at(x: int, y: int) -> bool:
	var possible_tiles = get_possible_tiles(x, y)
	if possible_tiles.empty():
		return false  # Cannot place any tile here

	# Apply weights to select a tile probabilistically
	var total_weight = 0.0
	for tile in possible_tiles:
		total_weight += tile.weight

	var rand_value = randf() * total_weight
	for tile in possible_tiles:
		rand_value -= tile.weight
		if rand_value <= 0:
			area_grid[Vector2(x,y)] = tile
			return true

	return false  # Should not reach here if weights are correctly calculated


func get_possible_tiles(x: int, y: int) -> Array:
	var possible_tiles = []

	var key = Vector2(x, y)
	var excluded_tiles = tried_tiles[key]

	for tile in tile_catalog:
		if tile.id in excluded_tiles:
			continue  # Skip tiles that have already been tried
		if can_tile_fit(Vector2(x, y), tile):
			possible_tiles.append(tile)

	return possible_tiles


# Function to check if a tile fits at the specified position considering all neighbors
func can_tile_fit(pos: Vector2, tile: Tile) -> bool:
	# Loop over north, east, south, and west to check all adjacent neighbors
	for direction in direction_offsets.keys():
		var offset = direction_offsets[direction]
		var neighbor_pos = pos + offset  # The coordinate in the specified direction

		# Ensure the neighbor position is within bounds
		if not is_within_grid_bounds(neighbor_pos):
			continue  # Skip out-of-bounds neighbors

		# Check if there's a tile in the neighbor position
		if area_grid.has(neighbor_pos):
			var neighbor_tile = area_grid[neighbor_pos]

			# Check neighbor key compatibility. This prevents incompatible zone types from being adjacent.
			if not tile.are_neighbor_keys_compatible(neighbor_tile):
				return false

			# Check connection compatibility for both tiles (i.e., bidirectional fit)
			if not tile.are_connections_compatible(neighbor_tile, direction):
				return false
			if not neighbor_tile.are_connections_compatible(tile, rotation_map[180][direction]):
				return false

	return true  # The tile fits with all adjacent neighbors


func backtrack(x: int, y: int) -> bool:
	## Remove the tile from the current cell
	#city_grid.set(x, y, null)
	## Get previous cell coordinates
	#var prev_cell = get_previous_cell(x, y)
	#if prev_cell == null:
		#return false  # Cannot backtrack further
	## Remove the tile from the previous cell
	#var prev_tile = city_grid.get(prev_cell.x, prev_cell.y)
	#if prev_tile == null:
		#return false  # No tile to backtrack
#
	## Exclude the previously tried tile and attempt to place a different tile
	#exclude_tile_from_cell(prev_cell.x, prev_cell.y, prev_tile)
	#return place_tile_at(prev_cell.x, prev_cell.y)
	return false


func exclude_tile_from_cell(x: int, y: int, tile: Tile):
	var key = Vector2(x, y)
	if not tried_tiles.has(key):
		tried_tiles[key] = tile


# Function to determine the order of cell processing, using a plus pattern from the center outward
func get_cell_processing_order() -> Array:
	var order = []
	var visited = {}  # Dictionary to keep track of visited coordinates

	# Start at the center of the grid
	var center = Vector2(grid_width / 2, grid_height / 2)
	order.append(center)
	visited[center] = true

	# Define the directions in a plus pattern: North, South, West, East
	var directions = [Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0)]

	# Add the first set of tiles in the plus pattern around the center
	var queue = []

	for direction in directions:
		var neighbor = center + direction
		if neighbor.x >= 0 and neighbor.x < grid_width and neighbor.y >= 0 and neighbor.y < grid_height:
			order.append(neighbor)
			queue.append(neighbor)
			visited[neighbor] = true

	# Continue expanding outward in a plus pattern
	while not queue.empty():
		var current = queue.pop_front()

		# Expand from the current position in the four primary directions
		for direction in directions:
			var neighbor = current + direction

			# Check if the neighbor is within bounds and has not been visited yet
			if neighbor.x >= 0 and neighbor.x < grid_width and neighbor.y >= 0 and neighbor.y < grid_height:
				if not visited.has(neighbor):
					order.append(neighbor)
					queue.append(neighbor)
					visited[neighbor] = true  # Mark as visited

	return order


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
	var distance_to_center = center.distance_to(position)

	# Calculate the percentage distance relative to the maximum distance (radius)
	var percentage_distance = (distance_to_center / max_radius) * 100.0
	return percentage_distance


# Function to calculate the Euclidean distance from a given position to the center of the map
func distance_to_center(position: Vector2) -> float:
	# Calculate the center of the map
	var center = get_map_center()
	
	# Calculate the Euclidean distance from the position to the center
	var distance = position.distance_to(center)
	
	return distance


# Function to calculate the angle from a given position to the center of the map
func angle_to_center(position: Vector2) -> float:
	# Calculate the center of the map
	var center = get_map_center()
	
	# Calculate the angle from the position to the center
	var angle = (center - position).angle()
	
	return angle


# Function to get the furthest position from the center along a given angle within the map dimensions
func furthest_position_in_angle(angle: float) -> Vector2:
	var center = get_map_center()

	# Calculate the direction vector using the angle
	var direction = Vector2(cos(angle), sin(angle))

	# Initialize the furthest position as the center
	var furthest_position = center

	# Loop to find the furthest position along the angle until it hits the map boundary
	while is_within_grid_bounds(furthest_position + direction):
		furthest_position += direction

	# Return the last valid position within the map bounds
	return furthest_position.round()


# Function to calculate the percentage distance of a position from the center relative to the furthest position in that direction
func calculate_percentage_distance_from_center(position: Vector2) -> float:
	var center = get_map_center()

	# Step 1: Calculate the angle from the position to the center
	var angle_to_center = angle_to_center(position)

	# Step 2: Find the furthest position from the center in that angle within the map bounds
	var furthest_position = furthest_position_in_angle(angle_to_center)

	# Step 3: Calculate the distance from the center to the given position and to the furthest position
	var distance_to_center = distance_to_center(position)
	var max_distance_to_center = distance_to_center(furthest_position)

	# Step 4: Treat the center as 0% and the furthest position as 100%, calculate the percentage distance
	var percentage_distance = (distance_to_center / max_distance_to_center) * 100.0

	return percentage_distance


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
	if not is_within_grid_bounds(position):
		return []
	# Step 1: Calculate the percentage distance from the center for the given position
	var percentage_distance = distance_from_center_map[position]
	#var percentage_distance = get_distance_from_center_as_percentage(position)
	#var percentage_distance = calculate_percentage_distance_from_center(position)

	# Step 2: Use the calculated percentage to get the list of overlapping region IDs
	var overlapping_regions = get_regions_for_percentage(percentage_distance)

	return overlapping_regions


# Function to set up the FastNoiseLite properties
func setup_noise(seed: int = 1234, frequency: float = 0.05) -> void:
	noise.seed = seed
	noise.noise_type = FastNoiseLite.TYPE_PERLIN  # Using Perlin noise for natural variation
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM  # Fractal Brownian Motion for layered noise
	noise.fractal_octaves = 5  # Number of noise layers
	noise.fractal_gain = 0.5  # Influence of each octave
	noise.fractal_lacunarity = 2.0  # Detail level between octaves
	noise.frequency = frequency  # Frequency of the noise for overall pattern
