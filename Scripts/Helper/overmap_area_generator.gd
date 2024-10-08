class_name OvermapAreaGenerator
extends RefCounted


# This is a stand-alone script that generates an area that can be placed on the overmap, such as a city
# It can be accessed trough OvermapAreaGenerator.new()
# The script has a function that returns the 2d grid on which maps are procedurally placed
# All map data comes from Gamedata.maps. The maps contain the weights and connections that are used


var grid_width: int = 20
var grid_height: int = 20
var area_grid: Dictionary = {}  # The resulting grid
var tile_catalog = []  # List of all tile instances with rotations
var tried_tiles = {}  # Key: (x, y), Value: Set of tried tile IDs

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
	var rotation_map = {
		0: {"north": "north", "east": "east", "south": "south", "west": "west"},
		90: {"north": "west", "east": "north", "south": "east", "west": "south"},
		180: {"north": "south", "east": "west", "south": "north", "west": "east"},
		270: {"north": "east", "east": "south", "south": "west", "west": "north"}
	}

	# Adjusts the connections based on the rotation
	func rotated_connections(rotation: int) -> Dictionary:
		var rotated_connections = {}
		for direction in dmap.connections.keys():
			# If the direction is "north" and the rotation is 90, new_direction will be "west"
			var new_direction = rotation_map[rotation][direction]  # Adjust the direction based on the rotation
			# Keep the same connection type but adjust direction, so a road to north is now a road to west
			rotated_connections[new_direction] = dmap.connections[direction]  
		return rotated_connections
	
	# Helper function to pick a neighbor key probabilistically based on weights
	func pick_neighbor_key() -> String:
		var total_weight: float = 0.0
		for weight in dmap.neighbor_keys.values():
			total_weight += weight
		
		var rand_value: float = randf() * total_weight
		for key in dmap.neighbor_keys.keys():
			rand_value -= dmap.neighbor_keys[key]
			if rand_value <= 0:
				return key
		return ""  # Return an empty string if no key is picked, should not happen if weights are correct

	# Retrieves a list of neighbor tiles based on the direction, connection type, and rotation
	func get_neighbor_tiles(direction: String) -> Array:
		# Step 1: Pick a neighbor key using the weighted selection
		var neighbor_key: String = pick_neighbor_key()
		if neighbor_key == "":
			return []  # Return an empty list if no valid neighbor key is found

		# Step 2: Determine the connection type for the provided direction based on tile rotation
		var rotated_connections: Dictionary = rotated_connections(rotation)
		var connection_type: String = rotated_connections.get(direction, "")

		# Step 3: Retrieve the list of tiles from tile_dictionary based on the neighbor key, connection type, and direction
		if tile_dictionary.has(neighbor_key) and tile_dictionary[neighbor_key].has(connection_type) and tile_dictionary[neighbor_key][connection_type].has(direction):
			return tile_dictionary[neighbor_key][connection_type][direction].values()  # Return the list of tiles
		else:
			return []  # Return an empty list if no matching tiles are found

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
	create_tile_entries()
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
				print("Failed to generate city. No valid tile placements available.")
				return


# An algorithm that loops over all Gamedata.maps and creates a Tile for: 
# 1. each rotation of the map, and 2. each neighbor key.
# Then it organizes the tiles into tile_dictionary based on their key, connection, and rotation.
# So one map can have a maximum of 4 TileInfo variants, multiplied by the amount of neighbor keys.
func create_tile_entries() -> void:
	tile_catalog.clear()
	tile_dictionary.clear()
	var maps: Dictionary = Gamedata.maps.get_all()
	var rotations: Array = [0, 90, 180, 270]

	for map: DMap in maps.values():
		for key in map.neighbor_keys.keys():
			for myrotation in rotations:
				var mytile: Tile = Tile.new()
				mytile.dmap = map
				mytile.tile_dictionary = tile_dictionary
				mytile.rotation = myrotation
				mytile.key = key  # May be "urban", "suburban", etc.
				mytile.id = map.id + "_" + str(key) + "_" + str(myrotation)
				tile_catalog.append(mytile)  # Add tile to the catalog

				# Get the rotated connections for this tile
				var rotated_connections = mytile.rotated_connections(myrotation)

				# Organize the tile into the tile_dictionary
				for connection_direction in rotated_connections.keys():
					var connection_type = rotated_connections[connection_direction]

					# Ensure the dictionary structure exists
					if not tile_dictionary.has(key):
						tile_dictionary[key] = {}
					if not tile_dictionary[key].has(connection_type):
						tile_dictionary[key][connection_type] = {}
					if not tile_dictionary[key][connection_type].has(connection_direction):
						tile_dictionary[key][connection_type][connection_direction] = {}

					# Store the tile in the dictionary under its key, connection type, and direction
					tile_dictionary[key][connection_type][connection_direction][mytile.id] = mytile


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
		if can_tile_fit(x, y, tile):
			possible_tiles.append(tile)

	return possible_tiles


func can_tile_fit(x: int, y: int, tile: Tile) -> bool:
	# Define a dictionary to map directions to their coordinate offsets
	var direction_offsets = {
		"north": Vector2(0, -1),
		"south": Vector2(0, 1),
		"east": Vector2(1, 0),
		"west": Vector2(-1, 0)
	}

	# Loop over north, east, south and west
	for direction in direction_offsets.keys():
		var offset = direction_offsets[direction] # Get the offset for this direction
		var neighbor_pos = Vector2(x, y) + offset # The coordinate in the direction provided

		# Ensure the neighbor position is within bounds
		if neighbor_pos.x < 0 or neighbor_pos.x >= grid_width or neighbor_pos.y < 0 or neighbor_pos.y >= grid_height:
			continue  # Skip out-of-bounds neighbors

		# Check if there's a tile in the neighbor position
		if area_grid.has(neighbor_pos):
			var neighbor_tile = area_grid[neighbor_pos]

			# Check neighbor key compatibility. This is useful to prevent a "field" from spawning
			# next to a "urban" tile.
			if not tile.are_neighbor_keys_compatible(neighbor_tile):
				return false

			# Check connection compatibility
			if not tile.are_connections_compatible(neighbor_tile, direction):
				return false

	return true  # Tile can fit here


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


func get_cell_processing_order() -> Array:
	var order = []
	# Implement a heuristic to determine the order
	# For example, use a priority queue based on the number of neighboring tiles
	return order


func normalize_tile_weights(tiles: Array) -> void:
	var total_weight = 0.0
	for tile in tiles:
		total_weight += tile.weight

	for tile in tiles:
		tile.normalized_weight = tile.weight / total_weight


func adjust_tile_weights_based_on_neighbors(possible_tiles: Array, x: int, y: int) -> void:
	# Example: Increase weight if the tile shares neighbor keys with adjacent tiles
	#var adjacent_tiles = get_adjacent_tiles(x, y)
	#for tile in possible_tiles:
		#for neighbor in adjacent_tiles:
			#if neighbor == null:
				#continue
			#if are_neighbor_keys_compatible(tile, neighbor):
				#tile.weight *= 1.2  # Increase weight by 20%
	pass
