extends Control


# This script is intended to be used by the CtrlInventoryStackedListHeaderItem
# It is meant to be a container for a label that displays a column header
# When the mouse cursor hover over this item, it will change color
# When this item is clicked, it will change color to indicate it is selected
# When this item is clicked, it will emit a signal that it is clicked


@export var myBackgroundRect: ColorRect
@export var myLabel: Label

# Colors for different states
var default_color: Color = Color(0.4, 0.4, 0.4, 1) # Default color
var hover_color: Color = Color(0.8, 0.8, 0.8, 1) # Hover color
var selected_color: Color = Color(0.5, 0.5, 0.8, 1) # Selected color

var is_selected: bool = false

signal header_clicked(item: Control)

# Called when the node enters the scene tree for the first time.
func _ready():
	myBackgroundRect.color = default_color
	connect("mouse_entered", _on_mouse_entered)
	connect("mouse_exited", _on_mouse_exited)

func select_item():
	is_selected = true
	myBackgroundRect.color = selected_color

func is_item_selected() -> bool:
	return is_selected

func unselect_item():
	is_selected = false
	myBackgroundRect.color = default_color

func _on_mouse_entered():
	highlight()

func _on_mouse_exited():
	unhighlight()
		
func highlight():
	if not is_selected:
		myBackgroundRect.color = hover_color

func unhighlight():
	if not is_selected:
		myBackgroundRect.color = default_color

# Function to set the text of the label. This hides the icon and shows the label.
func set_label_text(text: String):
	myLabel.text = text
	myLabel.visible = true

# Function to get the text of the label.
func get_label_text() -> String:
	return myLabel.text

func _on_gui_input(event):
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if event.pressed:
					if is_selected:
						unselect_item()
					else:
						select_item()
					header_clicked.emit(self)
