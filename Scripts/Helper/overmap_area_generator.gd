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
	var neighbor_keys: Dictionary = {}  # e.g., {"urban": 100, "suburban": 50}
	var connections: Dictionary = {}  # e.g., {"north": "road", "south": "ground", ...}
	var rotation: int
	var weight: float  # Base weight for selection
	var dmap: DMap  # Base weight for selection

	func rotated_connections(rotation: int) -> Dictionary:
		# Returns connections adjusted for the given rotation
		# Implement rotation logic here
		return {}


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
				mytile.id = map.id + "_" + str(key) + "_" + str(myrotation)
				tile_catalog.append(mytile)
