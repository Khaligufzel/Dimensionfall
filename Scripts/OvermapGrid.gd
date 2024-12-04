class_name OvermapGrid
extends RefCounted


# A grid that holds grid_width by grid_height of cells
# This is used to segment the overmap grid for saving and loading
# A maximum of 9 grids can exist at once. Grids that are far away will be unloaded
# Loading a grid will happen when the player is 25 cells away from the border of the next grid
# Unloading will happen if the player is 50 cells away from the border of the previous grid

# Should be 100 apart in any direction since it holds 100 cells. Starts at 0,0
var pos: Vector2 = Vector2.ZERO
var cells: Dictionary = {}
# Dictionary to store map_id and their corresponding coordinates
var map_id_to_coordinates: Dictionary = {}
var grid_width: int = 100 # TODO: Pass the global grid_width to this class
var grid_height: int = 100
# Dictionary to store lists of area positions sorted by dovermaparea.id
var area_positions: Dictionary = {}
var road_maps: Array = Runtimedata.maps.get_maps_by_category("Road")
var forest_road_maps: Array = Runtimedata.maps.get_maps_by_category("Forest Road")
const NOISE_VALUE_PLAINS = -0.2

enum Region {
	FOREST,
	PLAINS
}


# A cell in the grid. This will tell you it's coordinate and if it's part
# of something bigger like the tacticalmap
class map_cell:
	# Enum for revealed states
	enum RevealedState {
		HIDDEN,  # Default state. The cell has been instanced onto a grid, nothimg more
		REVEALED, # the map has been revealed on the overmap when the player got close enough
		EXPLORED, # the map has been loaded as a chunk in the player's proximity at least once
		VISITED # the player has entered the boundary of the map's coordinates
	}

	var region = Region.PLAINS
	var coordinate_x: int = 0
	var coordinate_y: int = 0
	var rmap: RMap = null
	var map_id: String = "field_grass_basic_00.json":
		set(value):
			map_id = value
			rmap = Runtimedata.maps.by_id(map_id)
	var tacticalmapname: String = "town_00.json"
	var revealed: int = RevealedState.HIDDEN  # Default state is HIDDEN
	var rotation: int = 0  # Will be any of [0, 90, 180, 270]

	func get_data() -> Dictionary:
		return {
			"region": region,
			"coordinate_x": coordinate_x,
			"coordinate_y": coordinate_y,
			"map_id": map_id,
			"tacticalmapname": tacticalmapname,
			"revealed": revealed,
			"rotation": rotation
		}

	func set_data(newdata: Dictionary):
		if newdata.is_empty():
			return
		region = newdata.get("region", Region.PLAINS)
		coordinate_x = newdata.get("coordinate_x", 0)
		coordinate_y = newdata.get("coordinate_y", 0)
		map_id = newdata.get("map_id", "field_grass_basic_00.json")
		tacticalmapname = newdata.get("tacticalmapname", "town_00.json")
		revealed = newdata.get("revealed", false)
		rotation = newdata.get("rotation", 0)

	func get_sprite() -> Texture:
		return rmap.sprite
	
	# Function to return formatted information about the map cell
	func get_info_string() -> String:
		# If the cell is not revealed, notify the player
		if revealed == RevealedState.HIDDEN:
			return "This area has not \nbeen explored yet."
		
		# If revealed, display the detailed information
		var pos_string: String = "Pos: (" + str(coordinate_x) + ", " + str(coordinate_y) + ")"
		
		# Use dmap's name and description instead of map_id
		var map_name_string: String = "\nName: " + rmap.name
		
		var region_string: String = "\nRegion: " + region_type_to_string(region)
		var challenge_string: String = "\nChallenge: Easy"  # Placeholder for now
		
		# Combine all the information into one formatted string
		return pos_string + map_name_string + region_string + challenge_string


	# Helper function to convert Region enum to string
	func region_type_to_string(region_type: int) -> String:
		match region_type:
			Region.PLAINS:
				return "Plains"
			Region.FOREST:
				return "Forest"
		return "Unknown"

	func set_revealed_state(new_state: int) -> void:
		# Ensure the new state is valid
		if new_state in RevealedState.values():
			revealed = new_state
		else:
			push_error("Invalid state for map_cell revealed: " + str(new_state))

	func is_revealed() -> bool:
		# Returns true if the revealed state is REVEALED, EXPLORED, or VISITED
		return revealed in [RevealedState.REVEALED, RevealedState.EXPLORED, RevealedState.VISITED]

	func reveal():
		# Automatically upgrade the revealed state
		if revealed < RevealedState.REVEALED:
			revealed = RevealedState.REVEALED

	func explore():
		# Automatically upgrade the state to explored
		if revealed < RevealedState.EXPLORED:
			revealed = RevealedState.EXPLORED

	func visit():
		# Automatically upgrade the state to visited
		revealed = RevealedState.VISITED
		
	func matches_reveal_condition(reveal_condition: String, exact_match: bool = false) -> bool:
		# Convert reveal_condition to uppercase for case-insensitive matching
		reveal_condition = reveal_condition.to_upper()

		if exact_match:
			# Match only the exact reveal condition
			match reveal_condition:
				"HIDDEN":
					return revealed == RevealedState.HIDDEN
				"REVEALED":
					return revealed == RevealedState.REVEALED
				"EXPLORED":
					return revealed == RevealedState.EXPLORED
				"VISITED":
					return revealed == RevealedState.VISITED
			return false  # Return false for unknown conditions
		else:
			# Match broader reveal conditions
			match reveal_condition:
				"HIDDEN":
					return revealed == RevealedState.HIDDEN
				"REVEALED":
					return is_revealed()
				"EXPLORED":
					return revealed in [RevealedState.EXPLORED, RevealedState.VISITED]
				"VISITED":
					return revealed == RevealedState.VISITED
			return false  # Return false for unknown conditions



