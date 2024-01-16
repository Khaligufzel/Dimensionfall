extends GridContainer

@export var tileScene: PackedScene
#This is the index of the level we are on. 0 is ground level. can be -10 to +10
var currentLevel: int = 10
#Contains the data of every tile in the current level, the ground level or level 0 by default
var currentLevelData: Array = []
@export var mapEditor: Control
@export var buttonRotateRight: Button
var selected_brush: Control

var drawRectangle: bool = false
var erase: bool = false
var snapAmount: float
# Initialize new mapdata with a 3x3 empty map grid
var defaultMapData: Dictionary = {"mapwidth": 3, "mapheight": 3, "maps": [{},{},{},{},{},{},{},{},{}]}
var rotationAmount: int = 0
#Contains map metadata like size as well as the data on all levels
var mapData: Dictionary = defaultMapData.duplicate():
	set(data):
		if data.is_empty():
			mapData = defaultMapData.duplicate()
		else:
			mapData = data.duplicate()
		loadLevel()

func _ready():
	createTiles()

# This function will fill fill this GridContainer with a grid of 3x3 instances of "res://Scenes/ContentManager/Custom_Editors/TacticalMapEditor/TacticalMapEditorTile.tscn"
func createTiles():
	columns = mapEditor.mapWidth
	for x in range(mapEditor.mapWidth):
		for y in range(mapEditor.mapHeight):
			var tileInstance: Control = tileScene.instantiate()
			add_child(tileInstance)
			tileInstance.connect("tile_clicked",grid_tile_clicked)

func resetGrid():
	for child in get_children():
		child.queue_free()
	createTiles()

#When one of the grid tiles is clicked, we paint the tile accordingly
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

#This function takes the mapData property and saves all of it as a json file.
func save_map_json_file():
	# Convert the TileGrid.mapData to a JSON string
	storeLevelData()
	var map_data_json = JSON.stringify(mapData.duplicate(), "\t")
	Helper.json_helper.write_json_file(mapEditor.contentSource, map_data_json)

#When this function is called, loop over all the TileGrid's children and get the tileData property. Store this data in the currentLevelData array
func storeLevelData():
	currentLevelData.clear()
	for child in get_children():
		currentLevelData.append(child.tileData)
	mapData.maps = currentLevelData.duplicate()

func load_tacticalmap_json_file():
	var fileToLoad: String = mapEditor.contentSource
	mapData = Helper.json_helper.load_json_dictionary_file(fileToLoad)
	
	
func loadLevel():
	if mapData.is_empty():
		print_debug("Tried to load data from an empty mapData dictionary")
		return;
	var newLevelData: Array = mapData.maps
	var i: int = 0
	# If any data exists on this level, we load it
	if newLevelData != []:
		for tile in get_children():
			tile.tileData = newLevelData[i]
			i += 1
	else:
		#No data is present on this level. apply the default value for each tile
		for tile in get_children():
			tile.set_default()


func _on_entities_container_tile_brush_selection_change(tilebrush):
	selected_brush = tilebrush
