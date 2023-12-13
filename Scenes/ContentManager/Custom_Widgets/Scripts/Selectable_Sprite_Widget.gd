extends Control

signal selectableSprite_clicked(clicked_sprite: Control)
var selected: bool = false

#When the event was a left mouse button press, adjust emit a signal that it was clicked
func _on_texture_rect_gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		selectableSprite_clicked.emit(self)
	
func set_sprite_texture(res: Resource) -> void:
	if res is BaseMaterial3D:
		$SpriteImage.texture = res.albedo_texture
	else:
		$SpriteImage.texture = res
	
func get_texture() -> Resource:
	return $SpriteImage.texture
	
#Mark the clicked spritebrush as selected
func set_selected(is_selected: bool) -> void:
	selected = is_selected
	if selected:
		modulate = Color(0.227, 0.635, 0.757)
	else:
		modulate = Color(1,1,1)
	
