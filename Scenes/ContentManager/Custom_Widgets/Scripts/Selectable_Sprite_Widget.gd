extends Control


# This script is intended to be used in the Selectable_Sprite_Widget widget.
# The goal is to show the user a sprite that can be clicked on
# This may be used in lists or flow containers, like the Sprite_Selector_Popup

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
		# Set the minimum size to the texture size, but ensure it's at least 64x64
		var texture_size = texture.get_size()
		custom_minimum_size = Vector2(max(texture_size.x, 64), max(texture_size.y, 64))

		# Set the tooltip with the name or path of the texture
		if texture.resource_path and texture.resource_path != "":
			tooltip_text = texture.resource_path
		else:
			tooltip_text = "Texture"

	else:
		$SpriteImage.texture = null
		# Reset to minimum size with a minimum height of 64
		custom_minimum_size = Vector2(0, 64)
		tooltip_text = ""  # Clear the tooltip


func get_texture() -> Resource:
	return $SpriteImage.texture

#Mark the clicked spritebrush as selected
func set_selected(is_selected: bool) -> void:
	selected = is_selected
	if selected:
		modulate = Color(0.227, 0.635, 0.757)
	else:
		modulate = Color(1,1,1)
	
