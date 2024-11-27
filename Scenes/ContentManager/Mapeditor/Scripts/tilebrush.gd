extends Control

# This script is intended to be used with TileBrush.tscn.
# It holds information about a tile brush that is used in the mapeditor


signal tilebrush_clicked(clicked_tile: Control)
var entityID: String = ""
var selected: bool = false
# Can be "tile", "mob", "furniture", "itemgroup", "mobgroup"
var entityType: String = "tile"
@export var tile_sprite: TextureRect
@export var label: Label = null


const TILEMARGIN: int = 10

#When the event was a left mouse button press, adjust the modulate property of the $TileSprite to be 3aa2c1
func _on_texture_rect_gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		tilebrush_clicked.emit(self)


# Set the texture of the tile sprite
func set_tile_texture(res: Resource) -> void:
	tile_sprite.texture = res


# Get the texture of the tile sprite
func get_texture() -> Resource:
	return tile_sprite.texture


# Mark the clicked tilebrush as selected
func set_selected(is_selected: bool) -> void:
	selected = is_selected
	modulate = Color(0.227, 0.635, 0.757) if selected else Color(1, 1, 1)


# Set the minimum size of the tile brush with additional margin
func set_minimum_size(newsize: Vector2) -> void:
	custom_minimum_size = Vector2(newsize.x + TILEMARGIN, newsize.y + TILEMARGIN)
	tile_sprite.custom_minimum_size = newsize


func show_label():
	label.show()
	
func hide_label():
	label.hide()
