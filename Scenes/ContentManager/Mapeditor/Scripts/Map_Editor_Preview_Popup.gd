extends Popup

# This script works with the Map_Editor_Preview_Popup.tscn
# It allows users to preview a map after random generation is complete

# Constants and enums for better readability
const DEFAULT_MAP_WIDTH = 32
const DEFAULT_MAP_HEIGHT = 32
const DEFAULT_LEVELS_COUNT = 21

@export var generate_button: Button
@export var map_preview_grid: GridContainer
@export var tileScene: PackedScene
@export var level_spin_box: SpinBox

var defaultMapData: Dictionary = {"mapwidth": DEFAULT_MAP_WIDTH, "mapheight": DEFAULT_MAP_HEIGHT, "levels": [[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[]]}

# Contains map metadata like size as well as the data on all levels
var mapData: Dictionary = defaultMapData.duplicate():
	set(data):
		mapData = data.duplicate()
		load_level_data(int(level_spin_box.value))

# Called when the level spinbox value changes
func _on_level_spin_box_value_changed(value: int) -> void:
	load_level_data(int(value))


# Called when the generate button is pressed
func _on_generate_button_button_up() -> void:
	generate_map_preview()


# Function to load level data into the grid
func load_level_data(level: int) -> void:
	level += 10 # The levels range from -10 to +10 so we need to add 10 to pick the right level
	if mapData.is_empty():
		print_debug("Tried to load data from an empty mapData dictionary")
		return
	var newLevelData: Array = mapData.levels[level]
	var i: int = 0
	# If any data exists on this level, we load it
	if newLevelData != []:
		for tile in map_preview_grid.get_children():
			tile.tileData = newLevelData[i]  # Assuming set_tile_data method exists in tileScene
			i += 1
	else:
		# No data is present on this level. apply the default value for each tile
		for tile in map_preview_grid.get_children():
			tile.set_default()  # Assuming set_default method exists in tileScene


# Function to generate the map preview
func generate_map_preview() -> void:
	load_level_data(int(level_spin_box.value))


# Ensure signals are connected
func _ready() -> void:
	# Initialize the grid with empty tiles
	create_level_tiles(map_preview_grid, false)


# Helper function to create tiles for the grid
func create_level_tiles(grid: GridContainer, connect_signals: bool) -> void:
	for x in range(DEFAULT_MAP_WIDTH):
		for y in range(DEFAULT_MAP_HEIGHT):
			var tile_instance = tileScene.instantiate()
			grid.add_child(tile_instance)
			tile_instance.set_clickable(connect_signals)

