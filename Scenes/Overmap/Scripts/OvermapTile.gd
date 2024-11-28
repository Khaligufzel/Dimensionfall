extends Control

# Define the default texture to show when no map_cell is revealed
# Preload the default texture to avoid loading it repeatedly
var defaultTexture = preload("res://Scenes/ContentManager/Mapeditor/Images/emptyTile.png")

# Declare the map_cell variable, replacing tileData
# the map_cell is of the map_cell class defined in Helper.overmap_manager
var map_cell:
	set(cell):
		map_cell = cell
		if map_cell and map_cell.is_revealed():
			set_texture(map_cell.get_sprite())  # Set the texture if revealed
			set_texture_rotation(map_cell.rotation, Vector2(16, 16))  # Apply the rotation
		else:
			set_texture(null)  # Clear the texture if not revealed


signal tile_clicked(clicked_tile: Control)

# Handle mouse input to emit the tile_clicked signal
func _on_texture_rect_mouse_entered():
	tile_clicked.emit(self)

func _on_texture_rect_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if event.pressed:
					pass

# Set the texture for the TextureRect
func set_texture(res: Resource) -> void:
	if res:
		$TextureRect.texture = res
	else:
		$TextureRect.texture = defaultTexture  # Set to default texture if none provided

# Highlight the tile
func highlight() -> void:
	$TextureRect.modulate = Color(0.227, 0.635, 0.757)

# Unhighlight the tile
func unhighlight() -> void:
	$TextureRect.modulate = Color(1, 1, 1)

# Set the color of the TextureRect
func set_color(myColor: Color) -> void:
	$TextureRect.modulate = myColor

# Set the tile to be clickable or not
func set_clickable(clickable: bool):
	if not clickable:
		mouse_filter = MOUSE_FILTER_IGNORE
		$TextureRect.mouse_filter = MOUSE_FILTER_IGNORE

# Show or hide the text on the tile
func set_text_visible(isvisible: bool):
	$TextLabel.visible = isvisible

# Set the text on the tile
func set_text(newtext: String):
	$TextLabel.text = newtext
	if newtext == "":
		$TextLabel.visible = false
		return
	$TextLabel.text = newtext
	$TextLabel.visible = true

# Set the rotation of the TextureRect based on the given rotation angle
func set_texture_rotation(myrotation: int, pivotoffset: Vector2 = Vector2.ZERO) -> void:
	var newpivot: Vector2 = size / 2
	if not pivotoffset == Vector2.ZERO: # HACK: Manual pivot offset since the size / 2 fails for some reason
		newpivot = pivotoffset
	$TextureRect.pivot_offset = newpivot  # Set the pivot to the center of the TextureRect
	match myrotation:
		0:
			$TextureRect.rotation_degrees = 0
		90:
			$TextureRect.rotation_degrees = 90
		180:
			$TextureRect.rotation_degrees = 180
		270:
			$TextureRect.rotation_degrees = 270
		_:
			$TextureRect.rotation_degrees = 0  # Default to 0 if an invalid rotation is provided
