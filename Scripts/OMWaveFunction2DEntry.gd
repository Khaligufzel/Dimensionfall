class_name OMWaveFunction2DEntry
extends WaveFunction2DEntry

# This script manages the OMWaveFunction2DEntry that represents one tile on the overmap
# This script provides support and interface for the https://github.com/BenjaTK/Gaea/tree/main addon
# Specifically the wave function collapse
# See https://github.com/Khaligufzel/Dimensionfall/issues/411 for the initial implementation idea


func clear_neighbors():
	neighbors_down.clear()
	neighbors_left.clear()
	neighbors_up.clear()
	neighbors_right.clear()