# Translates local grid coordinates to global coordinates
func local_to_global(local_coord: Vector2) -> Vector2:
	return local_coord + pos * grid_width

func get_data() -> Dictionary:
	var mydata: Dictionary = {"pos": pos, "cells": {}}
	for cell_key in cells.keys():
		mydata["cells"][str(cell_key)] = cells[cell_key].get_data()
	return mydata

func set_data(mydata: Dictionary) -> void:
	var newpos = mydata.get("pos", "0,0")
	pos = Vector2(newpos.split(",")[0].to_int(), newpos.split(",")[1].to_int())
	cells.clear()
	for cell_key in mydata["cells"].keys():
		var cell = map_cell.new()
		cell.set_data(mydata["cells"][cell_key])
		cells[Vector2(cell_key.split(",")[0].to_int(), cell_key.split(",")[1].to_int())] = cell

# Updates a cell's map ID and rotation using local coordinates
func update_cell(local_coord: Vector2, map_id: String, rotation: int):
	if cells.has(local_coord):
		cells[local_coord].map_id = map_id.replace(".json", "")
		cells[local_coord].rotation = rotation

# Helper function to build the map_id_to_coordinates dictionary
func build_map_id_to_coordinates():
	map_id_to_coordinates.clear()
	for cell_key in cells.keys():
		var cell = cells[cell_key]
		var map_id = cell.map_id

		if not map_id_to_coordinates.has(map_id):
			map_id_to_coordinates[map_id] = []
		
		map_id_to_coordinates[map_id].append(cell_key)


# Function to connect cities by creating a river-like path and update all road connections at the end
func connect_cities_by_riverlike_path(city_positions: Array) -> void:
	var all_road_positions: Array = []  # To collect all road positions

	# Step 1: Generate paths between each city and assign road maps
	for i in range(city_positions.size() - 1):
		var start_pos = city_positions[i]
		var end_pos = city_positions[i + 1]

		# Use local_to_global for global position adjustments
		var global_start = local_to_global(start_pos)
		var global_end = local_to_global(end_pos)

		# Generate an organic, winding path between the adjusted global positions
		var path = generate_winding_path(global_start, global_end)

		# Assign road maps to the generated path without updating connections
		update_path_on_grid(path)

		# Collect all positions in the path for later connection updates
		all_road_positions.append_array(path)

	# Step 2: Once all paths are generated, update road connections for all roads
	update_all_road_connections(all_road_positions)


