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
		tileGrid.load_map_json_file()


func _on_map_height_text_changed():
	mapHeight = int(mapheightTextEdit.text)

func _on_map_width_text_changed():
	mapWidth = int(mapwidthTextEdit.text)

