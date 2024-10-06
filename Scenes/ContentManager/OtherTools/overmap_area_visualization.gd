extends Control

@export var visual_grid: GridContainer = null
@export var tileScene: PackedScene



func _on_back_button_button_up() -> void:
	get_tree().change_scene_to_file("res://Scenes/ContentManager/othertools.tscn")


func _on_generate_button_button_up() -> void:
	Helper.free_all_children(visual_grid)
	var mygenerator: OvermapAreaGenerator = OvermapAreaGenerator.new()
	var mygrid: Dictionary = mygenerator.generate_grid()
	# This will be an array of 20*20 OvermapAreaGenerator.Tile
	for tileinfo in mygrid.values():
		var tile_instance = tileScene.instantiate()
		var dmap: DMap = tileinfo.dmap
		var myrotation: int = 0
		visual_grid.add_child(tile_instance)
		tile_instance.set_clickable(false)
		tile_instance.set_texture(dmap.sprite)
		tile_instance.set_rotation(myrotation)


# Helper function to create tiles for a specific level grid
func create_level_tiles():
	for x in range(20):
		for y in range(20):
			var tile_instance = tileScene.instantiate()
			visual_grid.add_child(tile_instance)
			tile_instance.set_clickable(false)
