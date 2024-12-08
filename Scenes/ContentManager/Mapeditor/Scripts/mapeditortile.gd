extends Control

const defaultTexture: String = "res://Scenes/ContentManager/Mapeditor/Images/emptyTile.png"
const aboveTexture: String = "res://Scenes/ContentManager/Mapeditor/Images/tileAbove.png"
const areaTexture: String = "res://Scenes/ContentManager/Mapeditor/Images/areatile.png"


signal tile_clicked(clicked_tile: Control)

# Emits tile_clicked signal when left mouse button is pressed
func _on_texture_rect_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		tile_clicked.emit(self)


# Gets the rotation amount of the tile sprite
func get_rotation_amount() -> int:
	return $TileSprite.rotation_degrees


# Sets the scale amount for the tile sprite
func set_scale_amount(scaleAmount: int) -> void:
	custom_minimum_size.x = scaleAmount
	custom_minimum_size.y = scaleAmount



# If the user holds the mouse button while entering this tile, we consider it clicked
func _on_texture_rect_mouse_entered() -> void:
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		tile_clicked.emit(self)


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


func _on_texture_rect_resized():
	$TileSprite.pivot_offset = size / 2
	$ObjectSprite.pivot_offset = size / 2
	$AreaSprite.pivot_offset = size / 2


func get_tile_texture():
	return $TileSprite.texture


# Sets the tooltip for this tile. The user can use this to see what's on this tile.
func set_tooltip(tileData: Dictionary) -> void:
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
		
	# Display mobgroup information
	if tileData.has("mobgroup"):
		tooltiptext += "Mob Group ID: " + str(tileData.mobgroup.id) + "\n"
		if tileData.mobgroup.has("rotation"):
			tooltiptext += "Mob Group Rotation: " + str(tileData.mobgroup.rotation) + " degrees\n"
		else:
			tooltiptext += "Mob Group Rotation: 0 degrees\n"
	else:
		tooltiptext += "Mob Group: None\n"
	
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
func set_area_sprite_visibility(isvisible: bool) -> void:
	$AreaSprite.visible = isvisible


# Updates the tile visuals based on the provided data
# Tiledata can have: id, rotation, mob, furniture, itemgroup, and areas
func update_display(tileData: Dictionary = {}, selected_area_name: String = "None"):
	var parent_name = get_parent().get_name()
	
	# Will be made visible again if the conditions are right
	$ObjectSprite.hide()
	$AreaSprite.hide()

	# If the parent node is "levelgrid_above", run the "set_above" logic
	if parent_name == "Level_Above":
		$ObjectSprite.texture = null
		if tileData.has("id") and tileData.id != "":
			$TileSprite.texture = load(aboveTexture)
		else:
			$TileSprite.texture = null
		return  # Exit early since we don't need to do further processing for the above layer

	# Regular update logic for other grids
	if tileData.has("id") and tileData["id"] != "" and tileData["id"] != "null":
		set_tile_id(tileData["id"])
		$TileSprite.rotation_degrees = tileData.get("rotation", 0)
		$ObjectSprite.rotation_degrees = 0
		$AreaSprite.rotation_degrees = 0

		# Check for mob and furniture, and update accordingly
		if tileData.has("mobgroup"):
			if tileData["mobgroup"].has("rotation"):
				$ObjectSprite.rotation_degrees = tileData["mobgroup"]["rotation"]
			$ObjectSprite.texture = Gamedata.mobgroups.sprite_by_id(tileData["mobgroup"]["id"])
			$ObjectSprite.show()
		if tileData.has("mob"):
			if tileData["mob"].has("rotation"):
				$ObjectSprite.rotation_degrees = tileData["mob"]["rotation"]
			$ObjectSprite.texture = Gamedata.mods.get_content_by_id(DMod.ContentType.MOBS,tileData["mob"]["id"]).sprite
			$ObjectSprite.show()
		elif tileData.has("furniture"):
			if tileData["furniture"].has("rotation"):
				$ObjectSprite.rotation_degrees = tileData["furniture"]["rotation"]
			$ObjectSprite.texture = Gamedata.furnitures.sprite_by_id(tileData["furniture"]["id"])
			$ObjectSprite.show()
		elif tileData.has("itemgroups"):
			set_tile_itemgroups(tileData)

		# Show the area sprite if conditions are met
		if tileData.has("areas") and selected_area_name != "None":
			for area in tileData["areas"]:
				if area["id"] == selected_area_name:
					$AreaSprite.show()
					break  # Exit the loop once the area is found
	else:
		$TileSprite.texture = load(defaultTexture)
		$ObjectSprite.texture = null

	set_tooltip(tileData)



# Update the sprite by id
func set_tile_id(id: String) -> void:
	if id == "null":
		return
	if id == "":
		$TileSprite.texture = load(defaultTexture)
	else:
		$TileSprite.texture = Gamedata.mods.by_id("Core").tiles.sprite_by_id(id)


# Manages the itemgroups property for the tile. 
# If the tile has no mob or furniture, it applies itemgroups to the tile and assigns a random sprite to the ObjectSprite.
# If the itemgroups array is empty, it hides the ObjectSprite and removes the itemgroups property from the tile.
# If the tileData contains a mob or furniture, the function returns early without making any changes.
func set_tile_itemgroups(tileData: Dictionary) -> void:
	if tileData.has("mob") or tileData.has("furniture") or tileData.has("mobgroup"):
		return
	
	var itemgroups: Array = tileData.get("itemgroups", [])
	if itemgroups.is_empty(): # Erase the itemgroups property if the itemgroups array is empty
		$ObjectSprite.hide()
	else:
		# Apply the itemgroup to the tile and update ObjectSprite with a random sprite
		var random_itemgroup: String = itemgroups.pick_random()
		$ObjectSprite.texture = Gamedata.itemgroups.sprite_by_id(random_itemgroup)
		$ObjectSprite.show()
		$ObjectSprite.rotation_degrees = 0
