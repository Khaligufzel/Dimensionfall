extends Control

@onready var tileBrush: PackedScene = preload("res://Scenes/ContentManager/Mapeditor/tilebrush.tscn")
signal zoom_level_changed(value: int)
var selected_brush: Control

var zoom_level:int = 50:
	set(val):
		zoom_level = val
		zoom_level_changed.emit(zoom_level)

func _on_zoom_scroller_zoom_level_changed(value):
	zoom_level = value

func _on_tile_grid_zoom_level_changed(value):
	zoom_level = value


func _ready():
	loadTiles()


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

func _input(event):
	var drawRectangleBox: CheckBox = $HSplitContainer/MapeditorContainer/Toolbar/DrawRectangle
	var snapAmount: int = 128*zoom_level/100
	var snapLevel: Vector2 = Vector2(snapAmount, snapAmount).round()
	if drawRectangleBox.button_pressed:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT:
				if event.is_pressed():
					start_point = event.position.snapped(snapLevel)
					is_drawing = true
				else:
					end_point = event.position.snapped(snapLevel)
					is_drawing = false
					paint_in_rectangle()
	else:
		is_drawing = false
	
	#When the users presses and holds the mouse wheel, we scoll the grid
	if event is InputEventMouseMotion and is_drawing:
		end_point = event.position
		update_rectangle()

#Change the color to be red
func update_rectangle():
	var TileGrid: Control = $HSplitContainer/MapeditorContainer/HBoxContainer/MapScrollWindow/TileGrid
	if is_drawing:
		TileGrid.highlight_children_in_rect(start_point, end_point)
	else:
		TileGrid.unhighlight_children()

func paint_in_rectangle():
	var drawRectangleBox: CheckBox = $HSplitContainer/MapeditorContainer/Toolbar/DrawRectangle
	var TileGrid: Control = $HSplitContainer/MapeditorContainer/HBoxContainer/MapScrollWindow/TileGrid
	if selected_brush and drawRectangleBox.button_pressed:
		TileGrid.paint_in_rectangle(start_point, end_point, selected_brush.get_texture())
		update_rectangle()



#This function takes the TileGrid.mapData property and saves all of it as a json file. The user will get a prompt asking for a file location.
func _on_save_button_button_up():
	var TileGrid: Control = $HSplitContainer/MapeditorContainer/HBoxContainer/MapScrollWindow/TileGrid
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
	var TileGrid: Control = $HSplitContainer/MapeditorContainer/HBoxContainer/MapScrollWindow/TileGrid
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


func _on_draw_rectangle_toggled(button_pressed):
	var TileGrid: Control = $HSplitContainer/MapeditorContainer/HBoxContainer/MapScrollWindow/TileGrid
	TileGrid.is_drawing_rect = button_pressed
