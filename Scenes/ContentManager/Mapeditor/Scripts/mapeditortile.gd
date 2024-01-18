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
			$TileSprite.texture = Gamedata.get_sprite_by_id(Gamedata.data.tiles,\
			tileData.id).albedo_texture
			if tileData.has("rotation"):
				set_rotation_amount(tileData.rotation)
			$MobFurnitureSprite.hide()
			$MobFurnitureSprite.rotation_degrees = 0
			if tileData.has("mob"):
				if tileData.mob.has("rotation"):
					$MobFurnitureSprite.rotation_degrees = tileData.mob.rotation
				$MobFurnitureSprite.texture = Gamedata.get_sprite_by_id(Gamedata.data.mobs,\
				tileData.mob.id)
				$MobFurnitureSprite.show()
			elif tileData.has("furniture"):
				if tileData.furniture.has("rotation"):
					$MobFurnitureSprite.rotation_degrees = tileData.furniture.rotation
				$MobFurnitureSprite.texture = Gamedata.get_sprite_by_id(\
				Gamedata.data.furniture, tileData.furniture.id)
				$MobFurnitureSprite.show()
		else:
			$TileSprite.texture = load(defaultTexture)
			$MobFurnitureSprite.texture = null
			$MobFurnitureSprite.hide()
signal tile_clicked(clicked_tile: Control)

func _on_texture_rect_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if event.pressed:
					tile_clicked.emit(self)

func set_rotation_amount(amount: int) -> void:
	$TileSprite.rotation_degrees = amount
	if amount == 0:
		tileData.erase("rotation")
	else:
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
		if !tileData.has("furniture"):
			$MobFurnitureSprite.hide()
	else:
		# A tile can either have a mob or furniture. If we add a mob, remove furniture
		tileData.erase("furniture")
		if tileData.has("mob"):
			tileData.mob.id = id
		else:
			tileData.mob = {"id": id}
		$MobFurnitureSprite.texture = Gamedata.get_sprite_by_id(Gamedata.data.mobs, id)
		$MobFurnitureSprite.show()

func set_furniture_id(id: String) -> void:
	if id == "":
		tileData.erase("furniture")
		if !tileData.has("mob"):
			$MobFurnitureSprite.hide()
	else:
		# A tile can either have a mob or furniture. If we add furniture, remove the mob
		tileData.erase("mob")
		if tileData.has("furniture"):
			tileData.furniture.id = id
		else:
			tileData.furniture = {"id": id}
		$MobFurnitureSprite.texture = Gamedata.get_sprite_by_id(Gamedata.data.furniture, id)
		$MobFurnitureSprite.show()

func set_mob_rotation(rotationDegrees):
	$MobFurnitureSprite.rotation_degrees = rotationDegrees
	if rotationDegrees == 0:
		tileData.mob.erase("rotation")
	else:
		tileData.mob.rotation = rotationDegrees
		
func set_furniture_rotation(rotationDegrees):
	$MobFurnitureSprite.rotation_degrees = rotationDegrees
	if rotationDegrees == 0:
		tileData.furniture.erase("rotation")
	else:
		tileData.furniture.rotation = rotationDegrees

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
		$MobFurnitureSprite.mouse_filter = MOUSE_FILTER_IGNORE

#This function sets the texture to some static resource that helps the user visualize that something is above
#If this tile has a texture in its data, set it to the above texture instead
func set_above():
	$MobFurnitureSprite.texture = null
	$MobFurnitureSprite.hide()
	if tileData.has("id") and tileData.id != "":
		$TileSprite.texture = load(aboveTexture)
	else:
		$TileSprite.texture = null

func _on_texture_rect_resized():
	$TileSprite.pivot_offset = size / 2
	$MobFurnitureSprite.pivot_offset = size / 2

func get_tile_texture():
	return $TileSprite.texture