# Generate a winding path between two global positions
# Global meaning they are independent of this grid's pos and are
# either contained within the range of this grid or not
# For example, the (-53,12) position is contained in the grid at (-1,0), 
# which holds positions (-100,0) to (-1,99)
func generate_winding_path(global_start: Vector2, global_end: Vector2) -> Array:
	var path = []
	var current = global_start
	while current.distance_to(global_end) > 1:
		if not path.has(current):
			path.append(current)
		var next_position = (global_end - current).normalized().round() + current
		# Ensure small deviations and avoid straight paths
		current = adjust_for_diagonal(next_position, current, path)
	append_unique(path, global_end)
	return path


# Helper function: Avoid straight paths and prefer neighbors
func adjust_for_diagonal(next_position: Vector2, current: Vector2, path: Array) -> Vector2:
	if is_diagonal(current, next_position):
		if randi() % 2 == 0:
			append_unique(path, current + Vector2(0, next_position.y - current.y))
		else:
			append_unique(path, current + Vector2(next_position.x - current.x, 0))
	return next_position


# Helper function: Append only if the position is not already in the array
func append_unique(path: Array, position: Vector2):
	if not path.has(position):
		path.append(position)


# Assign road maps without updating connections
func update_path_on_grid(path: Array) -> void:
	if road_maps.is_empty() or forest_road_maps.is_empty():
		print("Missing road or forest road maps!")
		return

	# Step 1: Assign road maps to path cells without updating connections
	for global_position in path:
		if cells.has(global_position):
			var cell = cells[global_position] # Will be a map_cell instance
			if not "Urban" in cell.rmap.categories: # Skip urban areas
				assign_road_map_to_cell(global_position, cell)


# Function to update all road connections, including edge cells across neighboring grids
func update_all_road_connections(road_positions: Array) -> void:
	var edge_data = get_edge_positions(road_positions)
	var edge_positions: Dictionary = edge_data["edge_positions"]
	var edgeglobals: Array = edge_data["edgeglobals"]

	# Step 2: Update connections for non-edge positions within this grid
	for global_position in road_positions:
		if cells.has(global_position) and not global_position in edgeglobals:
			var cell = cells[global_position]
			if not "Urban" in cell.rmap.categories:
				update_road_connections(global_position, cell)

	# Step 3: Handle connections for edge positions with neighboring grids
	for direction in edge_positions.keys():
		for edge_position in edge_positions[direction]: # All positions on the south border for example
			# Update within this grid first
			if cells.has(edge_position): # Should be true for all edge positions
				update_road_connections(edge_position, cells[edge_position])
			
			# Update in the neighboring grid
			var neighbor_pos: Vector2 = edge_position + Gamedata.DIRECTION_OFFSETS[direction]
			if neighbor_pos:
				var neighbor_grid: OvermapGrid = Helper.overmap_manager.get_grid_from_local_pos(neighbor_pos)
				var neighbor_cell = neighbor_grid.get_cell_from_global_pos(neighbor_pos) # A map_cell instance
				neighbor_grid.update_road_connections(neighbor_pos, neighbor_cell)


# Function to categorize road positions by grid edge
# Positions in road_positions are discarded if they are not on the edge of the grid
# Remaining positions will be on the edge of the current grid
# Example for the a grid with (-1,-1) as pos: 
# { "north": [], "east": [], "south": [(-17, -1), (-83, -1), (-82, -1), (-70, -1)], "west": [] }
# This example shows multiple positions on the south border of the grid.
# All positions on the south order have -1 as the y coordinate.
func get_edge_positions(road_positions: Array) -> Dictionary:
	var edge_positions: Dictionary = {"north": [], "east": [], "south": [], "west": []}
	var edgeglobals: Array = []

	for global_position in road_positions:
		if global_position.x == pos.x * grid_width:
			edge_positions["west"].append(global_position)
			edgeglobals.append(global_position)
		elif global_position.x == (pos.x + 1) * grid_width - 1:
			edge_positions["east"].append(global_position)
			edgeglobals.append(global_position)
		elif global_position.y == pos.y * grid_height:
			edge_positions["north"].append(global_position)
			edgeglobals.append(global_position)
		elif global_position.y == (pos.y + 1) * grid_height - 1:
			edge_positions["south"].append(global_position)
			edgeglobals.append(global_position)

	return {"edge_positions": edge_positions, "edgeglobals": edgeglobals}


