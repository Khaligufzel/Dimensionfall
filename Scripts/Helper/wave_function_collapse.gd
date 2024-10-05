extends RefCounted

# This script provides support and interface for the https://github.com/BenjaTK/Gaea/tree/main addon
# Specifically the wave function collapse
# This script will process DMaps, create the required Gaea components
# and finally return a grid of TileInfo that can be used in the overmap_manager.
# See https://github.com/Khaligufzel/Dimensionfall/issues/411 for the initial implementation idea


# Created once, holds all possible tile entries and their neighbors
var tileentrylist: Array = []

func create_collapsed_grid() -> GaeaGrid:
	var mygrid: GaeaGrid
	create_tile_entries()
	apply_neighbors()
	apply_weights()
	return mygrid


# An algorithm that loops over all Gamedata.maps and creates a OMWaveFunction2DEntry for: 1. each rotation of the map. 2. each neighbor key. So one map can have a maximum of 4 TileInfo variants, multiplied by the amount of neighbor keys.
func create_tile_entries() -> void:
	tileentrylist.clear()
	var maps: Dictionary = Gamedata.maps.get_all()
	for map: DMap in maps:
		for key in map.neighbor_keys.keys():
			var rotations: Array = [0,90,180,270]
			for myrotation in rotations:
				var mytileinfo: OvermapTileInfo = OvermapTileInfo.new()
				mytileinfo.rotation = myrotation
				mytileinfo.key = key
				mytileinfo.dmap = map
				mytileinfo.id = map.id + "_" + str(key) + "_" + str(myrotation)
				var myomentry: OMWaveFunction2DEntry = OMWaveFunction2DEntry.new()
				myomentry.tile_info = mytileinfo
				tileentrylist.append(myomentry)


# In order to give every rotated variant their appropriate neighbors, we have to loop over all eligible maps and each of their rotations. Actually we might skip this process for maps that have 0 or 4 connections since they fit either everywhere or nowhere. Let's say we use urban and suburban neighbor keys, where urban will be the inner city core and suburban will be the outer area. In this case, the maps in the urban category will have connections with the urban and suburban category and the suburban category will have connections with the suburban and wilderness/plains category. This creates a one-way expansion outwards.
func apply_neighbors():
	for tile: OMWaveFunction2DEntry in tileentrylist:
		# Step 1: Get all tile entries that are even able to become neighbors in any direction
		var considered_neighbors: Array = get_neighbors_for_tile(tile)
		var mytileinfo: OvermapTileInfo = tile.tile_info

		# Step 2: Apply the neighbors for each direction, using exclude_invalid_rotations
		# North neighbors
		tile.neighbors_up = exclude_invalid_rotations(considered_neighbors, mytileinfo, "north")

		# East neighbors
		tile.neighbors_right = exclude_invalid_rotations(considered_neighbors, mytileinfo, "east")

		# South neighbors
		tile.neighbors_down = exclude_invalid_rotations(considered_neighbors, mytileinfo, "south")

		# West neighbors
		tile.neighbors_left = exclude_invalid_rotations(considered_neighbors, mytileinfo, "west")


# Returns maps that are able to become neighbors by excluding the other maps
# based on the neighbor key and connections
func get_neighbors_for_tile(tileentry: OMWaveFunction2DEntry) -> Array:
	tileentry.clear_neighbors()
	var mytileinfo: OvermapTileInfo = tileentry.tile_info
	# Step 1: only consider tile entries that match the neighbor key
	var considered_tiles: Array = get_neighbors_by_key(mytileinfo)
	# Step 2: Exclude all tiles that are unable to connect due to their connection types
	# For example, a crossroads has to match with another road and cannot match with a field
	# This does not exclue tiles that have both road and ground connections 
	# unless mytileinfo is water or something
	considered_tiles = exclude_connections_basic(considered_tiles, mytileinfo)

	# You can now return or process the remaining considered tiles
	return considered_tiles


# Returns a list of OMWaveFunction2DEntry by filtering the tileentrylist by neighbor keys
# The OMWaveFunction2DEntry's key must be included
func get_neighbors_by_key(mytileinfo: OvermapTileInfo) -> Array:
	var considered_tiles: Array = []
	for tile: OMWaveFunction2DEntry in tileentrylist:
		var tileinfo: OvermapTileInfo = tile.tile_info
		# Loop over directions north, east, south, west
		for direction: String in mytileinfo.dmap.neighbors.keys():
			if  mytileinfo.dmap.neighbors[direction].has(tileinfo.key):
				considered_tiles.append(tile)
				break # We must consider this tile when at least one direction  has the key
	return considered_tiles


