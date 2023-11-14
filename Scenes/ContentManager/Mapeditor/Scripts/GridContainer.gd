extends GridContainer
@onready var tileScene: PackedScene = preload("res://Scenes/ContentManager/Mapeditor/mapeditortile.tscn")
var mapsize: int = 32
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
		child.custom_minimum_size = Vector2(zoom_level, zoom_level)
	
	
var mouse_button_pressed: bool = false
#When the user presses and holds the middle mousebutton and moves the mouse, change the parent's scroll_horizontal and scroll_vertical properties appropriately
func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				mouse_button_pressed = true
			else:
				mouse_button_pressed = false
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			if Input.is_key_pressed(KEY_CTRL):
				zoom_level_changed.emit($"../../../../..".zoom_level+1)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if Input.is_key_pressed(KEY_CTRL):
				zoom_level_changed.emit($"../../../../..".zoom_level-1)
			
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
