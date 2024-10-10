extends Control

@export var visual_grid: GridContainer = null
@export var tileScene: PackedScene
@export var width_spin_box: SpinBox = null
@export var height_spin_box: SpinBox = null
@export var max_iterations_spin_box: SpinBox = null
@export var area_option_button: OptionButton = null


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Refresh the area_option_button by clearing any existing items
	area_option_button.clear()

	# Add all overmap area keys to the area_option_button as options
	var area_keys = Gamedata.overmapareas.get_all().keys()
	for area_key in area_keys:
		area_option_button.add_item(area_key)


func _on_back_button_button_up() -> void:
	get_tree().change_scene_to_file("res://Scenes/ContentManager/othertools.tscn")


func _on_generate_button_button_up() -> void:
	Helper.free_all_children(visual_grid)
	generate_grid()


func generate_grid():
	visual_grid.set("theme_override_constants/h_separation", 0)
	visual_grid.set("theme_override_constants/v_separation", 0)
	var mywidth: int = width_spin_box.value
	var myheight: int = height_spin_box.value
	var mymaxiterations: int = max_iterations_spin_box.value
	# Define the dimensions of the grid as 20x20 units
	var mydimensions = Vector2(mywidth, myheight)
	var myareaname: String = area_option_button.get_item_text(area_option_button.selected)
	visual_grid.columns = mywidth

	# Create a new instance of OvermapAreaGenerator and generate the area grid
	var mygenerator: OvermapAreaGenerator = OvermapAreaGenerator.new()
	mygenerator.dimensions = mydimensions
	mygenerator.dovermaparea = Gamedata.overmapareas.by_id(myareaname)
	var mygrid: Dictionary = mygenerator.generate_area(mymaxiterations)

	# Loop over each x and y coordinate within the grid dimensions
	for y in range(int(mydimensions.y)):
		for x in range(int(mydimensions.x)):
			var current_position = Vector2(x, y)
			var tile_instance = tileScene.instantiate()  # Instantiate a new tile scene
			visual_grid.add_child(tile_instance)
			tile_instance.set_clickable(false)

			# Check if there is a tile at the current position in mygrid
			if mygrid.has(current_position):
				var tileinfo = mygrid[current_position]
				var dmap: DMap = tileinfo.dmap
				var myrotation: int = tileinfo.rotation
				tile_instance.set_texture(dmap.sprite)
				# HACK: Second argument is the pivot offset. The automatic calculations for this are
				# failing for some reason, so we put in half the minumum size of 32 in manually
				tile_instance.set_texture_rotation(myrotation, Vector2(16, 16))
			else:
				# If no tile exists at the current position, set texture to null
				tile_instance.set_texture(null)
