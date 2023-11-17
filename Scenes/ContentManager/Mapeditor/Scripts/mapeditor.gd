extends Control

@onready var tileBrush: PackedScene = preload("res://Scenes/ContentManager/Mapeditor/tilebrush.tscn")
signal zoom_level_changed(value: int)
var selected_brush: Control
var tileSize: int = 128
var mapsize: int = 32

var zoom_level: int = 50:
	set(val):
		zoom_level = val
		adjust_scale(zoom_level)
		zoom_level_changed.emit(zoom_level)

func _on_zoom_scroller_zoom_level_changed(value):
	zoom_level = value

func _on_tile_grid_zoom_level_changed(value):
	zoom_level = value


func _ready():
	loadTiles()
	var panWindow: ColorRect = $HSplitContainer/MapeditorContainer/HBoxContainer/MapScrollWindow/PanWindow
	var rangeofmap: float = 0.8*tileSize*mapsize
	panWindow.custom_minimum_size = Vector2(rangeofmap, rangeofmap)
	

# this function will read all files in "res://Mods/Core/Tiles/" and for each file it will create a texturerect and assign the file as the texture of the texturerect. Then it will add the texturerect as a child to $HSplitContainer/EntitiesContainer/TilesList
func loadTiles():
	var tilesDir = "res://Mods/Core/Tiles/"
	var tilesList = $HSplitContainer/EntitiesContainer/ScrollContainer/TilesList
	
	var dir = DirAccess.open(tilesDir)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			var extension = file_name.get_extension()

			if !dir.current_is_dir():
				if extension == "png":
					# Create a TextureRect node
					var brushInstance = tileBrush.instantiate()

					# Load the texture from file
					var texture: Resource = load(tilesDir + file_name)

					# Assign the texture to the TextureRect
					brushInstance.set_tile_texture(texture)
					brushInstance.tilebrush_clicked.connect(tilebrush_clicked)

					# Add the TextureRect as a child to the TilesList
					tilesList.add_child(brushInstance)
			file_name = dir.get_next()
	else:
		print_debug("An error occurred when trying to access the path.")
	dir.list_dir_end()


#Mark the clicked tilebrush as selected, but only after deselecting all other brushes
func tilebrush_clicked(tilebrush: Control) -> void:
	selected_brush = tilebrush

# The clicked tile gets the texture of the selected brush
func _on_grid_tile_clicked(clicked_tile: Node):
	var drawRectangleBox: CheckBox = $HSplitContainer/MapeditorContainer/Toolbar/DrawRectangle
	if selected_brush and not drawRectangleBox.button_pressed:
		clicked_tile.set_texture(selected_brush.get_texture())


var start_point = Vector2()
var end_point = Vector2()
var is_drawing = false
var mouse_button_pressed: bool = false

func _input(event):
	var drawRectangleBox: CheckBox = $HSplitContainer/MapeditorContainer/Toolbar/DrawRectangle
	var snapAmount: int = 1.28*zoom_level
	var snapLevel: Vector2 = Vector2(snapAmount, snapAmount).round()
	if event is InputEventMouseButton:
		if drawRectangleBox.button_pressed:
			match event.button_index:
				MOUSE_BUTTON_LEFT:
					if event.is_pressed():
						start_point = event.global_position.snapped(snapLevel)
						is_drawing = true
					else:
						end_point = event.global_position.snapped(snapLevel)
						is_drawing = false
						paint_in_rectangle()
		else:
			is_drawing = false
			
		match event.button_index:
			MOUSE_BUTTON_MIDDLE: 
				if event.pressed:
					mouse_button_pressed = true
				else:
					mouse_button_pressed = false
	
	#When the users presses and holds the mouse wheel, we scoll the grid
	if event is InputEventMouseMotion:
		print_debug("is_drawing = " + str(is_drawing))
		if mouse_button_pressed:
			var parent: ScrollContainer = $HSplitContainer/MapeditorContainer/HBoxContainer/MapScrollWindow
			parent.scroll_horizontal = parent.scroll_horizontal - event.relative.x
			parent.scroll_vertical = parent.scroll_vertical - event.relative.y
		if is_drawing:
			end_point = event.global_position
			update_rectangle()

#Change the color to be red
func update_rectangle():
	var TileGrid: Control = $HSplitContainer/MapeditorContainer/HBoxContainer/MapScrollWindow/PanWindow/GridContainer/TileGrid
	if is_drawing:
		TileGrid.highlight_children_in_rect(start_point, end_point)
	else:
		TileGrid.unhighlight_children()

func paint_in_rectangle():
	var drawRectangleBox: CheckBox = $HSplitContainer/MapeditorContainer/Toolbar/DrawRectangle
	var TileGrid: Control = $HSplitContainer/MapeditorContainer/HBoxContainer/MapScrollWindow/PanWindow/GridContainer/TileGrid
	if selected_brush and drawRectangleBox.button_pressed:
		TileGrid.paint_in_rectangle(start_point, end_point, selected_brush.get_texture())
		update_rectangle()



#This function takes the TileGrid.mapData property and saves all of it as a json file. The user will get a prompt asking for a file location.
func _on_save_button_button_up():
	var TileGrid: Control = $HSplitContainer/MapeditorContainer/HBoxContainer/MapScrollWindow/PanWindow/GridContainer/TileGrid
	var folderName: String = "./Mods/Core"
	var fileName: String = "Generichouse.json"
	var saveLoc: String = folderName + "/Maps" + "/" + fileName
	# Convert the TileGrid.mapData to a JSON string
	TileGrid.storeLevelData()
	var map_data_json = str(TileGrid.mapData.duplicate())

	var dir = DirAccess.open(folderName)
	dir.make_dir("Maps")

	# Save the JSON string to the selected file location
	var file = FileAccess.open(saveLoc, FileAccess.WRITE)
	if file:
		file.store_string(map_data_json)
	else:
		print_debug("Unable to write file " + saveLoc)


func _on_load_button_button_up():	
	var TileGrid: Control = $HSplitContainer/MapeditorContainer/HBoxContainer/MapScrollWindow/PanWindow/GridContainer/TileGrid
	var folderName: String = "./Mods/Core"
	var fileName: String = "Generichouse.json"
	var loadLoc: String = folderName + "/Maps" + "/" + fileName
	# Convert the TileGrid.mapData to a JSON string
	TileGrid.storeLevelData()

	var dir = DirAccess.open(folderName)
	dir.make_dir("Maps")

	# Save the JSON string to the selected file location
	var file = FileAccess.open(loadLoc, FileAccess.READ)
	if file:
		var map_data_json: Dictionary
		map_data_json = JSON.parse_string(file.get_as_text())
		TileGrid.mapData = map_data_json

	else:
		print_debug("Unable to load file " + loadLoc)



func _on_map_scroll_window_ready():
	await get_tree().create_timer(0.5).timeout
	var scrollwindow: ScrollContainer = $HSplitContainer/MapeditorContainer/HBoxContainer/MapScrollWindow
	scrollwindow.scroll_horizontal = tileSize*16
	scrollwindow.scroll_vertical = tileSize*16
	adjust_scale(50)
	

func adjust_scale(zoom: int):
	$HSplitContainer/MapeditorContainer/HBoxContainer/MapScrollWindow/PanWindow/GridContainer.custom_minimum_size = Vector2(mapsize*1.28*zoom, mapsize*1.28*zoom)

