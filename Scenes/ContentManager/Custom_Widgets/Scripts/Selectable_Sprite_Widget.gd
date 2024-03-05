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
			
#func _on_texture_rect_gui_input(event):
	#if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		#selectableSprite_clicked.emit(self)
	
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
	
