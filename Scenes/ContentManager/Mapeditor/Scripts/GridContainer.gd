extends GridContainer
@onready var tileScene: PackedScene = preload("res://Scenes/ContentManager/Mapeditor/mapeditortile.tscn")
#This is the index of the level we are on. 0 is ground level. can be -10 to +10
var currentLevel: int = 10
#Contains the data of every tile in the current level, the ground level or level 0 by default
var currentLevelData: Array[Dictionary] = []
var mapEditor: Control
var LevelScrollBar: VScrollBar
var selected_brush: Control
var drawRectangle: bool = false
var erase: bool = false
var snapAmount: float
#Contains map metadata like size as well as the data on all levels
var mapData: Dictionary = {"mapwidth": 32, "mapheight": 32, "levels": [[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[]]}:
	set(data):
		mapData = data.duplicate()
		loadLevelData(currentLevel)
signal zoom_level_changed(zoom_level: int)

func _on_mapeditor_ready():
	mapEditor = $"../../../../../../.."
	LevelScrollBar = $"../../../../Levelscroller/LevelScrollbar"
	columns = mapEditor.mapWidth
	createTiles()
	snapAmount = 1.28*mapEditor.zoom_level


# This function will fill fill this GridContainer with a grid of 32x32 instances of "res://Scenes/ContentManager/Mapeditor/mapeditortile.tscn"
func createTiles():
	for x in range(mapEditor.mapWidth):
		for y in range(mapEditor.mapHeight):
			var tileInstance: Control = tileScene.instantiate()
			add_child(tileInstance)
			tileInstance.connect("tile_clicked",grid_tile_clicked)

	
var start_point = Vector2()
var end_point = Vector2()
var is_drawing = false
var mouse_button_pressed: bool = false
var snapLevel: Vector2 = Vector2(snapAmount, snapAmount).round()

#When the user presses and holds the middle mousebutton and moves the mouse, change the parent's scroll_horizontal and scroll_vertical properties appropriately
func _input(event):
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if Input.is_key_pressed(KEY_CTRL) and event.button_mask == 0:
					zoom_level_changed.emit(mapEditor.zoom_level+2)
				if Input.is_key_pressed(KEY_ALT) and event.button_mask == 0:
					LevelScrollBar.value += 1
				if Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_ALT):
					get_viewport().set_input_as_handled()
			MOUSE_BUTTON_WHEEL_DOWN: 
				if Input.is_key_pressed(KEY_CTRL) and event.button_mask == 0:
					zoom_level_changed.emit(mapEditor.zoom_level-2)
				if Input.is_key_pressed(KEY_ALT) and event.button_mask == 0:
					LevelScrollBar.value -= 1
				if Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_ALT):
					get_viewport().set_input_as_handled()
			MOUSE_BUTTON_LEFT:
				if drawRectangle:
					if event.is_pressed():
						start_point = event.global_position.snapped(snapLevel)
						is_drawing = true
					else:
						end_point = event.global_position.snapped(snapLevel)
						is_drawing = false
						paint_in_rectangle()
				else:
					is_drawing = false
	
	#When the users presses and holds the mouse wheel, we scoll the grid
	if event is InputEventMouseMotion:
		if is_drawing:
			end_point = event.global_position
			update_rectangle()

#Change the color to be red
func update_rectangle():
	if is_drawing:
		highlight_tiles_in_rect()
	else:
		unhighlight_tiles()

#When one of the grid tiles is clicked, we paint the tile accordingly
func grid_tile_clicked(clicked_tile):
	paint_single_tile(clicked_tile)
		
#We paint a single tile if draw rectangle is not selected
# Either erase the tile or paint it if a brush is selected.
func paint_single_tile(clicked_tile):
	if drawRectangle:
		return
	if erase:
		clicked_tile.set_default()
	elif selected_brush:
		clicked_tile.set_texture(selected_brush.get_texture())
	
#When this function is called, loop over all the TileGrid's children and get the tileData property. Store this data in the currentLevelData array
func storeLevelData():
	currentLevelData.clear()
	for child in get_children():
		currentLevelData.append(child.tileData)
	mapData.levels[currentLevel] = currentLevelData.duplicate()
		
#Loads the leveldata from the mapdata
#If no data exists, use the default to create a new map
func loadLevelData(newLevel: int):
	var newLevelData: Array = mapData.levels[newLevel]
	var i: int = 0
	# If any data exists on this level, we load it
	if newLevelData != []:
		for child in get_children():
			child.tileData = newLevelData[i]
			i += 1
	else:
		#No data is present on this level. apply the default value for each tile
		for child in get_children():
			child.set_default()


# We change from one level to another. For exmple from ground level (0) to 1
# Save the data we currently have in the mapData
# Then load the data from mapData if it exists for that level
# If no data exists for that level, create new level data
func change_level(newlevel: int) -> void:
	storeLevelData()
	loadLevelData(newlevel)
	currentLevel = newlevel
	storeLevelData()

# We need to add 10 since the scrollbar starts at -10
func _on_level_scrollbar_value_changed(value):
	change_level(10+0-value)
	
#This function takes two coordinates representing a rectangle. It will check which of the TileGrid's children's position falls inside this rectangle. It returns all the child tiles that fall inside this rectangle
func get_tiles_in_rectangle(rect_start: Vector2, rect_end: Vector2) -> Array:
	var tiles_in_rectangle: Array = []
	for tile in get_children():
		if tile.global_position.x >= rect_start.x-(1*mapEditor.zoom_level) and tile.global_position.x <= rect_end.x:
			if tile.global_position.y >= rect_start.y-(1*mapEditor.zoom_level) and tile.global_position.y <= rect_end.y:
				tiles_in_rectangle.append(tile)
	return tiles_in_rectangle
	
func unhighlight_tiles():
	for tile in get_children():
		tile.unhighlight()
	
func highlight_tiles_in_rect():
	unhighlight_tiles()
	var tiles: Array = get_tiles_in_rectangle(start_point, end_point)
	for tile in tiles:
		tile.highlight()
		
#Paint every tile in the selected rectangle
#We always erase if erase is selected, even if no brush is selected
#Only paint if a brush is selected and erase is false
func paint_in_rectangle():
	var tiles: Array = get_tiles_in_rectangle(start_point, end_point)
	if erase:
		for tile in tiles:
			tile.set_default()
	elif selected_brush:
		for tile in tiles:
			tile.set_texture(selected_brush.get_texture())
	update_rectangle()

#The user has pressed the erase toggle button in the editor
func _on_erase_toggled(button_pressed):
	erase = button_pressed

func _on_draw_rectangle_toggled(button_pressed):
	drawRectangle = button_pressed

func _on_tilebrush_list_tile_brush_selection_change(tilebrush):
	selected_brush = tilebrush
	
