extends GridContainer
@onready var tileScene: PackedScene = preload("res://Scenes/ContentManager/Mapeditor/mapeditortile.tscn")
var mapsize: int = 32
var tilesize: int = 128
#This is the index of the level we are on. 0 is ground level. can be -10 to +10
var currentLevel: int = 10
#Contains the data of every tile in the current level, the ground level or level 0 by default
var currentLevelData: Array[Dictionary] = []
#Contains map metadata like size as well as the data on all levels
var mapData: Dictionary = {"mapsize": mapsize, "levels": [[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[]]}:
	set(data):
		mapData = data.duplicate()
		loadLevelData(currentLevel)
var is_drawing_rect: bool = false
signal zoom_level_changed(zoom_level: int)
signal tile_clicked(clicked_tile: Control)

# Called when the node enters the scene tree for the first time.
func _ready():
	columns = mapsize
	createTiles()
	adjust_scale(50)


# This function will fill fill this GridContainer with a grid of 32x32 instances of "res://Scenes/ContentManager/Mapeditor/mapeditortile.tscn"
func createTiles():
	for x in range(mapsize):
		for y in range(mapsize):
			var tileInstance: Control = tileScene.instantiate()
			add_child(tileInstance)
			tileInstance.connect("tile_clicked",grid_tile_clicked)

	
func adjust_scale(zoom_level: int):
	for child in get_children():
		child.custom_minimum_size = Vector2(1.28*zoom_level, 1.28*zoom_level)
	
	
var mouse_button_pressed: bool = false
#When the user presses and holds the middle mousebutton and moves the mouse, change the parent's scroll_horizontal and scroll_vertical properties appropriately
func _input(event):
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if Input.is_key_pressed(KEY_CTRL) and event.button_mask == 0:
					zoom_level_changed.emit($"../../../../..".zoom_level+1)
				if Input.is_key_pressed(KEY_ALT) and event.button_mask == 0:
					$"../../Levelscroller/LevelScrollbar".value += 1
				if Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_ALT):
					get_viewport().set_input_as_handled()
			MOUSE_BUTTON_WHEEL_DOWN: 
				if Input.is_key_pressed(KEY_CTRL) and event.button_mask == 0:
					zoom_level_changed.emit($"../../../../..".zoom_level-1)
				if Input.is_key_pressed(KEY_ALT) and event.button_mask == 0:
					$"../../Levelscroller/LevelScrollbar".value -= 1
				if Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_ALT):
					get_viewport().set_input_as_handled()
			MOUSE_BUTTON_MIDDLE: 
				if event.pressed:
					mouse_button_pressed = true
				else:
					mouse_button_pressed = false
			
	#When the users presses and holds the mouse wheel, we scoll the grid
	if event is InputEventMouseMotion and mouse_button_pressed:
		var parent: ScrollContainer = get_parent()
		parent.scroll_horizontal = parent.scroll_horizontal - event.relative.x
		parent.scroll_vertical = parent.scroll_vertical - event.relative.y
		

func _on_mapeditor_zoom_level_changed(value: int) -> void:
	adjust_scale(value)

#When one of the grid tiles is clicked, we pass on the signal including the clicked tile
func grid_tile_clicked(clicked_tile):
	tile_clicked.emit(clicked_tile)
	

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
		if tile.global_position.x >= rect_start.x and tile.global_position.x <= rect_end.x:
			if tile.global_position.y >= rect_start.y-64 and tile.global_position.y <= rect_end.y:
				tiles_in_rectangle.append(tile)
	return tiles_in_rectangle
	
func unhighlight_children():
	for child in get_children():
		child.unhighlight()
	

func highlight_children_in_rect(start_point: Vector2, end_point: Vector2):
	unhighlight_children()
	var tiles: Array = get_tiles_in_rectangle(start_point, end_point)
	for tile in tiles:
		tile.highlight()
	

func paint_in_rectangle(start_point: Vector2, end_point: Vector2, res: Resource):
	var tiles: Array = get_tiles_in_rectangle(start_point, end_point)
	for tile in tiles:
		tile.set_texture(res)


	
	

