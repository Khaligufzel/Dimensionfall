extends Control

signal tilebrush_clicked(clicked_tile: Control)
var mapID: String = ""
var selected: bool = false
var entityType: String = "tile"
const DEFAULT_WIDTH = 64
const LINE_HEIGHT = 20
@export var tile_sprite: TextureRect
@export var label: Label

# Update the label size based on text and ensure tile_sprite resizes accordingly
func _ready():
	label.minimum_size_changed.connect(_on_label_minimum_size_changed)


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


# Set the label text and adjust the size of the label and the tile sprite accordingly
func set_label(text: String):
	label.text = text
	label.custom_minimum_size = Vector2(DEFAULT_WIDTH, 12)

	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # Enable word wrapping
	label.size_flags_horizontal = Control.SIZE_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_END
	label.custom_minimum_size = Vector2(DEFAULT_WIDTH, label.get_minimum_size().y)

	# Update the minimum size of the parent container
	update_min_size()


func _on_label_minimum_size_changed():
	# Update the minimum size of the parent container
	update_min_size()


# Update the minimum size of the parent container
func update_min_size():
	var total_height = DEFAULT_WIDTH + label.custom_minimum_size.y
	# Because the text might wrap around to the next line, we add LINE_HEIGHT to accommodate
	# that. If the label text does not wrap around, the LINE_HEIGHT will be empty space below the text.
	custom_minimum_size = Vector2(custom_minimum_size.x, total_height+LINE_HEIGHT)
