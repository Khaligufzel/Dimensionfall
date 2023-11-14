extends Control


signal tile_clicked(clicked_tile: Control)


func _on_texture_rect_gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		tile_clicked.emit(self)

func set_texture(res: Resource):
	$TextureRect.texture = res


#func _on_texture_rect_mouse_entered(event):
#	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
#
#
func _on_texture_rect_mouse_entered():
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
#		emit_signal("tile_clicked")
		tile_clicked.emit(self)
