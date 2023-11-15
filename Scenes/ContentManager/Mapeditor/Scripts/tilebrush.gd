extends Control

var selected: bool = false
signal tilebrush_clicked(clicked_tile: Control)

#When the event was a left mouse button press, adjust the modulate property of the $TileSprite to be 3aa2c1
func _on_texture_rect_gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var children: Array[Node] = get_parent().get_children()
		var was_selected = selected
		for child in children:
			child.deselect()
		if !was_selected:
			select()
		tilebrush_clicked.emit(self)
	
func set_tile_texture(res: Resource) -> void:
	$TileSprite.texture = res
	
func get_texture() -> Resource:
	return $TileSprite.texture
	
func select() -> void:
	$TileSprite.modulate = Color(0.227, 0.635, 0.757)
	selected = true
	
func deselect() -> void:
	$TileSprite.modulate = Color(1,1,1)
	selected = false
