extends Control

# Supports the reusable UI layout with a header and a swappable body window

@export var header_panel_container: PanelContainer = null
@export var body_panel_container: PanelContainer = null
@export var header_label: Label = null
@export var close_button: Button = null


# Text to display in the header
@export var header_text: String = "Window Title"

# Packed scene for the body content (e.g. inventory, crafting, etc.)
@export var body_scene: PackedScene = null

func _ready():
	header_label.text = header_text

	if body_scene:
		var instance = body_scene.instantiate()
		body_panel_container.add_child(instance)

	# Connect close button to hide the window
	if close_button:
		close_button.pressed.connect(_on_close_button_pressed)


func _on_close_button_pressed():
	visible = false

func _input(event):
	# Check if we need to hide based on what input action the child window uses
	if body_scene.input_action != "" and event.is_action_pressed(body_scene.input_action):
		visible = not visible
