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
const NOISE_VALUE_PLAINS = -0.2

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
		var cell = Helper.overmap_manager.map_cell.new()
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
	var road_maps: Array = Gamedata.maps.get_maps_by_category("Road")
	var forest_road_maps: Array = Gamedata.maps.get_maps_by_category("Forest Road")

	if road_maps.is_empty() or forest_road_maps.is_empty():
		print("Missing road or forest road maps!")
		return

	# Step 1: Assign road maps to path cells without updating connections
	for global_position in path:
		if cells.has(global_position):
			var cell = cells[global_position] # Will be a Helper.overmap_manager.map_cell instance
			if not "Urban" in cell.dmap.categories: # Skip urban areas
				assign_road_map_to_cell(global_position, cell, road_maps, forest_road_maps)


# New function to update all road connections after all paths are placed
func update_all_road_connections(road_positions: Array) -> void:
	var road_maps: Array = Gamedata.maps.get_maps_by_category("Road")
	var forest_road_maps: Array = Gamedata.maps.get_maps_by_category("Forest Road")

	# Iterate over all known road positions and update connections
	for global_position in road_positions:
		if cells.has(global_position):
			var cell = cells[global_position] # Will be a Helper.overmap_manager.map_cell instance
			if not "Urban" in cell.dmap.categories: # Skip urban areas
				update_road_connections(global_position, cell, road_maps, forest_road_maps)


# Assign the appropriate road map (forest or regular) to a cell
# cell: A Helper.overmap_manager.map_cell instance
func assign_road_map_to_cell(global_position: Vector2, cell, road_maps: Array, forest_road_maps: Array) -> void:
	# If it's a forest cell, assign a forest road, otherwise a normal road
	var map_to_use = road_maps
	if "Forest" in cell.dmap.categories:
		map_to_use = forest_road_maps
	var selected_map = map_to_use.pick_random()
	update_cell(global_position, selected_map.id, 0)


# Update the road connections for a cell based on its type (forest or non-forest)
# cell: A Helper.overmap_manager.map_cell instance
func update_road_connections(global_position: Vector2, cell, road_maps: Array, forest_road_maps: Array) -> void:
	# Get the required connections for this cell
	var needed_connections = get_needed_connections(global_position)
	# If it's a forest cell, find a matching forest road map, otherwise a regular road map
	var map_to_use = forest_road_maps if "Forest Road" in cell.dmap.categories else road_maps
	var matching_maps = get_road_maps_with_connections(map_to_use, needed_connections)
	if matching_maps.size() > 0:
		var selected_map = matching_maps.pick_random()
		update_cell(global_position, selected_map.id, selected_map.rotation)


# Function to determine if movement from pos1 to pos2 is diagonal
func is_diagonal(pos1: Vector2, pos2: Vector2) -> bool:
	var direction = pos2 - pos1
	return abs(direction.x) == 1 and abs(direction.y) == 1

# Function to determine the required connections for a road tile
func get_needed_connections(position: Vector2) -> Array:
	var directions: Array[String] = ["north", "east", "south", "west"]
	var connections: Array[String] = []

	# Iterate over each direction (north, east, south, west)
	for direction in directions:
		var neighbor_pos: Vector2 = position + Gamedata.DIRECTION_OFFSETS[direction]

		# Check if the neighbor exists in the grid
		if self.cells.has(neighbor_pos):
			var neighbor_cell = self.cells[neighbor_pos]

			# Define the categories to check
			var categories_to_check: Array[String] = ["Road", "Urban", "Forest Road"]

			# Check if any of the categories are present in the neighbor cell's categories
			for category in categories_to_check:
				if category in neighbor_cell.dmap.categories:
					connections.append(direction)
					break  # Exit loop early since we found a match
		else:
			# If no neighbor exists, optionally handle ground connections
			pass

	return connections

# Function to get road maps that match the required connections
func get_road_maps_with_connections(road_maps: Array, required_directions: Array) -> Array[Dictionary]:
	var matching_maps: Array[Dictionary] = []

	# Iterate through each road map
	for road_map in road_maps:
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
	var valid_position = find_weighted_random_position(placed_positions, int(mapsize.x), int(mapsize.y))
	# Calculate the center offset
	var center_offset = Vector2(int(mapsize.x / 2), int(mapsize.y / 2))

	# Only if a valid position is found, place the area
	if valid_position != Vector2(-1, -1):
		for local_position in area_grid.keys():
			var adjusted_position = valid_position + local_position
			if area_grid.has(local_position):
				var tile = area_grid[local_position]
				if tile != null:
					update_cell(local_to_global(adjusted_position), tile.dmap.id, tile.rotation)
					placed_positions.append(adjusted_position)
		# Return the valid position (adjusted to the center of the placed area)
		return valid_position + center_offset

	# Return the valid position (the top-left corner of the placed area)
	return valid_position

