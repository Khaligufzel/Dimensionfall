extends Control

@export var visual_grid: GridContainer = null
@export var tileScene: PackedScene


func _on_back_button_button_up() -> void:
	get_tree().change_scene_to_file("res://Scenes/ContentManager/othertools.tscn")


func _on_generate_button_button_up() -> void:
	Helper.free_all_children(visual_grid)
	generate_grid()
	#generate_grid.call_deferred()


func generate_grid():
	visual_grid.set("theme_override_constants/h_separation", 0)
	visual_grid.set("theme_override_constants/v_separation", 0)
	var mygenerator: OvermapAreaGenerator = OvermapAreaGenerator.new()
	var mygrid: Dictionary = mygenerator.generate_grid()
	for tileinfo in mygrid.values():
		var tile_instance = tileScene.instantiate()
		var dmap: DMap = tileinfo.dmap
		var myrotation: int = tileinfo.rotation
		visual_grid.add_child(tile_instance)
		tile_instance.set_clickable(false)
		tile_instance.set_texture(dmap.sprite)
		# HACK: Second argument is the pivot offset. The automatic calculations for this are
		# failing for some reason, so we put in half the minumum size of 32 in manually
		tile_instance.set_texture_rotation(myrotation, Vector2(16,16))

func _on_clear_button_button_up() -> void:
	Helper.free_all_children(visual_grid)
