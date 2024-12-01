extends Control


@export var tileGrid: GridContainer = null
@export var mapwidthTextEdit: SpinBox = null
@export var mapheightTextEdit: SpinBox = null
@export var panWindow: Control = null

# For controlling the focus when the tab button is pressed
var control_elements: Array = []
var tileSize: int = 128
var mapHeight: int = 3:
	set(newHeight):
		mapHeight = newHeight
		if not mapheightTextEdit.value == newHeight:
			mapheightTextEdit.value = newHeight

var mapWidth: int = 3:
	set(newWidth):
		mapWidth = newWidth
		if not mapwidthTextEdit.value == newWidth:
			mapwidthTextEdit.value = newWidth

var oldmap: DTacticalmap #Used to remember the mapdata before it was changed
var currentMap: DTacticalmap:
	set(newMap):
		currentMap = newMap
		oldmap = newMap
		mapWidth = currentMap.mapwidth
		mapHeight = currentMap.mapheight
		setPanWindowSize()  # To adjust the size after loading
		tileGrid.loadLevel()


# In tacticalmapeditor.gd
func _ready() -> void:
	# For properly using the tab key to switch elements
	control_elements = [mapwidthTextEdit,mapheightTextEdit]
	setPanWindowSize()


func setPanWindowSize():
	var minSize: int = 512  # Minimum size for either width or height
	var maxSize: int = 2048  # Maximum size to prevent it from being too big

	# Calculate base sizes from tile size and map dimensions
	var baseWidth: float = tileSize * mapWidth
	var baseHeight: float = tileSize * mapHeight

	# Apply a scaling factor that diminishes the added size per tile
	var scalingFactor: float = 0.75  # Adjust this factor based on desired growth rate
	var adjustedWidth: float = minSize + (baseWidth - minSize) * scalingFactor
	var adjustedHeight: float = minSize + (baseHeight - minSize) * scalingFactor

	# Clamp values between minimum and maximum sizes
	var finalWidth: float = clamp(adjustedWidth, minSize, maxSize)
	var finalHeight: float = clamp(adjustedHeight, minSize, maxSize)

	# Set the custom minimum size for the panWindow using the calculated dimensions
	panWindow.custom_minimum_size = Vector2(finalWidth, finalHeight)

	# Ensure the tileGrid's size respects the map dimensions ratio
	var gridWidth: float = mapWidth * tileSize
	var gridHeight: float = mapHeight * tileSize
	var aspectRatio: float = gridWidth / gridHeight

	# Calculate max dimensions for the tileGrid based on panWindow dimensions
	var maxGridWidth: float = finalWidth * 0.9
	var maxGridHeight: float = finalHeight * 0.9

	# Adjust grid size respecting aspect ratio
	if aspectRatio > 1:
		# Width is the limiting factor
		maxGridHeight = min(maxGridHeight, maxGridWidth / aspectRatio)
	else:
		# Height is the limiting factor
		maxGridWidth = min(maxGridWidth, maxGridHeight * aspectRatio)

	# Set the custom minimum size for the tileGrid
	tileGrid.custom_minimum_size = Vector2(maxGridWidth, maxGridHeight)


#The editor is closed, destroy the instance
#TODO: Check for unsaved changes
func _on_close_button_button_up() -> void:
	queue_free()


# Fix for tab key not properly switching control
func _input(event):
	if event.is_action_pressed("ui_focus_next"):
		for myControl in control_elements:
			if myControl.has_focus():
				if Input.is_key_pressed(KEY_SHIFT):  # Check if Shift key
					if !myControl.focus_previous.is_empty():
						myControl.get_node(myControl.focus_previous).grab_focus()
				else:
					if !myControl.focus_next.is_empty():
						myControl.get_node(myControl.focus_next).grab_focus()
				break
		get_viewport().set_input_as_handled()


func _on_map_width_value_changed(value):
	mapWidth = value
	currentMap.mapwidth = value
	tileGrid.resetGrid()
	setPanWindowSize()


func _on_map_height_value_changed(value):
	mapHeight = value
	currentMap.mapheight = value
	tileGrid.resetGrid()
	setPanWindowSize()
