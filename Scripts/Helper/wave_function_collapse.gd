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
	return mygrid


# An algorithm that loops over all Gamedata.maps and creates a OMWaveFunction2DEntry for: 1. each rotation of the map. 2. each neighbor key. So one map can have a maximum of 4 TileInfo variants, multiplied by the amount of neighbor keys. Next, in order to give every rotated variant their appropriate neighbors, we have to loop over all eligible maps and each of their rotations. Actually we might skip this process for maps that have 0 or 4 connections since they fit either everywhere or nowhere. Let's say we use urban and suburban neighbor keys, where urban will be the inner city core and suburban will be the outer area. In this case, the maps in the urban category will have connections with the urban and suburban category and the suburban category will have connections with the suburban and wilderness/plains category. This creates a one-way expansion outwards.
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


func apply_neighbors():
	for tile: OMWaveFunction2DEntry in tileentrylist:
		var mytileinfo: OvermapTileInfo = tile.tile_info


func get_neighbors_for_tile(tileentry: OMWaveFunction2DEntry):
	tileentry.clear_neighbors()
	var mytileinfo: OvermapTileInfo = tileentry.tile_info
	# Step 1: only consider tile entries that match the neighbor key
	var considered_tiles: Array = get_neighbors_by_key(mytileinfo)


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
