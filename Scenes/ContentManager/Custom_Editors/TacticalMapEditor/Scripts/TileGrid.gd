extends GridContainer

# This script is used in the TacticalMapEditor. It manages a grid of tiles. 
# This grid represents a map of chunks. This allows the user to make a 
# larger map made up of smaller maps.

@export var tileScene: PackedScene
#Contains the data of every tile in the current level, the ground level or level 0 by default
var currentLevelData: Array[DTacticalmap.TChunk] = []
@export var mapEditor: Control
@export var buttonRotateRight: Button
var selected_brush: Control

var drawRectangle: bool = false
var erase: bool = false
var snapAmount: float
# Initialize new mapdata with a 3x3 empty map grid
var defaultMapData: Dictionary = {"mapwidth": 3, "mapheight": 3, "chunks": [{},{},{},{},{},{},{},{},{}]}
var rotationAmount: int = 0



func _ready():
	createTiles()


# This function will fill fill this GridContainer with a grid of 3x3 instances of "res://Scenes/ContentManager/Custom_Editors/TacticalMapEditor/TacticalMapEditorTile.tscn"
func createTiles():
	columns = mapEditor.mapWidth
	for x in range(mapEditor.mapWidth):
		for y in range(mapEditor.mapHeight):
			var tileInstance: Control = tileScene.instantiate()
			add_child(tileInstance)
			tileInstance.tile_clicked.connect(grid_tile_clicked)


func resetGrid():
	# Clear the existing children
	for child in get_children():
		child.queue_free()

	var newMapsArray = []
	for x in range(mapEditor.mapWidth):
		for y in range(mapEditor.mapHeight):
			newMapsArray.append({})  # Add an empty dictionary for each tile

	# Recreate tiles
	createTiles()


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
	mapEditor.currentMap.save_data_to_disk()
	mapEditor.currentMap.changed(mapEditor.oldmap)
	mapEditor.oldmap = DTacticalmap.new(mapEditor.currentMap.id,"", null)
	mapEditor.oldmap.set_data(mapEditor.currentMap.get_data().duplicate(true))


# When this function is called, loop over all the TileGrid's children and get the tileData property. Store this data in the currentLevelData array
func storeLevelData():
	currentLevelData.clear()
	for child in get_children():
		currentLevelData.append(child.tileData)
	mapEditor.currentMap.chunks = currentLevelData.duplicate()


func loadLevel():
	# Clear existing children
	for child in get_children():
		child.queue_free()

	# Set the number of columns based on mapWidth
	columns = mapEditor.currentMap.mapwidth

	# Recreate the grid based on mapData dimensions
	var newLevelData: Array = mapEditor.currentMap.chunks
	var index: int = 0
	for x in range(mapEditor.currentMap.mapwidth):
		for y in range(mapEditor.currentMap.mapheight):
			var tileInstance: Control = tileScene.instantiate()
			add_child(tileInstance)
			tileInstance.tile_clicked.connect(grid_tile_clicked)

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