# Function to place overmap areas on this grid
func place_overmap_area() -> void:
	var placed_positions = []  # Track positions that have already been placed
	Helper.overmap_manager.area_positions.clear()

	# Loop to place up to 10 overmap areas on the grid
	for n in range(10):
		var mygenerator = OvermapAreaGenerator.new()
		var dovermaparea = Gamedata.overmapareas.by_id(Gamedata.overmapareas.get_random_area().id)
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
				if not Helper.overmap_manager.area_positions.has(dovermaparea.id):
					Helper.overmap_manager.area_positions[dovermaparea.id] = []
				# Append the valid position to the list for this area's id
				Helper.overmap_manager.area_positions[dovermaparea.id].append(valid_position)
		else:
			print("Failed to find a valid position for the overmap area.")


# Function to place tactical maps on this grid
func place_tactical_maps() -> void:
	var placed_positions = []
	for n in range(5):  # Loop to place up to 10 tactical maps on the grid
		var dmap: DTacticalmap = Gamedata.tacticalmaps.get_random_map()

		var map_width = dmap.mapwidth
		var map_height = dmap.mapheight
		var chunks = dmap.chunks

		# Find a valid position on the grid to place the tactical map
		var position = find_weighted_random_position(placed_positions, map_width, map_height)
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
					var dchunk: DTacticalmap.TChunk = chunks[chunk_index]
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
			var cell = Helper.overmap_manager.map_cell.new()
			cell.coordinate_x = global_x
			cell.coordinate_y = global_y
			cell.region = region_type

			# Pick a map from the category based on the region type
			var maps_by_category = Gamedata.maps.get_maps_by_category(region_type_to_string(region_type))
			if maps_by_category.size() > 0:
				cell.map_id = Helper.overmap_manager.pick_random_map_by_weight(maps_by_category)
			else:
				cell.map_id = "field_grass_basic_00.json"  # Fallback if no maps found
			# If you need to test a specific map, uncomment these two lines and put in your map name.
			# It will spawn the map at position (0,0), where the player starts
			#if global_x == 0 and global_y == 0:
				#cell.map_id = "subway_station.json"

			# Add the cell to the grid's cells dictionary
			cells[cell_key] = cell

	# Place tactical maps and overmap areas on the grid, and connect cities
	place_overmap_area()

	if Helper.overmap_manager.area_positions.has("city"):
		connect_cities_by_riverlike_path(Helper.overmap_manager.area_positions["city"])

	place_tactical_maps()
	# After modifications, rebuild the map_id_to_coordinates dictionary
	build_map_id_to_coordinates()

# Helper function to convert Region enum to string
func region_type_to_string(region_type: int) -> String:
	match region_type:
		Helper.overmap_manager.Region.PLAINS:
			return "Plains"
		Helper.overmap_manager.Region.FOREST:
			return "Forest"
	return "Unknown"


# Function to find a weighted random position, favoring distant positions, and avoiding specific categories
func find_weighted_random_position(placed_positions: Array, map_width: int, map_height: int) -> Vector2:
	var max_attempts = 100  # Number of random attempts to generate a good position
	var best_position = Vector2(-1, -1)  # To store the best candidate
	var best_distance = 0  # To store the largest minimum distance found

	var categories_to_check: Array[String] = ["Road", "Urban", "Forest Road"]  # Categories to avoid

	# Loop for a number of random candidate positions
	for attempt in range(max_attempts):
		# Generate a random position on the grid
		var random_x = randi() % (grid_width - map_width + 1)
		var random_y = randi() % (grid_height - map_height + 1)
		var position = Vector2(random_x, random_y)

		# Retrieve the cell at this position from the grid
		var cell_key = local_to_global(position)
		if cells.has(cell_key):
			var cell = cells[cell_key]

			# Check if the cell belongs to any of the forbidden categories
			var unsuitable = false
			for category in categories_to_check:
				if category in cell.dmap.categories:
					unsuitable = true
					break  # If any category matches, mark the position as unsuitable

			# If the position is unsuitable, continue to the next attempt
			if unsuitable:
				continue

		# Calculate the minimum distance from this position to any already placed area
		var min_distance = INF  # Start with a very high number
		for placed_pos in placed_positions:
			# Calculate distance to the already placed position
			var dist = position.distance_to(placed_pos)
			# Keep track of the shortest distance to any other area
			if dist < min_distance:
				min_distance = dist

		# If this position has a larger minimum distance than previous ones, it's a better candidate
		if min_distance > best_distance:
			best_position = position
			best_distance = min_distance

	# Return the position with the largest minimum distance (i.e., most "spacious" position)
	return best_position


# Function to get region type based on noise value, rounded to the nearest 0.2
func get_region_type(x: int, y: int) -> int:
	var noise_value = Helper.overmap_manager.noise.get_noise_2d(float(x), float(y))

	# Compare the rounded noise value to determine the region type
	if noise_value < NOISE_VALUE_PLAINS:
		return Helper.overmap_manager.Region.PLAINS
	else:
		return Helper.overmap_manager.Region.FOREST