# Assign the appropriate road map (forest or regular) to a cell
# cell: A map_cell instance
func assign_road_map_to_cell(global_position: Vector2, cell) -> void:
	# If it's a forest cell, assign a forest road, otherwise a normal road
	var map_to_use = road_maps
	if "Forest" in cell.rmap.categories:
		map_to_use = forest_road_maps
	var selected_map = map_to_use.pick_random()
	update_cell(global_position, selected_map.id, 0)


# Update the road connections for a cell based on its type (forest or non-forest)
# cell: A map_cell instance
func update_road_connections(global_position: Vector2, cell) -> void:
	if not "Road" in cell.rmap.categories and not "Forest Road" in cell.rmap.categories:
		return # Only update road cells
	# Get the required connections for this cell
	var needed_connections = get_needed_connections(global_position)
	# If it's a forest cell, find a matching forest road map, otherwise a regular road map
	var map_to_use = forest_road_maps if "Forest Road" in cell.rmap.categories else road_maps
	var matching_maps = get_road_maps_with_connections(map_to_use, needed_connections)
	if matching_maps.size() > 0:
		var selected_map = matching_maps.pick_random()
		update_cell(global_position, selected_map.id, selected_map.rotation)


# Function to determine if movement from pos1 to pos2 is diagonal
func is_diagonal(pos1: Vector2, pos2: Vector2) -> bool:
	var direction = pos2 - pos1
	return abs(direction.x) == 1 and abs(direction.y) == 1


# Function to determine the required connections for a road tile, including edge cases
func get_needed_connections(position: Vector2) -> Array:
	var directions: Array[String] = ["north", "east", "south", "west"]
	var connections: Array[String] = []
	# Define the categories to check
	var categories_to_check: Array[String] = ["Road", "Urban", "Forest Road"]

	# Iterate over each direction (north, east, south, west)
	for direction in directions:
		var neighbor_pos: Vector2 = position + Gamedata.DIRECTION_OFFSETS[direction]
		
		# Check if the neighbor exists in this grid
		if cells.has(neighbor_pos):
			var neighbor_cell = cells[neighbor_pos]

			# Check if any of the categories are present in the neighbor cell's categories
			for category in categories_to_check:
				if category in neighbor_cell.rmap.categories:
					connections.append(direction)
					break  # Exit loop early since we found a match
		else:
			# Check the neighboring grid for cells at boundaries
			var neighbor_cell = Helper.overmap_manager.get_grid_cell_from_local_pos(neighbor_pos)
			if neighbor_cell:
				# Same category check for the neighboring grid cell
				for category in categories_to_check:
					if category in neighbor_cell.rmap.categories:
						connections.append(direction)
						break  # Exit if match is found
	
	return connections



# Function to get road maps that match the required connections
func get_road_maps_with_connections(myroad_maps: Array, required_directions: Array) -> Array[Dictionary]:
	var matching_maps: Array[Dictionary] = []

	# Iterate through each road map
	for road_map in myroad_maps:
		# Check all possible rotations (0, 90, 180, 270)
		for rotation in [0, 90, 180, 270]:
			var rotated_connections = self.get_rotated_connections(road_map.connections, rotation)

			# Check if the rotated connections match the required directions
			if self.are_connections_matching(rotated_connections, required_directions):
				# If it matches, add a dictionary with map id and rotation
				matching_maps.append({
					"id": road_map.id,
					"rotation": rotation
				})
				break  # Stop checking other rotations for this road_map once a match is found

	return matching_maps


# Function to check if rotated connections match the required directions
func are_connections_matching(rotated_connections: Dictionary, required_directions: Array) -> bool:
	var directions: Array[String] = ["north", "east", "south", "west"]

	# Check if all required directions have a road connection
	for direction in required_directions:
		if rotated_connections.get(direction, "none") != "road":
			return false  # Any required direction that doesn't have a road connection fails

	# Ensure all remaining directions are ground connections
	for direction in directions:
		if direction not in required_directions:
			if rotated_connections.get(direction, "none") != "ground":
				return false  # Any other direction that isn't ground fails

	return true


