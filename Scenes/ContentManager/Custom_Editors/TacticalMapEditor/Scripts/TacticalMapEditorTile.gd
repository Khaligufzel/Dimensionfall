extends Control

#If a tile has no data, we save an empty object. Tiledata can have:
# id, rotation, mob
const defaultTileData: Dictionary = {}
const defaultTexture: String = "res://Scenes/ContentManager/Mapeditor/Images/emptyTile.png"
const aboveTexture: String = "res://Scenes/ContentManager/Mapeditor/Images/tileAbove.png"
var tileData: Dictionary = defaultTileData.duplicate():
	set(data):
		tileData = data
		if tileData.has("id") and tileData.id != "":
			$TileSprite.texture = Gamedata.get_sprite_by_id(Gamedata.data.maps,\
			tileData.id)
			if tileData.has("rotation"):
				set_rotation_amount(tileData.rotation)
		else:
			$TileSprite.texture = load(defaultTexture)
signal tile_clicked(clicked_tile: Control)

func _on_texture_rect_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if event.pressed:
					tile_clicked.emit(self)

func set_rotation_amount(amount: int) -> void:
	$TileSprite.rotation_degrees = amount
	tileData.rotation = amount
	
func get_rotation_amount() -> int:
	return $TileSprite.rotation_degrees

func set_tile_id(id: String) -> void:
	if id == "":
		tileData.erase("id")
		$TileSprite.texture = load(defaultTexture)
	else:
		tileData.id = id
		$TileSprite.texture = Gamedata.get_sprite_by_id(Gamedata.data.tiles, id).albedo_texture

func _on_texture_rect_mouse_entered() -> void:
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		tile_clicked.emit(self)

func set_default() -> void:
	tileData = defaultTileData.duplicate()

func highlight() -> void:
	$TileSprite.modulate = Color(0.227, 0.635, 0.757)

func unhighlight() -> void:
	$TileSprite.modulate = Color(1,1,1)

func set_clickable(clickable: bool):
	if !clickable:
		mouse_filter = MOUSE_FILTER_IGNORE
		$TileSprite.mouse_filter = MOUSE_FILTER_IGNORE

func get_tile_texture():
	return $TileSprite.texture
