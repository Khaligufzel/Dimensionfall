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


func generate_grid() -> Dictionary:
	area_grid.clear()
	create_tile_entries()
	for i in range(grid_width):
		for j in range(grid_height):
			var cell_key = Vector2(i, j)
			area_grid[cell_key] = tile_catalog.pick_random()
	return area_grid


# An algorithm that loops over all Gamedata.maps and creates a Tile for: 1. each rotation of the map. 2. each neighbor key. So one map can have a maximum of 4 TileInfo variants, multiplied by the amount of neighbor keys.
func create_tile_entries() -> void:
	tile_catalog.clear()
	var maps: Dictionary = Gamedata.maps.get_all()
	var rotations: Array = [0,90,180,270]
	for map: DMap in maps.values():
		for key in map.neighbor_keys.keys():
			for myrotation in rotations:
				var mytile: Tile = Tile.new()
				mytile.dmap = map
				mytile.rotation = myrotation
				mytile.key = key # May be "urban", "suburban" or something else
				mytile.id = map.id + "_" + str(key) + "_" + str(myrotation)
				tile_catalog.append(mytile)
