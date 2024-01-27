extends Control


# This script is intended to be used by the CtrlInventoryStackedListItem
# It is meant to be a container for control nodes that allow the inventory
# to be represented visually
# When the mouse cursor hover over this item, it will change color
# When this item is clicked, it will change color to indicate it is selected
# When this item is clicked, it will emit a signal that it is clicked
# There will be a function that returns if this item is selected


@export var myBackgroundRect: ColorRect
@export var myLabel: Label
@export var myIcon: TextureRect

# Colors for different states
var default_color: Color = Color(0.4, 0.4, 0.4, 1) # Default color
var hover_color: Color = Color(0.8, 0.8, 0.8, 1) # Hover color
var selected_color: Color = Color(0.5, 0.5, 0.8, 1) # Selected color

var is_selected: bool = false

signal item_clicked(item)

# Called when the node enters the scene tree for the first time.
func _ready():
	myBackgroundRect.color = default_color
	set_process_unhandled_input(true)
	connect("mouse_entered", _on_mouse_entered)
	connect("mouse_exited", _on_mouse_exited)

func _unhandled_input(event):
	if event is InputEventMouse:
		if get_global_rect().has_point(event.global_position):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_select_item()
		else:
			if not is_selected:
				myBackgroundRect.color = default_color

func _select_item():
	is_selected = true
	myBackgroundRect.color = selected_color
	emit_signal("item_clicked", self)

func is_item_selected() -> bool:
	return is_selected

func unselect_item():
	is_selected = false
	myBackgroundRect.color = default_color

func _on_mouse_entered():
	if not is_selected:
		myBackgroundRect.color = hover_color

func _on_mouse_exited():
	if not is_selected:
		myBackgroundRect.color = default_color

# Function to set the text of the label. This hides the icon and shows the label.
func set_label_text(text: String):
	myLabel.text = text
	myLabel.visible = true
	myIcon.visible = false

# Function to get the text of the label.
func get_label_text() -> String:
	return myLabel.text

# Function to set the icon. This hides the label and shows the icon.
func set_icon(texture: Texture):
	myIcon.texture = texture
	myIcon.visible = true
	myLabel.visible = false

# Function to get the icon's texture.
func get_icon() -> Texture:
	return myIcon.texture

# Adjusts the size of the item based on its content
func adjust_size():
	var content_width = 0
	var content_height = 0

	# Calculate size based on visible content (label or icon)
	if myLabel.visible:
		content_width = myLabel.get_minimum_size().x
		content_height = myLabel.get_minimum_size().y
	
	# Check if the icon is visible and has a texture
	if myIcon.visible and myIcon.texture:
		custom_minimum_size = Vector2(32,32)

	# Set the size of the background rectangle to fit the content
	myBackgroundRect.custom_minimum_size = Vector2(content_width, content_height)
