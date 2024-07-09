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
@export var window_size_h_slider: HSlider
@export var window_size_label: Label



var defaultMapData: Dictionary = {"mapwidth": DEFAULT_MAP_WIDTH, "mapheight": DEFAULT_MAP_HEIGHT, "levels": [[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[]]}


# Contains map metadata like size as well as the data on all levels
var mapData: Dictionary = defaultMapData.duplicate():
	set(data):
		mapData = data.duplicate()
		generate_map_preview()
var generated_mapdata: Dictionary

# Ensure signals are connected
func _ready() -> void:
	# Initialize the grid with empty tiles
	create_level_tiles(map_preview_grid, false)


# Function to check if mapData has areas and return their data based on spawn chance
func get_area_data_based_on_spawn_chance() -> Array:
	var selected_areas = []
	if mapData.has("areas"):
		for area in mapData["areas"]:
			if randi() % 100 < area.get("spawn_chance", 0):
				selected_areas.append(area)
	return selected_areas


# Function to pick a tile based on its count property
func pick_tile_based_on_count(tiles: Array) -> String:
	var total_count: int = 0
	for tile in tiles:
		total_count += tile["count"]
	
	var random_pick: int = randi() % total_count
	for tile in tiles:
		if random_pick < tile["count"]:
			return tile["id"]
		random_pick -= tile["count"]
	
	return ""  # In case no tile is selected, though this should not happen if the input is valid


# Function to loop over every tile in every level and print area IDs if present
func apply_areas_to_tiles(selected_areas: Array) -> void:
	if generated_mapdata.has("levels"):
		for level in generated_mapdata["levels"]:
			for tile in level:
				if tile.has("areas"):
					apply_area_to_tile(tile, selected_areas)


# Applie an area to a tile, overwriting it's id based on a picked tile
# It will loop over all selected areas from mapdata in order, from top to bottom
# Each area will pick a new tile id for this tile, so it may be overwritten more then once
# This only happens if the tile has more then one are (i.e. overlapping areas)
# The order of areas in the tile doesn't matter, onlt the order of areas in the mapdata.
func apply_area_to_tile(tile: Dictionary, selected_areas: Array) -> void:
	# Store the areas property from the tile data into a variable
	var tile_areas = tile.get("areas", [])
	
	# Loop over every area from the selected areas
	for area in selected_areas:
		# Check if the area ID is present in the tile's areas list
		for tile_area in tile_areas:
			if area["id"] == tile_area["id"]:
				var area_data = get_area_data_by_id(area["id"])
				var tiles_data = area_data["tiles"]
				tile["id"] = pick_tile_based_on_count(tiles_data)
	
	tile.erase("areas")


# Function to get area data by ID
func get_area_data_by_id(area_id: String) -> Dictionary:
	if mapData.has("areas"):
		for area in mapData["areas"]:
			if area["id"] == area_id:
				return area
	return {}


# Called when the level spinbox value changes
func _on_level_spin_box_value_changed(value: int) -> void:
	load_level_data(int(value))


# Called when the generate button is pressed
func _on_generate_button_button_up() -> void:
	generate_map_preview()


# Function to load level data into the grid
func load_level_data(level: int) -> void:
	level += 10 # The levels range from -10 to +10 so we need to add 10 to pick the right level
	if generated_mapdata.is_empty():
		print_debug("Tried to load data from an empty generated_mapdata dictionary")
		return
	var newLevelData: Array = generated_mapdata.levels[level]
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
	generated_mapdata = mapData.duplicate()
	# Check and get area data in mapData based on spawn chance
	var selected_areas = get_area_data_based_on_spawn_chance()
	apply_areas_to_tiles(selected_areas)
	load_level_data(int(level_spin_box.value))


# Helper function to create tiles for the grid
func create_level_tiles(grid: GridContainer, connect_signals: bool) -> void:
	for x in range(DEFAULT_MAP_WIDTH):
		for y in range(DEFAULT_MAP_HEIGHT):
			var tile_instance = tileScene.instantiate()
			grid.add_child(tile_instance)
			tile_instance.set_clickable(connect_signals)


# Called when the horizontal slider value changes
func _on_h_slider_value_changed(value: float) -> void:
	window_size_label.text = "Window size: " + str(value)
	# Set the grid size based on the slider value before setting the window size
	resize_map_preview_grid(value)
	# Set the window size based on the slider value
	size = Vector2(value, value)


# Resize the map_preview_grid to fit the new size of the popup window
func resize_map_preview_grid(value: float) -> void:
	# Make sure the grid is a square with both dimensions equal to the smallest dimension
	map_preview_grid.custom_minimum_size = Vector2(value, value)
