extends Control

const defaultTileData: Dictionary = {"texture": "", "rotation": 0}
const defaultTexture: String = "res://Scenes/ContentManager/Mapeditor/Images/emptyTile.png"
var tileData: Dictionary = defaultTileData.duplicate():
	set(data):
		tileData = data
		if tileData.texture != "":
			$TextureRect.texture = load("res://Mods/Core/Tiles/" + tileData.texture)
		else:
			$TextureRect.texture = load(defaultTexture)
signal tile_clicked(clicked_tile: Control)


func _on_texture_rect_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if event.pressed:
					tile_clicked.emit(self)

func set_texture(res: Resource) -> void:
	$TextureRect.texture = res
	var path: String = res.resource_path
	tileData.texture = path.replace("res://Mods/Core/Tiles/","")

func _on_texture_rect_mouse_entered() -> void:
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		tile_clicked.emit(self)

func set_default() -> void:
	tileData = defaultTileData.duplicate()

func highlight() -> void:
	$TextureRect.modulate = Color(0.227, 0.635, 0.757)
	
func unhighlight() -> void:
	$TextureRect.modulate = Color(1,1,1)