# Function to get rotated connections based on rotation
func get_rotated_connections(connections: Dictionary, rotation: int) -> Dictionary:
	var rotated_connections = {}
	
	# Apply the rotation map to the connections
	for direction in connections.keys():
		var rotated_direction = Gamedata.ROTATION_MAP[rotation][direction]
		rotated_connections[rotated_direction] = connections[direction]

	return rotated_connections


# Function to place an area on the grid and return the valid position where it was placed
func place_area_on_grid(area_grid: Dictionary, placed_positions: Array, mapsize: Vector2) -> Vector2:
	var max_attempts = 100  # Combined attempt limit
	var attempts = 0
	var valid_position: Vector2 = Vector2(-1, -1)
	var is_far_enough = true

	while attempts < max_attempts:
		# Calculate remaining attempts to stay within the max_attempts limit
		var remaining_attempts = max_attempts - attempts
		# Find a candidate position with limited attempts
		valid_position = find_weighted_random_position(placed_positions, mapsize, remaining_attempts, false)
		attempts += remaining_attempts

		# Check if this position is at least 15 units away from each placed position
		for placed_pos in placed_positions:
			if valid_position.distance_to(placed_pos) < 15:
				is_far_enough = false
				break

		# If the position is valid, break from the loop
		if is_far_enough:
			break

	# If a valid position is found, place the area
	if valid_position != Vector2(-1, -1) and is_far_enough:
		for local_position in area_grid.keys():
			var adjusted_position = valid_position + local_position
			if area_grid.has(local_position):
				var tile = area_grid[local_position]
				if tile != null:
					update_cell(local_to_global(adjusted_position), tile.rmap.id, tile.rotation)
					placed_positions.append(adjusted_position)

		# Return the adjusted center of the placed area
		var center_offset = Vector2(int(mapsize.x / 2), int(mapsize.y / 2))
		return valid_position + center_offset

	# Return the invalid position if no valid placement is found
	return Vector2(-1, -1)


# Function to place overmap areas on this grid
func place_overmap_areas() -> void:
	var placed_positions = []  # Track positions that have already been placed
	area_positions.clear()

	# Loop to place up to 10 overmap areas on the grid
	for n in range(10):
		var mygenerator = OvermapAreaGenerator.new()
		var dovermaparea = Runtimedata.overmapareas.by_id(Runtimedata.overmapareas.get_random_area().id)
		mygenerator.dovermaparea = dovermaparea

		# Generate the area
		var area_grid: Dictionary = mygenerator.generate_area(10000)
		if area_grid.size() > 0:
			# Use the dimensions from mygenerator after generating the area
			var map_dimensions = mygenerator.dimensions

			# Place the area and get the valid position
			var valid_position = place_area_on_grid(area_grid, placed_positions, map_dimensions)
			if valid_position != Vector2(-1, -1):
				# Ensure the area_positions dictionary has an array for this dovermaparea.id
				if not area_positions.has(dovermaparea.id):
					area_positions[dovermaparea.id] = []
				# Append the valid position to the list for this area's id
				area_positions[dovermaparea.id].append(valid_position)
		else:
			print("Failed to find a valid position for the overmap area.")


# Function to place tactical maps on this grid
func place_tactical_maps() -> void:
	var placed_positions = []
	for n in range(5):  # Loop to place up to 10 tactical maps on the grid
		var dmap: RTacticalmap = Runtimedata.tacticalmaps.get_random_map()

		var map_width = dmap.mapwidth
		var map_height = dmap.mapheight
		var chunks = dmap.chunks

		# Find a valid position on the grid to place the tactical map
		var position = find_weighted_random_position(placed_positions, Vector2(map_width, map_height), 100, true)
		if position == Vector2(-1, -1):  # If no valid position is found, skip this map placement
			print("Failed to find a valid position for tactical map")
			continue

		var random_x = position.x
		var random_y = position.y

		# Place the tactical map chunks on the grid, overwriting cells as needed
		for i in range(map_width):
			for j in range(map_height):
				var local_x = random_x + i
				var local_y = random_y + j
				if local_x < grid_width and local_y < grid_height:
					var cell_key = Vector2(local_x, local_y)
					var chunk_index = j * map_width + i
					var dchunk: RTacticalmap.TChunk = chunks[chunk_index]
					update_cell(local_to_global(cell_key), dchunk.id, dchunk.rotation)
					placed_positions.append(cell_key)  # Track the positions that have been occupied