# Basic check to see if the tiles in the list are able to match with this tile's connection
# The tile will be considered if any of its connection types match any of this tile's connection types.
# The direction doesn't matter.
func exclude_connections_basic(considered_tiles: Array, mytileinfo: OvermapTileInfo) -> Array:
	var newconsiderations: Array = []
	var myconnections: Dictionary = mytileinfo.dmap.connections # example: {"south": "road","west": "ground"}

	for tile: OMWaveFunction2DEntry in considered_tiles:
		var tileinfo: OvermapTileInfo = tile.tile_info
		var tileconnections: Dictionary = tileinfo.dmap.connections

		# Check if any connection type in mytileinfo matches any connection type in tileinfo
		var has_matching_connection: bool = false
		for myconnection_type in myconnections.values():
			if myconnection_type in tileconnections.values():
				has_matching_connection = true
				break # Exit loop once a match is found

		# If there is a matching connection type, add the tile to the new considerations list
		if has_matching_connection:
			newconsiderations.append(tile)

	return newconsiderations

# Exclude tiles based on their rotation and mismatched connection types for a specific direction
func exclude_invalid_rotations(considered_tiles: Array, mytileinfo: OvermapTileInfo, direction: String) -> Array:
	var myconnections = mytileinfo.dmap.connections

	# Define rotation mappings for how the directions shift depending on rotation
	var rotation_map = {
		0: {"north": "north", "east": "east", "south": "south", "west": "west"},
		90: {"north": "west", "east": "north", "south": "east", "west": "south"},
		180: {"north": "south", "east": "west", "south": "north", "west": "east"},
		270: {"north": "east", "east": "south", "south": "west", "west": "north"}
	}

	var final_considered_tiles: Array = []

	# Get the adjusted direction for the current tile (mytileinfo)
	var my_rotated_connections = rotation_map[mytileinfo.rotation]
	var my_adjusted_direction = my_rotated_connections[direction]  # Adjust only for the current direction
	var my_connection_type = myconnections[my_adjusted_direction]

	for tile: OMWaveFunction2DEntry in considered_tiles:
		var tileinfo: OvermapTileInfo = tile.tile_info
		var tileconnections = tileinfo.dmap.connections

		# Get the adjusted directions for the candidate tile (tileinfo)
		var tile_rotated_connections = rotation_map[tileinfo.rotation]

		var exclude_tile = false

		# Loop over each direction of the candidate tile to check if it can connect in the current direction
		for candidate_direction in ["north", "east", "south", "west"]:
			var tile_adjusted_direction = tile_rotated_connections[candidate_direction]
			var tile_connection_type = tileconnections[tile_adjusted_direction]

			# If the candidate's connection in any direction matches my connection in the current direction, it's valid
			if my_connection_type == tile_connection_type:
				exclude_tile = false
				break  # Valid candidate if we find any match
			else:
				exclude_tile = true  # Mark tile as excluded if no match

		# Only include the tile if a valid connection is found
		if not exclude_tile:
			final_considered_tiles.append(tile)

	return final_considered_tiles


# Apply weights to the neighbors by normalizing and adjusting based on current tile's neighbor keys
func apply_weights():
	for tile: OMWaveFunction2DEntry in tileentrylist:
		var mytileinfo: OvermapTileInfo = tile.tile_info

		# Loop through each direction's neighbors (up, right, down, left)
		tile.neighbors_up = adjust_weights_for_neighbors(tile.neighbors_up, mytileinfo)
		tile.neighbors_right = adjust_weights_for_neighbors(tile.neighbors_right, mytileinfo)
		tile.neighbors_down = adjust_weights_for_neighbors(tile.neighbors_down, mytileinfo)
		tile.neighbors_left = adjust_weights_for_neighbors(tile.neighbors_left, mytileinfo)


# Adjust weights for a given set of neighbors based on the current tile's neighbor keys
func adjust_weights_for_neighbors(neighbors: Array, mytileinfo: OvermapTileInfo) -> Array:
	var adjusted_neighbors: Array = []
	var neighbor_key_weights = mytileinfo.dmap.neighbor_keys  # Get current tile's neighbor key weights

	# Create a dictionary to store neighbors grouped by their neighbor key
	var neighbor_groups: Dictionary = {}

	# Group neighbors by their key (urban, suburban, etc.)
	for neighbor: OMWaveFunction2DEntry in neighbors:
		var key = neighbor.tile_info.key
		if not neighbor_groups.has(key):
			neighbor_groups[key] = []
		neighbor_groups[key].append(neighbor)

	# Adjust weights for each group
	for key in neighbor_groups.keys():
		var group = neighbor_groups[key]
		var total_weight = 0

		# Normalize the weights within the group
		for neighbor in group:
			total_weight += neighbor.tile_info.dmap.weight  # Sum all the original weights

		# Apply the normalized weights
		for neighbor in group:
			var normalized_weight = float(neighbor.tile_info.dmap.weight) / total_weight  # Normalize
			var adjusted_weight = normalized_weight * neighbor_key_weights.get(key, 0)  # Apply key weight

			# Duplicate the neighbor entry and assign the new weight
			var new_neighbor: OMWaveFunction2DEntry = OMWaveFunction2DEntry.new()
			new_neighbor.weight = adjusted_weight
			new_neighbor.tile_info = neighbor.tile_info
			adjusted_neighbors.append(new_neighbor)

	return adjusted_neighbors
