extends Control

#If a tile has no data, we save an empty object. Tiledata can have:
# id, rotation, mob, furniture, itemgroup and areas
const defaultTileData: Dictionary = {}
const defaultTexture: String = "res://Scenes/ContentManager/Mapeditor/Images/emptyTile.png"
const aboveTexture: String = "res://Scenes/ContentManager/Mapeditor/Images/tileAbove.png"
const areaTexture: String = "res://Scenes/ContentManager/Mapeditor/Images/areatile.png"
var tileData: Dictionary = defaultTileData.duplicate():
	set(data):
		if tileData.has("id") and tileData.id == "null":
			return
		tileData = data
		if tileData.has("id") and not tileData.id == "":
			$TileSprite.texture = Gamedata.tiles.sprite_by_id(tileData.id)
			set_rotation_amount(tileData.get("rotation", 0))
			$ObjectSprite.hide()
			$ObjectSprite.rotation_degrees = 0
			$AreaSprite.hide()
			$AreaSprite.rotation_degrees = 0
			if tileData.has("mob"):
				if tileData.mob.has("rotation"):
					$ObjectSprite.rotation_degrees = tileData.mob.rotation
				$ObjectSprite.texture = Gamedata.mobs.sprite_by_id(tileData.mob.id)
				$ObjectSprite.show()
			elif tileData.has("furniture"):
				if tileData.furniture.has("rotation"):
					$ObjectSprite.rotation_degrees = tileData.furniture.rotation
				$ObjectSprite.texture = Gamedata.furnitures.sprite_by_id(tileData.furniture.id)
				$ObjectSprite.show()
			elif tileData.has("itemgroups"):
				var random_itemgroup: String = tileData.itemgroups.pick_random()
				$ObjectSprite.texture = Gamedata.get_sprite_by_id(Gamedata.data.itemgroups, random_itemgroup)
				$ObjectSprite.show()
			if tileData.has("areas"):
				$AreaSprite.show()
		else:
			$TileSprite.texture = load(defaultTexture)
			$ObjectSprite.texture = null
			$ObjectSprite.hide()
			$AreaSprite.hide()
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
	if id == "null":
		return
	if id == "":
		tileData.erase("id")
		$TileSprite.texture = load(defaultTexture)
	else:
		tileData.id = id
		$TileSprite.texture = Gamedata.tiles.sprite_by_id(id)
	set_tooltip()


# Place a mob on this tile. We erase furniture and itemgroups since they can't exist on the same tile
func set_mob_id(id: String) -> void:
	if id == "":
		tileData.erase("mob")
		if not tileData.has("furniture") and not tileData.has("itemgroups"):
			$ObjectSprite.hide()
	else:
		# A tile can either have a mob or furniture. If we add a mob, remove furniture and itemgroups
		tileData.erase("furniture")
		tileData.erase("itemgroups")
		if tileData.has("mob"):
			tileData.mob.id = id
		else:
			tileData.mob = {"id": id}
		$ObjectSprite.texture = Gamedata.mobs.sprite_by_id(id)
		$ObjectSprite.show()
	set_tooltip()


# Place a furniture on this tile. We erase mob and itemgroups since they can't exist on the same tile
func set_furniture_id(id: String) -> void:
	if id == "":
		tileData.erase("furniture")
		if not tileData.has("mob") and not tileData.has("itemgroups"):
			$ObjectSprite.hide()
	else:
		# A tile can either have a mob or furniture. If we add furniture, remove the mob and itemgroups
		tileData.erase("mob")
		tileData.erase("itemgroups")
		if tileData.has("furniture"):
			tileData.furniture.id = id
		else:
			tileData.furniture = {"id": id}
		$ObjectSprite.texture = Gamedata.furnitures.sprite_by_id(id)
		$ObjectSprite.show()
	set_tooltip()


# Sets the rotation for the mob sprite
func set_mob_rotation(rotationDegrees: int) -> void:
	set_entity_rotation("mob", rotationDegrees)


# Sets the rotation for the furniture sprite
func set_furniture_rotation(rotationDegrees: int) -> void:
	set_entity_rotation("furniture", rotationDegrees)


# Helper function to set entity rotation
func set_entity_rotation(key: String, rotationDegrees: int) -> void:
	$ObjectSprite.rotation_degrees = rotationDegrees
	if rotationDegrees == 0:
		tileData[key].erase("rotation")
	else:
		tileData[key].rotation = rotationDegrees
	set_tooltip()


# Sets the itemgroups property for the furniture on this tile
# If the "container" property exists in the "Function" property of the furniture data, 
# it sets the tileData.furniture.itemgroups property.
# If the "container" property or the "Function" property does not exist, it erases the "itemgroups" property.
# If no furniture is present, it applies the itemgroup to the tile and updates the ObjectSprite with a random sprite.
# If the tileData has the "mob" property, it returns without making any changes.
func set_tile_itemgroups(itemgroups: Array) -> void:
	if tileData.has("mob"):
		return
	
	# If the tile doesn't have furniture
	if not tileData.has("furniture"):
		if itemgroups.is_empty(): # Erase the itemgroups property if the itemgroups array is empty
			tileData.erase("itemgroups")
			$ObjectSprite.hide()
		else:
			# Apply the itemgroup to the tile and update ObjectSprite with a random sprite
			var random_itemgroup: String = itemgroups.pick_random()
			$ObjectSprite.texture = Gamedata.get_sprite_by_id(Gamedata.data.itemgroups, random_itemgroup)
			$ObjectSprite.show()
			$ObjectSprite.rotation_degrees = 0
			tileData["itemgroups"] = itemgroups
	else:
		if itemgroups.is_empty(): # Only erase the itemgroups property from furniture
			tileData.furniture.erase("itemgroups")
		else:
			var furniture: DFurniture = Gamedata.furnitures.by_id(tileData.furniture.id)
			if not itemgroups.is_empty() and furniture.function.is_container:
				tileData.furniture.itemgroups = itemgroups
			else:
				tileData.furniture.erase("itemgroups")
	
	set_tooltip()



