extends Control

signal zoom_level_changed(value: int)
var tileSize: int = 128
var mapHeight: int = 32
var mapWidth: int = 32

var panWindow: Control
var mapScrollWindow: ScrollContainer
var tileGrid: Control
var drawRectangleBox: CheckBox
var gridContainer: ColorRect

var zoom_level: int = 20:
	set(val):
		zoom_level = val
		adjust_scale(zoom_level)
		zoom_level_changed.emit(zoom_level)


func _ready():
	panWindow = $HSplitContainer/MapeditorContainer/HBoxContainer/MapScrollWindow/PanWindow
	mapScrollWindow = $HSplitContainer/MapeditorContainer/HBoxContainer/MapScrollWindow
	tileGrid = $HSplitContainer/MapeditorContainer/HBoxContainer/MapScrollWindow/PanWindow/GridContainer/TileGrid
	drawRectangleBox = $HSplitContainer/MapeditorContainer/Toolbar/DrawRectangle
	gridContainer = $HSplitContainer/MapeditorContainer/HBoxContainer/MapScrollWindow/PanWindow/GridContainer
	
	print_debug("editor ready")
	setPanWindowSize()
	
func setPanWindowSize():
	var panWindowWidth: float = 0.8*tileSize*mapWidth
	var panWindowHeight: float = 0.8*tileSize*mapHeight
	panWindow.custom_minimum_size = Vector2(panWindowWidth, panWindowHeight)


var mouse_button_pressed: bool = false

func _input(event):
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_MIDDLE: 
				if event.pressed:
					mouse_button_pressed = true
				else:
					mouse_button_pressed = false
	
	#When the users presses and holds the mouse wheel, we scoll the grid
	if event is InputEventMouseMotion:
		if mouse_button_pressed:
			mapScrollWindow.scroll_horizontal = mapScrollWindow.scroll_horizontal - event.relative.x
			mapScrollWindow.scroll_vertical = mapScrollWindow.scroll_vertical - event.relative.y


#This function takes the TileGrid.mapData property and saves all of it as a json file. The user will get a prompt asking for a file location.
func _on_save_button_button_up():
	var folderName: String = "./Mods/Core"
	var fileName: String = "Generichouse.json"
	var saveLoc: String = folderName + "/Maps" + "/" + fileName
	# Convert the TileGrid.mapData to a JSON string
	tileGrid.storeLevelData()
	var map_data_json = str(tileGrid.mapData.duplicate())

	var dir = DirAccess.open(folderName)
	dir.make_dir("Maps")

	# Save the JSON string to the selected file location
	var file = FileAccess.open(saveLoc, FileAccess.WRITE)
	if file:
		file.store_string(map_data_json)
	else:
		print_debug("Unable to write file " + saveLoc)

func _on_load_button_button_up():	
	var folderName: String = "./Mods/Core"
	var fileName: String = "Generichouse.json"
	var loadLoc: String = folderName + "/Maps" + "/" + fileName
	# Convert the tileGrid.mapData to a JSON string
	tileGrid.storeLevelData()

	var dir = DirAccess.open(folderName)
	dir.make_dir("Maps")

	# Save the JSON string to the selected file location
	var file = FileAccess.open(loadLoc, FileAccess.READ)
	if file:
		var map_data_json: Dictionary
		map_data_json = JSON.parse_string(file.get_as_text())
		tileGrid.mapData = map_data_json

	else:
		print_debug("Unable to load file " + loadLoc)

#Scroll to the center when the scroll window is ready
func _on_map_scroll_window_ready():
	await get_tree().create_timer(0.5).timeout
	mapScrollWindow.scroll_horizontal = int(panWindow.custom_minimum_size.x/3.5)
	mapScrollWindow.scroll_vertical = int(panWindow.custom_minimum_size.y/3.5)
	adjust_scale(20)
	
func adjust_scale(zoom: int):
	gridContainer.custom_minimum_size = Vector2(mapWidth*1.28*zoom, mapHeight*1.28*zoom)

func _on_zoom_scroller_zoom_level_changed(value):
	zoom_level = value

func _on_tile_grid_zoom_level_changed(value):
	zoom_level = value

