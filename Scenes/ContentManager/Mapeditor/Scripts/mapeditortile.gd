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
			set_rotation_amount(tileData.get("rotation", 0))
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
		set_tooltip()

signal tile_clicked(clicked_tile: Control)

# Emits tile_clicked signal when left mouse button is pressed
func _on_texture_rect_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		tile_clicked.emit(self)


# Sets the rotation amount for the tile sprite and updates tile data
func set_rotation_amount(amount: int) -> void:
	$TileSprite.rotation_degrees = amount
	if amount == 0:
		tileData.erase("rotation")
	else:
		tileData.rotation = amount
	set_tooltip()


# Gets the rotation amount of the tile sprite
func get_rotation_amount() -> int:
	return $TileSprite.rotation_degrees


# Sets the scale amount for the tile sprite
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
	set_tooltip()


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
	set_tooltip()


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
	set_tooltip()


# Sets the rotation for the mob sprite
func set_mob_rotation(rotationDegrees: int) -> void:
	set_entity_rotation("mob", rotationDegrees)


# Sets the rotation for the furniture sprite
func set_furniture_rotation(rotationDegrees: int) -> void:
	set_entity_rotation("furniture", rotationDegrees)


# Helper function to set entity rotation
func set_entity_rotation(key: String, rotationDegrees: int) -> void:
	$MobFurnitureSprite.rotation_degrees = rotationDegrees
	if rotationDegrees == 0:
		tileData[key].erase("rotation")
	else:
		tileData[key].rotation = rotationDegrees
	set_tooltip()


# Sets the itemgroups property for the furniture on this tile
# If the "container" property exists in the "Function" property of the furniture data, 
# it sets the tileData.furniture.itemgroups property.
# If the "container" property or the "Function" property does not exist, it erases the "itemgroups" property.
func set_furniture_itemgroups(itemgroups: Array) -> void:
	if not tileData.has("furniture"):
		return
	
	var furnituredata = Gamedata.get_data_by_id(Gamedata.data.furniture, tileData.furniture.id)
	var containervalue = Helper.json_helper.get_nested_data(furnituredata, "Function.container")
	
	if not itemgroups.is_empty() and containervalue:
		tileData.furniture.itemgroups = itemgroups
	else:
		tileData.furniture.erase("itemgroups")
	set_tooltip()


# If the user holds the mouse button while entering this tile, we consider it clicked
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


func set_tooltip():
	var tooltiptext = "Tile Overview:\n"
	
	if tileData.has("id") and tileData.id != "":
		tooltiptext += "ID: " + str(tileData.id) + "\n"
	else:
		tooltiptext += "ID: None\n"
	
	if tileData.has("rotation"):
		tooltiptext += "Rotation: " + str(tileData.rotation) + " degrees\n"
	else:
		tooltiptext += "Rotation: 0 degrees\n"
	
	if tileData.has("mob"):
		tooltiptext += "Mob ID: " + str(tileData.mob.id) + "\n"
		if tileData.mob.has("rotation"):
			tooltiptext += "Mob Rotation: " + str(tileData.mob.rotation) + " degrees\n"
		else:
			tooltiptext += "Mob Rotation: 0 degrees\n"
	else:
		tooltiptext += "Mob: None\n"
	
	if tileData.has("furniture"):
		tooltiptext += "Furniture ID: " + str(tileData.furniture.id) + "\n"
		if tileData.furniture.has("rotation"):
			tooltiptext += "Furniture Rotation: " + str(tileData.furniture.rotation) + " degrees\n"
		else:
			tooltiptext += "Furniture Rotation: 0 degrees\n"
		if tileData.furniture.has("itemgroups"):
			tooltiptext += "Furniture Item Groups: " + str(tileData.furniture.itemgroups) + "\n"
	else:
		tooltiptext += "Furniture: None\n"
	
	# Set the tooltip
	self.tooltip_text = tooltiptext

