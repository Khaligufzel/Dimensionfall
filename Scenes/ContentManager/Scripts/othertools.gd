extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_back_button_button_up() -> void:
	get_tree().change_scene_to_file("res://Scenes/ContentManager/contentmanager.tscn")


func _on_overmap_area_button_button_up() -> void:
	get_tree().change_scene_to_file("res://Scenes/ContentManager/OtherTools/overmap_area_visualization.tscn")
