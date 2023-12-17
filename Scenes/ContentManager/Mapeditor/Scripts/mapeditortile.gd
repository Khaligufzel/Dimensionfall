extends Control

const defaultTileData: Dictionary = {"id": "", "rotation": 0}
const defaultTexture: String = "res://Scenes/ContentManager/Mapeditor/Images/emptyTile.png"
const aboveTexture: String = "res://Scenes/ContentManager/Mapeditor/Images/tileAbove.png"
var tileData: Dictionary = defaultTileData.duplicate():
	set(data):
		tileData = data
		if tileData.id != "":
			# tileData has an id. Now we want to load the json that has that tileid
			var tileGameData = Gamedata.data.tiles
			# The index in the tiles json data
			var myTileIndex: int = Gamedata.get_array_index_by_id(tileGameData,tileData.id)
			if myTileIndex != -1:
				# We found the tile json with the specified id, so get that json by using the index
				var myTileData: Dictionary = tileGameData.data[myTileIndex]
				$TextureRect.texture = Gamedata.data.tiles.sprites[myTileData.sprite].albedo_texture
			else:
				$TextureRect.texture = load(defaultTexture)
		else:
			$TextureRect.texture = load(defaultTexture)
signal tile_clicked(clicked_tile: Control)

func _on_texture_rect_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if event.pressed:
					tile_clicked.emit(self)

func set_rotation_amount(amount: int) -> void:
	$TextureRect.rotation_degrees = amount
	tileData.rotation = amount
	
func get_rotation_amount() -> int:
	return $TextureRect.rotation_degrees
	
func set_scale_amount(scaleAmount: int) -> void:
	custom_minimum_size.x = scaleAmount
	custom_minimum_size.y = scaleAmount

func set_tile_id(id: String) -> void:
	tileData.id = id
	var jsonTileData: Dictionary = Gamedata.data.tiles
	var jsonTile: Dictionary = jsonTileData.data[Gamedata.get_array_index_by_id(jsonTileData,id)]
	var tileTexture: Resource = Gamedata.data.tiles.sprites[jsonTile.sprite]
	$TextureRect.texture = tileTexture.albedo_texture

func _on_texture_rect_mouse_entered() -> void:
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		tile_clicked.emit(self)

func set_default() -> void:
	tileData = defaultTileData.duplicate()

func highlight() -> void:
	$TextureRect.modulate = Color(0.227, 0.635, 0.757)

func unhighlight() -> void:
	$TextureRect.modulate = Color(1,1,1)

func set_clickable(clickable: bool):
	if !clickable:
		mouse_filter = MOUSE_FILTER_IGNORE
		$TextureRect.mouse_filter = MOUSE_FILTER_IGNORE

#This function sets the texture to some static resource that helps the user visualize that something is above
#If this tile has a texture in its data, set it to the above texture instead
func set_above():
	if tileData.id != "":
		$TextureRect.texture = load(aboveTexture)
	else:
		$TextureRect.texture = null


func _on_texture_rect_resized():
	$TextureRect.pivot_offset = size / 2
