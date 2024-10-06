extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_wave_collapse_button_button_up() -> void:
	get_tree().change_scene_to_file("res://Scenes/ContentManager/OtherTools/wave_collapse_generator.tscn")


func _on_back_button_button_up() -> void:
	get_tree().change_scene_to_file("res://Scenes/ContentManager/contentmanager.tscn")
