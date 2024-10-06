extends Control

@export var visual_grid: GridContainer = null
@export var tileScene: PackedScene



func _on_back_button_button_up() -> void:
	get_tree().change_scene_to_file("res://Scenes/ContentManager/othertools.tscn")


func _on_generate_button_button_up() -> void:
	var mygrid: GaeaGrid = Helper.wave_function_collapse.create_collapsed_grid()
	# This will be an array of 32*32 OvermapTileInfo
	var values: Array = mygrid.get_values(0) # Get all values form layer 0
	for tileinfo: OvermapTileInfo in values:
		var tile_instance = tileScene.instantiate()
		var dmap: DMap = tileinfo.dmap
		var myrotation: int = tileinfo.rotation
		visual_grid.add_child(tile_instance)
		tile_instance.set_clickable(false)
		tile_instance.set_texture(dmap.sprite)
		tile_instance.set_rotation(myrotation)


# Helper function to create tiles for a specific level grid
func create_level_tiles():
	for x in range(32):
		for y in range(32):
			var tile_instance = tileScene.instantiate()
			visual_grid.add_child(tile_instance)
			tile_instance.set_clickable(false)
