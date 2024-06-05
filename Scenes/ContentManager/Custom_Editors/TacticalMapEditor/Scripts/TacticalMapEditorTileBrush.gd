extends Control

signal tilebrush_clicked(clicked_tile: Control)
var mapID: String = ""
var selected: bool = false
var entityType: String = "tile"
@export var tile_sprite: TextureRect
@export var label: Label


# Update the label size based on text and ensure tile_sprite resizes accordingly
func _ready():
	label.minimum_size_changed.connect(_on_label_minimum_size_changed)
	# Ensure there is enough horizontal spacing between tile brushes
	offset_left = 10
	offset_left = 10


#When the event was a left mouse button press, adjust the modulate property of the $TileSprite to be 3aa2c1
func _on_texture_rect_gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		tilebrush_clicked.emit(self)


func set_tile_texture(res: Resource) -> void:
	tile_sprite.texture = res


func get_texture() -> Resource:
	return tile_sprite.texture


#Mark the clicked tilebrush as selected
func set_selected(is_selected: bool) -> void:
	selected = is_selected
	if selected:
		modulate = Color(0.227, 0.635, 0.757)
	else:
		modulate = Color(1,1,1)


# Update the minimum size of the parent container
func update_label_minimum_size():
	var total_height = 64 + label.custom_minimum_size.y
	custom_minimum_size = Vector2(custom_minimum_size.x, total_height)



# Set the label text and adjust the size of the label and the tile sprite accordingly
func set_label(text: String):
	label.text = text
	label.custom_minimum_size = Vector2(64, 12)  # Ensure the label has a minimum size of 64x12

	# Resize the label to fit its text within 64 pixels width by wrapping text and/or reducing font size
	#var font_size = label.font_size
	var font_size = label.get_theme_font_size("font_size")
	while label.get_minimum_size().x > 64 and font_size > 1:
		font_size -= 1
		label.add_theme_font_override("font", FontFile.new())
		label.add_theme_font_size_override("font", font_size)

	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # Enable word wrapping
	label.size_flags_horizontal = Control.SIZE_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_END
	label.custom_minimum_size = Vector2(64, label.get_minimum_size().y)  # Ensure the height remains

	# Adjust the size of the tile sprite to fit the label if needed
	var label_width = label.get_minimum_size().x
	if label_width > 64:
		tile_sprite.custom_minimum_size = Vector2(label_width, 64)
	else:
		tile_sprite.custom_minimum_size = Vector2(64, 64)

	# Update the minimum size of the parent container
	update_minimum_size()


func _on_label_minimum_size_changed():
	# Adjust the tile_sprite size based on the label's new size
	var label_width = label.custom_minimum_size.x
	if label_width > 64:
		tile_sprite.custom_minimum_size = Vector2(label_width, 64)
	else:
		tile_sprite.custom_minimum_size = Vector2(64, 64)

	# Update the minimum size of the parent container
	update_min_size()


# Update the minimum size of the parent container
func update_min_size():
	var total_height = 64 + label.custom_minimum_size.y
	custom_minimum_size = Vector2(custom_minimum_size.x, total_height)
