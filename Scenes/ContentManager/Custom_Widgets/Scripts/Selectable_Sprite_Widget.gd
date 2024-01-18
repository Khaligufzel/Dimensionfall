extends Control

signal selectableSprite_clicked(clicked_sprite: Control)
signal selectableSprite_double_clicked(clicked_sprite: Control)
var selected: bool = false

# Store the time of the last mouse click
var last_click_time = 0.0

#When the event was a left mouse button press, adjust emit a signal that it was clicked
func _on_texture_rect_gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var current_time = Time.get_ticks_msec() / 1000.0
			if current_time - last_click_time < 0.3:  # Check for double-click (300 ms threshold)
				selectableSprite_double_clicked.emit(self)
			else:
				selectableSprite_clicked.emit(self)
			last_click_time = current_time

func set_sprite_texture(res: Resource) -> void:
	var texture: Texture
	if res is BaseMaterial3D:
		texture = res.albedo_texture
	else:
		texture = res

	if texture:
		$SpriteImage.texture = texture
		# Set the minimum size of the widget based on the texture size
		var texture_size = texture.get_size()
		custom_minimum_size = Vector2(texture_size.x, texture_size.y)
	else:
		$SpriteImage.texture = null
		custom_minimum_size = Vector2(0, custom_minimum_size.y)  # Reset to no minimum width

func get_texture() -> Resource:
	return $SpriteImage.texture

#Mark the clicked spritebrush as selected
func set_selected(is_selected: bool) -> void:
	selected = is_selected
	if selected:
		modulate = Color(0.227, 0.635, 0.757)
	else:
		modulate = Color(1,1,1)
	