# Function to generate cells for the grid
func generate_cells() -> void:
	for x in range(grid_width):
		for y in range(grid_height):
			# Calculate global coordinates based on grid position
			var global_x = pos.x * grid_width + x
			var global_y = pos.y * grid_height + y
			var cell_key = Vector2(global_x, global_y)

			# Determine region type based on noise values
			var region_type = get_region_type(global_x, global_y)
			var cell = map_cell.new()
			cell.coordinate_x = global_x
			cell.coordinate_y = global_y
			cell.region = region_type

			# Pick a map from the category based on the region type
			var maps_by_category = Runtimedata.maps.get_maps_by_category(region_type_to_string(region_type))
			if maps_by_category.size() > 0:
				cell.map_id = Helper.overmap_manager.pick_random_map_by_weight(maps_by_category)
			else:
				cell.map_id = "field_grass_basic_00.json"  # Fallback if no maps found
			# If you need to test a specific map, uncomment these two lines and put in your map name.
			# It will spawn the map at position (0,0), where the player starts
			#if global_x == 0 and global_y == 0:
				#cell.map_id = "radio_tower.json"

			# Add the cell to the grid's cells dictionary
			cells[cell_key] = cell

	# Place tactical maps and overmap areas on the grid, and connect cities
	place_overmap_areas()

	if area_positions.has("city"):
		connect_cities_by_hub_path(area_positions["city"])

	place_tactical_maps()
	
	# Connect cities on the borders with neighboring grids
	check_and_connect_neighboring_grids()
	
	# After modifications, rebuild the map_id_to_coordinates dictionary
	build_map_id_to_coordinates()


# Helper function to convert Region enum to string
func region_type_to_string(region_type: int) -> String:
	match region_type:
		Region.PLAINS:
			return "Plains"
		Region.FOREST:
			return "Forest"
	return "Unknown"


# Function to find a weighted random position within a maximum number of attempts
# Prevents placement within a radius of 15 from (0,0) for tactical maps if enforce_restricted_radius is true.
func find_weighted_random_position(placed_positions: Array, mapsize: Vector2, max_attempts: int, enforce_restricted_radius: bool) -> Vector2:
	var best_position = Vector2(-1, -1)
	var best_distance = 0
	var restricted_radius = 15  # Define the restricted radius
	var restricted_center = Vector2(0, 0)  # Center of the restricted area

	# Calculate the grid's global offset
	var grid_offset = pos * Vector2(grid_width, grid_height)
	
	# Loop within the specified maximum attempts
	for attempt in range(max_attempts):
		var random_x = randi() % (grid_width - int(mapsize.x) + 1)
		var random_y = randi() % (grid_height - int(mapsize.y) + 1)
		var position = Vector2(random_x, random_y)

		# Adjust position to account for grid offset
		var global_position = position + grid_offset

		# If enforcing the restricted radius, check the distance
		if enforce_restricted_radius:
			var distance_to_center = global_position.distance_to(restricted_center)
			if distance_to_center < restricted_radius:
				continue  # Skip this position if it's within the restricted radius

		# Check if this position is too close to already placed positions
		var is_unsuitable = false
		for placed_pos in placed_positions:
			if position.distance_to(placed_pos) < 15:
				is_unsuitable = true
				break

		# Skip unsuitable positions
		if is_unsuitable:
			continue

		# Calculate the distance to the nearest placed position
		var min_distance = INF
		for placed_pos in placed_positions:
			var dist = position.distance_to(placed_pos)
			if dist < min_distance:
				min_distance = dist

		# Update best position if this position is farther from others
		if min_distance > best_distance:
			best_position = position
			best_distance = min_distance

	return best_position


# Function to get region type based on noise value, rounded to the nearest 0.2
func get_region_type(x: int, y: int) -> int:
	var noise_value = Helper.overmap_manager.noise.get_noise_2d(float(x), float(y))

	# Compare the rounded noise value to determine the region type
	if noise_value < NOISE_VALUE_PLAINS:
		return Region.PLAINS
	else:
		return Region.FOREST


