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
	var mymaxiterations: int = max_iterations_spin_box.value
	# Define the dimensions of the grid as 20x20 units
	var myareaname: String = area_option_button.get_item_text(area_option_button.selected)
	var myovermaparea: DOvermaparea = Gamedata.overmapareas.by_id(myareaname)
	var mydimensions = set_area_dimensions(myovermaparea)

	# Create a new instance of OvermapAreaGenerator and generate the area grid
	var mygenerator: OvermapAreaGenerator = OvermapAreaGenerator.new()
	if not mydimensions == Vector2(0,0):
		mygenerator.dimensions = mydimensions
		visual_grid.columns = mydimensions.x
	mygenerator.dovermaparea = myovermaparea
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



# Function to set the dimensions for the area generator based on the dovermaparea data
func set_area_dimensions(dovermaparea: DOvermaparea) -> Vector2:
	var mywidth: int = width_spin_box.value
	var myheight: int = height_spin_box.value
	# Check if the dimensions are already set to a non-default value
	if not mywidth == 0 and not myheight == 0:
		return Vector2(mywidth,myheight) # Terminate if no dimensions are set

	# Ensure that dovermaparea data is available
	if dovermaparea == null:
		print_debug("set_area_dimensions: dovermaparea data not available")
		return Vector2.ZERO

	# Randomly set dimensions using the min and max width/height from the dovermaparea data
	var random_width = randi() % (dovermaparea.max_width - dovermaparea.min_width + 1) + dovermaparea.min_width
	var random_height = randi() % (dovermaparea.max_height - dovermaparea.min_height + 1) + dovermaparea.min_height
	return Vector2(random_width, random_height)
