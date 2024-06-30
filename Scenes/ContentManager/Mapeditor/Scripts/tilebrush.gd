extends Control

# This script is intended to be used with TileBrush.tscn.
# It holds information about a tile brush that is used in the mapeditor


signal tilebrush_clicked(clicked_tile: Control)
var entityID: String = ""
var selected: bool = false
# Can be "tile", "mob", "furniture", "itemgroup"
var entityType: String = "tile"
const TILEMARGIN: int = 10

#When the event was a left mouse button press, adjust the modulate property of the $TileSprite to be 3aa2c1
func _on_texture_rect_gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		tilebrush_clicked.emit(self)


func set_tile_texture(res: Resource) -> void:
	$TileSprite.texture = res


func get_texture() -> Resource:
	return $TileSprite.texture


#Mark the clicked tilebrush as selected
func set_selected(is_selected: bool) -> void:
	selected = is_selected
	if selected:
		modulate = Color(0.227, 0.635, 0.757)
	else:
		modulate = Color(1,1,1)


func set_minimum_size(newsize: Vector2):
	custom_minimum_size = Vector2(newsize.x+TILEMARGIN, newsize.y+TILEMARGIN)
	$TileSprite.custom_minimum_size = newsize
