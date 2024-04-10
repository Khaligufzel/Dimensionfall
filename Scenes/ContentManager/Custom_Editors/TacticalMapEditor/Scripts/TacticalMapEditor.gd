extends Control


@export var tileGrid: GridContainer = null
@export var mapwidthTextEdit: TextEdit = null
@export var mapheightTextEdit: TextEdit = null
@export var panWindow: Control = null

var tileSize: int = 128
var mapHeight: int = 3
var mapWidth: int = 3
var contentSource: String = "":
	set(newSource):
		contentSource = newSource
		tileGrid.load_tacticalmap_json_file()
		


# In tacticalmapeditor.gd
func _ready() -> void:
	# Connect the signal from TileGrid to this script
	tileGrid.connect("map_dimensions_changed",_on_map_dimensions_changed)
	setPanWindowSize()


func _on_map_height_text_changed() -> void:
	mapHeight = int(mapheightTextEdit.text)
	tileGrid.resetGrid()
	setPanWindowSize()


func _on_map_width_text_changed() -> void:
	mapWidth = int(mapwidthTextEdit.text)
	tileGrid.resetGrid()
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


# Handler for the signal
func _on_map_dimensions_changed(new_map_width: int, new_map_height: int) -> void:
	mapwidthTextEdit.text = str(new_map_width)
	mapheightTextEdit.text = str(new_map_height)
