extends Control

#If a tile has no data, we save an empty object. Tiledata can have:
# id, rotation, mob
const defaultTileData: Dictionary = {}
const defaultTexture: String = "res://Scenes/ContentManager/Mapeditor/Images/emptyTile.png"
const aboveTexture: String = "res://Scenes/ContentManager/Mapeditor/Images/tileAbove.png"
var tileData: Dictionary = defaultTileData.duplicate():
	set(data):
		tileData = data
		if tileData.has("id"):
			$TileSprite.texture = Gamedata.get_sprite_by_id(Gamedata.data.tiles,\
			tileData.id).albedo_texture
			if tileData.has("rotation"):
				set_rotation_amount(tileData.rotation)
			if tileData.has("mob"):
				$MobSprite.texture = Gamedata.get_sprite_by_id(Gamedata.data.mobs,\
				tileData.mob)
				$MobSprite.show()
		else:
			$TileSprite.texture = load(defaultTexture)
			$MobSprite.texture = null
			$MobSprite.hide()
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
	
func set_scale_amount(scaleAmount: int) -> void:
	custom_minimum_size.x = scaleAmount
	custom_minimum_size.y = scaleAmount

func set_tile_id(id: String) -> void:
	if id == "":
		tileData.erase("id")
		$TileSprite.texture = load(defaultTexture)
	else:
		tileData.id = id
		$TileSprite.texture = Gamedata.get_sprite_by_id(Gamedata.data.tiles, id).albedo_texture

func set_mob_id(id: String) -> void:
	if id == "":
		tileData.erase("mob")
		$MobSprite.hide()
	else:
		tileData.mob = id
		$MobSprite.texture = Gamedata.get_sprite_by_id(Gamedata.data.mobs, id)
		$MobSprite.show()

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
		$MobSprite.mouse_filter = MOUSE_FILTER_IGNORE

#This function sets the texture to some static resource that helps the user visualize that something is above
#If this tile has a texture in its data, set it to the above texture instead
func set_above():
	$MobSprite.texture = null
	$MobSprite.hide()
	if tileData.id != "":
		$TileSprite.texture = load(aboveTexture)
	else:
		$TileSprite.texture = null


func _on_texture_rect_resized():
	$TileSprite.pivot_offset = size / 2
	$MobSprite.pivot_offset = size / 2
