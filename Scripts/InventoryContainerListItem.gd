extends Control

signal containerlistitem_clicked(clicked_item: Control)
var containerInstance: Node3D = null
var selected: bool = false

#When the event was a left mouse button press, signal it was clicked
func _on_texture_rect_gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		containerlistitem_clicked.emit(self)

func set_item_texture(res: Resource) -> void:
	$ContainerSprite.texture = res

func get_texture() -> Resource:
	return $ContainerSprite.texture

#Mark the clicked containerlistitem as selected
func set_selected(is_selected: bool) -> void:
	selected = is_selected
	if selected:
		modulate = Color(0.227, 0.635, 0.757)
	else:
		modulate = Color(1,1,1)
