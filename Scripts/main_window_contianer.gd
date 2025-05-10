extends Control

# Supports the reusable UI layout with a header and a swappable body window

@export var header_panel_container: PanelContainer = null
@export var body_panel_container: PanelContainer = null
@export var header_label: Label = null


# Text to display in the header
@export var header_text: String = "Window Title"

# Packed scene for the body content (e.g. inventory, crafting, etc.)
@export var body_scene: PackedScene = null

func _ready():
	# Set the title text if a Label exists in the header
	header_label.text = header_text

	# Instantiate and add the body scene to the body container
	if body_scene:
		var instance = body_scene.instantiate()
		body_panel_container.add_child(instance)
