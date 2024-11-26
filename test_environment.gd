extends Node3D

@export var canvas_layer: CanvasLayer = null
@export var chunk: Chunk = null



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if Input.is_action_just_pressed("escape"):
		canvas_layer.show()


# The user pressed the return button, we go to the contenteditor
func _on_return_button_button_up() -> void:
	chunk.unload_chunk()
	Helper.test_map_name = "" # Reset this before returning otherwise the main game will be in trouble
	get_tree().change_scene_to_file("res://Scenes/ContentManager/contenteditor.tscn")


# The user presses the resume button, hide the window
func _on_resume_button_button_up() -> void:
	canvas_layer.hide()
