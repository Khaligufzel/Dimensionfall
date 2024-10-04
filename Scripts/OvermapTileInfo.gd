class_name OvermapTileInfo
extends TileInfo

# This script manages the OvermapTileInfo that represents one tile on the overmap
# This script provides support and interface for the https://github.com/BenjaTK/Gaea/tree/main addon
# Specifically the wave function collapse
# See https://github.com/Khaligufzel/Dimensionfall/issues/411 for the initial implementation idea


var rotation: int = 0 # can by any of 0,90,180 or 270
var key: String = "" # the neighbor_key that was assigned. For example "urban"
var dmap: DMap # The DMap data object from which this TileInfo was created