# Main function to connect cities by hub paths, calling separate functions for close city pairs and hub connections
func connect_cities_by_hub_path(city_positions: Array) -> void:
	var city_pairs: Array = get_city_pairs(city_positions)
	var all_road_positions: Array = []

	# Step 1: Handle hub connections for distant city pairs
	connect_distant_city_pairs_with_hubs(city_pairs, city_positions, all_road_positions)

	# Step 2: Finalize all road connections
	update_all_road_connections(all_road_positions)


# New function to connect city pairs directly if their distance is less than 40
func connect_close_city_pairs(city_pairs: Array, all_road_positions: Array) -> void:
	var connected_pairs: Dictionary = {}
	for pair in city_pairs:
		var city_a = pair["cities"][0]
		var city_b = pair["cities"][1]
		var distance = pair["distance"]


		# Avoid duplicate paths by using sorted key pairs
		var pair_key = [city_a, city_b]
		pair_key.sort()
		if connected_pairs.has(pair_key):
			continue
		connected_pairs[pair_key] = true
		
		# Connect directly if cities are close
		if distance < 40:
			var direct_path = generate_winding_path(local_to_global(city_a), local_to_global(city_b))
			update_path_on_grid(direct_path)
			all_road_positions.append_array(direct_path)


# Updated function to connect hubs to cities within 40 units and track connection counts for all cities
func connect_distant_city_pairs_with_hubs(city_pairs: Array, city_positions: Array, all_road_positions: Array) -> void:
	var city_hub_connections: Dictionary = {}
	var connected_hubs: Dictionary = {}
	var connection_counts: Dictionary = {}  # Dictionary to track connection counts per city

	# Initialize connection count for each city to 0
	for city_pos in city_positions:
		connection_counts[city_pos] = 0

	# Generate hubs based on city distances
	var hubs: Array = get_city_hubs(city_positions, city_pairs)

	# Loop through each hub to connect it to nearby cities
	for hub in hubs:
		for city_pos in city_positions:
			var distance = hub.distance_to(city_pos)
			
			# Only connect cities within 40 units
			if distance <= 40:
				# Generate a unique key to prevent duplicate connections
				var hub_city_key = [hub, city_pos]
				hub_city_key.sort()
				if connected_hubs.has(hub_city_key):
					continue  # Skip if this hub-city pair is already connected

				# Mark the hub-city pair as connected to prevent duplicates
				connected_hubs[hub_city_key] = true

				# Generate and store the path from hub to city
				var path_to_city = generate_winding_path(local_to_global(hub), local_to_global(city_pos))
				update_path_on_grid(path_to_city)
				all_road_positions.append_array(path_to_city)

				# Register the hub connection for this city
				city_hub_connections[city_pos] = hub

				# Increment the connection count for this city
				connection_counts[city_pos] += 1

	# Connect cities with zero connections
	connect_zero_connection_cities(city_positions, connection_counts, all_road_positions)


# New function to connect cities with zero connections to nearby cities within 40 units
func connect_zero_connection_cities(city_positions: Array, connection_counts: Dictionary, all_road_positions: Array) -> void:
	for city_pos in city_positions:
		if connection_counts[city_pos] == 0:
			for other_city in city_positions:
				# Skip if checking the same city or if already connected
				if other_city == city_pos:# or connection_counts[other_city] > 0:
					continue
				var distance = city_pos.distance_to(other_city)
				if distance <= 40:
					# Generate and store the path between the two cities
					var path_between_cities = generate_winding_path(local_to_global(city_pos), local_to_global(other_city))
					update_path_on_grid(path_between_cities)
					all_road_positions.append_array(path_between_cities)

					# Update connection counts for both cities
					connection_counts[city_pos] += 1
					connection_counts[other_city] += 1



# Custom sorting function to compare by distance (descending order)
func compare_distances_desc(a: Dictionary, b: Dictionary) -> bool:
	return a["distance"] < b["distance"]


# New function to create and sort city pairs by distance
func get_city_pairs(city_positions: Array) -> Array:
	var city_pairs = []
	for i in range(city_positions.size()):
		for j in range(i + 1, city_positions.size()):
			var dist = city_positions[i].distance_to(city_positions[j])
			city_pairs.append({"cities": [city_positions[i], city_positions[j]], "distance": dist})

	# Sort pairs by distance in descending order using custom comparison function
	city_pairs.sort_custom(compare_distances_desc)
	return city_pairs


