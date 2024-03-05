extends Control


@export var tileGrid: GridContainer = null
@export var mapwidthTextEdit: TextEdit = null
@export var mapheightTextEdit: TextEdit = null

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

func _on_map_height_text_changed() -> void:
	mapHeight = int(mapheightTextEdit.text)
	tileGrid.resetGrid()

func _on_map_width_text_changed() -> void:
	mapWidth = int(mapwidthTextEdit.text)
	tileGrid.resetGrid()

#The editor is closed, destroy the instance
#TODO: Check for unsaved changes
func _on_close_button_button_up() -> void:
	queue_free()


# Handler for the signal
func _on_map_dimensions_changed(new_map_width: int, new_map_height: int) -> void:
	mapwidthTextEdit.text = str(new_map_width)
	mapheightTextEdit.text = str(new_map_height)
