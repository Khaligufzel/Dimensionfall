extends Control

@export var visual_grid: GridContainer = null
@export var tileScene: PackedScene


func _on_generate_button_button_up() -> void:
	Helper.free_all_children(visual_grid)
	generate_grid()


func generate_grid():
	visual_grid.set("theme_override_constants/h_separation", 0)
	visual_grid.set("theme_override_constants/v_separation", 0)
	var mywidth: int = Helper.overmap_manager.grid_width
	var height: int = Helper.overmap_manager.grid_height

	visual_grid.columns = mywidth
	var mygrid = Helper.overmap_manager.create_new_grid_with_default_values()

	# Loop over each x and y coordinate within the grid dimensions
	for y in range(mywidth):
		for x in range(height):
			var current_position = Vector2(x, y)
			var tile_instance = tileScene.instantiate()  # Instantiate a new tile scene
			visual_grid.add_child(tile_instance)
			tile_instance.set_clickable(false)

			# Check if there is a tile at the current position in mygrid
			if mygrid.cells.has(current_position):
				var map_cell = mygrid.cells[current_position]
				var dmap: DMap = map_cell.dmap
				var myrotation: int = map_cell.rotation
				tile_instance.set_texture(dmap.sprite)
				# HACK: Second argument is the pivot offset. The automatic calculations for this are
				# failing for some reason, so we put in half the minumum size of 32 in manually
				tile_instance.set_texture_rotation(myrotation, Vector2(16, 16))
			else:
				# If no tile exists at the current position, set texture to null
				tile_instance.set_texture(null)


func _on_back_button_button_up() -> void:
	get_tree().change_scene_to_file("res://Scenes/ContentManager/othertools.tscn")