# Modified function to identify intermediate hubs based on city distances and ensure minimum distance from cities
func get_city_hubs(city_positions: Array, city_pairs: Array) -> Array:
	var hubs = []
	var max_hubs = min(city_positions.size() / 2, 5)  # Set a limit on the number of hubs

	# Generate hubs at midpoints of the farthest city pairs
	for pair in city_pairs:
		if hubs.size() >= max_hubs:
			break  # Stop if we've reached the maximum number of hubs
		var city_a = pair["cities"][0]
		var city_b = pair["cities"][1]
		var distance = pair["distance"]

		# Only create a hub if the distance is greater than 40
		if distance <= 40:
			continue

		# Calculate a midpoint with slight random adjustment to make it feel more organic
		var midpoint = (city_a + city_b) / 2
		midpoint += Vector2(randf_range(-2, 2), randf_range(-2, 2))  # Random offset

		# Round midpoint to convert it to a Vector2i
		var midpoint_int = Vector2i(int(midpoint.x), int(midpoint.y))

		# Ensure the midpoint is at least 10 units away from each city
		var is_far_enough = true
		for city in city_positions:
			if midpoint_int.distance_to(city) < 20:
				is_far_enough = false
				break

		# Only add the midpoint if it’s far enough from all cities and other hubs
		if is_far_enough:
			# Check that the midpoint is also not too close to other hubs
			var is_far_from_others = true
			for existing_hub in hubs:
				if midpoint_int.distance_to(existing_hub) < 20:
					is_far_from_others = false
					break
			
			if is_far_from_others:
				hubs.append(midpoint_int)

	return hubs

# Find the nearest hub for a given city
func get_nearest_hub(city_pos: Vector2, hubs: Array) -> Vector2i:
	var min_distance = INF
	var nearest_hub: Vector2
	for hub in hubs:
		var distance = city_pos.distance_to(hub)
		if distance < min_distance:
			min_distance = distance
			nearest_hub = hub
	return nearest_hub


# Function to connect cities on the border of this grid with the cities on the border of the neighboring grid
func connect_border_cities(neighbor_grid: OvermapGrid) -> void:
	var neighboring_cities = neighbor_grid.area_positions.get("city", [])
	var current_cities = area_positions.get("city", [])
	var all_road_positions: Array = []  # Master list to collect all positions from paths

	# Convert local positions to global coordinates for accurate distance calculation
	for city_a in current_cities:
		var city_a_global = local_to_global(city_a)
		
		for city_b in neighboring_cities:
			var city_b_global = neighbor_grid.local_to_global(city_b)
			var distance = city_a_global.distance_to(city_b_global)

			# If cities are within a certain threshold, connect them with a road path
			if distance < 40:
				var path: Array = generate_winding_path(city_a_global, city_b_global)
				
				# Collect all positions in the generated path
				all_road_positions.append_array(path)
				
				# Update path on each grid to assign road maps
				update_path_on_grid(path)
				neighbor_grid.update_path_on_grid(path)

	# Once all paths are processed, update road connections with collected positions
	update_all_road_connections(all_road_positions)
	neighbor_grid.update_all_road_connections(all_road_positions)


# Function to check neighboring grids and connect border cities if needed
func check_and_connect_neighboring_grids() -> void:
	for offset: Vector2 in Gamedata.DIRECTION_OFFSETS.values():
		var neighbor_grid: OvermapGrid = Helper.overmap_manager.get_grid_from_meta_pos(pos + offset)
		if neighbor_grid:
			connect_border_cities(neighbor_grid)


# Returns the map_cell from the provided position. The position can be any Vector2 with two ints in it
# Coordinates between 0,0 and 99,99 will only return the cell if this grid's pos is at 0,0.
# Coordinates between 100,0 and 199,99 will only return the cell if this grid's pos is at 1,0.
# Coordinates between -100,-100 and -1,-1 will only return the cell if this grid's pos is at -1,-1.
func get_cell_from_global_pos(global_pos: Vector2):
	if cells.has(global_pos):
		return cells[global_pos]
	return null
