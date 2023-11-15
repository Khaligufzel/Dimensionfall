extends Control

const defaultTileData: Dictionary = {"texture": "res://Scenes/ContentManager/Mapeditor/Images/emptyTile.png", "rotation": 0}
var tileData: Dictionary = defaultTileData.duplicate():
	set(data):
		tileData = data
		$TextureRect.texture = load(tileData.texture)
signal tile_clicked(clicked_tile: Control)


func _on_texture_rect_gui_input(event):
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if event.pressed:
					tile_clicked.emit(self)

func set_texture(res: Resource):
	$TextureRect.texture = res
	var path: String = res.resource_path
	tileData.texture = path

func _on_texture_rect_mouse_entered():
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		tile_clicked.emit(self)

func set_default():
	tileData = defaultTileData.duplicate()
