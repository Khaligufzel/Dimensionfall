extends GridContainer

# This script is used in the TacticalMapEditor. It manages a grid of tiles. 
# This grid represents a map of chunks. This allows the user to make a 
# larger map made up of smaller maps.

signal map_dimensions_changed(new_map_width, new_map_height)
signal map_data_changed(map_path: String, new_data: Dictionary, old_data: Dictionary)  # Declare the signal

@export var tileScene: PackedScene
#Contains the data of every tile in the current level, the ground level or level 0 by default
var currentLevelData: Array = []
@export var mapEditor: Control
@export var buttonRotateRight: Button
var selected_brush: Control

var drawRectangle: bool = false
var erase: bool = false
var snapAmount: float
# Initialize new mapdata with a 3x3 empty map grid
var defaultMapData: Dictionary = {"mapwidth": 3, "mapheight": 3, "chunks": [{},{},{},{},{},{},{},{},{}]}
var rotationAmount: int = 0
#Contains map metadata like size as well as the data on all levels
var mapData: Dictionary = defaultMapData.duplicate():
	set(data):
		if data.is_empty():
			mapData = defaultMapData.duplicate()
		else:
			mapData = data.duplicate()
		loadLevel()

var olddata: Dictionary  # Used to remember the mapdata before it was changed

func _ready():
	createTiles()
	map_data_changed.connect(Gamedata.on_tacticalmapdata_changed)  # Connect the signal

# This function will fill fill this GridContainer with a grid of 3x3 instances of "res://Scenes/ContentManager/Custom_Editors/TacticalMapEditor/TacticalMapEditorTile.tscn"
func createTiles():
	columns = mapEditor.mapWidth
	for x in range(mapEditor.mapWidth):
		for y in range(mapEditor.mapHeight):
			var tileInstance: Control = tileScene.instantiate()
			add_child(tileInstance)
			tileInstance.connect("tile_clicked",grid_tile_clicked)

func resetGrid():
	# Clear the existing children
	for child in get_children():
		child.queue_free()

	# Update mapData with new dimensions
	mapData.mapwidth = mapEditor.mapWidth
	mapData.mapheight = mapEditor.mapHeight
	var newMapsArray = []
	for x in range(mapEditor.mapWidth):
		for y in range(mapEditor.mapHeight):
			newMapsArray.append({})  # Add an empty dictionary for each tile

	mapData.chunks = newMapsArray

	# Recreate tiles
	createTiles()

	# Emit map_data_changed signal
	map_data_changed.emit(mapEditor.contentSource, mapData, olddata)

# When one of the grid tiles is clicked, we paint the tile accordingly
func grid_tile_clicked(clicked_tile):
	paint_single_tile(clicked_tile)

# We paint a single tile if draw rectangle is not selected
# Either erase the tile or paint it if a brush is selected.
func paint_single_tile(clicked_tile):
	if drawRectangle or !clicked_tile:
		return
	if erase:
		if selected_brush:
			clicked_tile.set_tile_id("")
			clicked_tile.set_rotation_amount(0)
		else:
			clicked_tile.set_default()
	elif selected_brush:
		clicked_tile.set_tile_id(selected_brush.mapID)
		clicked_tile.set_rotation_amount(rotationAmount)

# This function takes the mapData property and saves all of it as a json file.
func save_map_json_file():
	# Convert the TileGrid.mapData to a JSON string
	storeLevelData()
	map_data_changed.emit(mapEditor.contentSource, mapData, olddata)  # Emit the signal before saving
	var map_data_json = JSON.stringify(mapData.duplicate(), "\t")
	Helper.json_helper.write_json_file(mapEditor.contentSource, map_data_json)
	olddata = mapData.duplicate(true)

# When this function is called, loop over all the TileGrid's children and get the tileData property. Store this data in the currentLevelData array
func storeLevelData():
	currentLevelData.clear()
	for child in get_children():
		currentLevelData.append(child.tileData)
	mapData.chunks = currentLevelData.duplicate()

func load_tacticalmap_json_file():
	var fileToLoad: String = mapEditor.contentSource
	mapData = Helper.json_helper.load_json_dictionary_file(fileToLoad)
	olddata = mapData.duplicate(true)
	# Notify about the change in map dimensions
	map_dimensions_changed.emit(mapData.mapwidth, mapData.mapheight)

func loadLevel():
	if mapData.is_empty():
		print_debug("Tried to load data from an empty mapData dictionary")
		return

	# Clear existing children
	for child in get_children():
		child.queue_free()

	# Set the number of columns based on mapWidth
	columns = mapData.mapwidth

	# Recreate the grid based on mapData dimensions
	var newLevelData: Array = mapData.chunks
	var index: int = 0
	for x in range(mapData.mapwidth):
		for y in range(mapData.mapheight):
			var tileInstance: Control = tileScene.instantiate()
			add_child(tileInstance)
			tileInstance.connect("tile_clicked",grid_tile_clicked)

			# Load tile data if available, otherwise use default data
			if index < newLevelData.size():
				tileInstance.tileData = newLevelData[index]
			else:
				tileInstance.set_default()
			index += 1

func _on_entities_container_tile_brush_selection_change(tilebrush):
	selected_brush = tilebrush

# The user has pressed the rotate right button on the toolbar
# We need to set the rotation so that the brush will apply rotation to the tile
func _on_rotate_right_pressed():
	rotationAmount += 90
	rotationAmount = rotationAmount % 360  # Keep rotation within 0-359 degrees
	buttonRotateRight.text = str(rotationAmount)