# If the user holds the mouse button while entering this tile, we consider it clicked
func _on_texture_rect_mouse_entered() -> void:
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		tile_clicked.emit(self)


# Resets the tiledata to the default
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
		$ObjectSprite.mouse_filter = MOUSE_FILTER_IGNORE
		$AreaSprite.mouse_filter = MOUSE_FILTER_IGNORE


#This function sets the texture to some static resource that helps the user visualize that something is above
#If this tile has a texture in its data, set it to the above texture instead
func set_above():
	$ObjectSprite.texture = null
	$ObjectSprite.hide()
	$AreaSprite.hide()
	if tileData.has("id") and tileData.id != "":
		$TileSprite.texture = load(aboveTexture)
	else:
		$TileSprite.texture = null


func _on_texture_rect_resized():
	$TileSprite.pivot_offset = size / 2
	$ObjectSprite.pivot_offset = size / 2
	$AreaSprite.pivot_offset = size / 2


func get_tile_texture():
	return $TileSprite.texture


# Adds a area dictionary to the areas list of the tile
func add_area_to_tile(area: Dictionary, tilerotation: int) -> void:
	if area.is_empty():
		return
	if not tileData.has("areas"):
		tileData.areas = []
	# Check if the area id already exists
	for existing_area in tileData.areas:
		if existing_area.id == area.id:
			return
	# Since the area definition is stored in the main mapdata, 
	# we only need to remember the id and rotation
	tileData.areas.append({"id": area.id, "rotation": tilerotation})
	$AreaSprite.show()
	set_tooltip()


# Removes a area dictionary from the areas list of the tile by its id
func remove_area_from_tile(area_id: String) -> void:
	if area_id == "":
		return
	if tileData.has("areas"):
		for area in tileData.areas:
			if area.id == area_id:
				tileData.areas.erase(area)
				$AreaSprite.hide()
				break
		if tileData.areas.is_empty():
			$AreaSprite.hide()
	set_tooltip()


# Sets the tooltip for this tile. The user can use this to see what's on this tile.
func set_tooltip() -> void:
	var tooltiptext = "Tile Overview:\n"
	
	# Display tile ID
	if tileData.has("id") and tileData.id != "":
		tooltiptext += "ID: " + str(tileData.id) + "\n"
	else:
		tooltiptext += "ID: None\n"
	
	# Display tile rotation
	if tileData.has("rotation"):
		tooltiptext += "Rotation: " + str(tileData.rotation) + " degrees\n"
	else:
		tooltiptext += "Rotation: 0 degrees\n"
	
	# Display mob information
	if tileData.has("mob"):
		tooltiptext += "Mob ID: " + str(tileData.mob.id) + "\n"
		if tileData.mob.has("rotation"):
			tooltiptext += "Mob Rotation: " + str(tileData.mob.rotation) + " degrees\n"
		else:
			tooltiptext += "Mob Rotation: 0 degrees\n"
	else:
		tooltiptext += "Mob: None\n"
	
	# Display furniture information
	if tileData.has("furniture"):
		tooltiptext += "Furniture ID: " + str(tileData.furniture.id) + "\n"
		if tileData.furniture.has("rotation"):
			tooltiptext += "Furniture Rotation: " + str(tileData.furniture.rotation) + " degrees\n"
		else:
			tooltiptext += "Furniture Rotation: 0 degrees\n"
		if tileData.furniture.has("itemgroups"):
			tooltiptext += "Furniture Item areas: " + str(tileData.furniture.itemgroups) + "\n"
	else:
		tooltiptext += "Furniture: None\n"
	
	# Display itemgroups information
	if tileData.has("itemgroups"):
		tooltiptext += "Tile Item areas: " + str(tileData.itemgroups) + "\n"
	else:
		tooltiptext += "Tile Item areas: None\n"
	
	# Display areas information
	if tileData.has("areas"):
		tooltiptext += "Tile areas: "
		for area in tileData.areas:
			tooltiptext += area.id + ", "
		tooltiptext += "\n"
	else:
		tooltiptext += "Tile areas: None\n"
	
	# Set the tooltip
	self.tooltip_text = tooltiptext


# Sets the visibility of the area sprite based on the provided area name and visibility flag
func set_area_sprite_visibility(isvisible: bool, area_name: String) -> void:
	if tileData.has("areas"):
		for area in tileData["areas"]:
			if area["id"] == area_name:
				$AreaSprite.visible = isvisible
				return
	$AreaSprite.visible = false


# Checks if a area with the specified id is in the areas list of the tile
func is_area_in_tile(area_id: String) -> bool:
	if tileData.has("areas"):
		for area in tileData.areas:
			if area.id == area_id:
				return true
	return false
