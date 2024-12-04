extends Control

@export var visual_grid: GridContainer = null
@export var tileScene: PackedScene
@export var width_spin_box: SpinBox = null
@export var height_spin_box: SpinBox = null
@export var max_iterations_spin_box: SpinBox = null


# Variable to store the area
var myovermaparea: ROvermaparea


func _on_generate_button_button_up() -> void:
	Helper.free_all_children(visual_grid)
	generate_grid()


func generate_grid():
	visual_grid.set("theme_override_constants/h_separation", 0)
	visual_grid.set("theme_override_constants/v_separation", 0)
	var mymaxiterations: int = int(max_iterations_spin_box.value)
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
				var dmap: RMap = tileinfo.rmap
				var myrotation: int = tileinfo.rotation
				tile_instance.set_texture(dmap.sprite)
				# HACK: Second argument is the pivot offset. The automatic calculations for this are
				# failing for some reason, so we put in half the minumum size of 32 in manually
				tile_instance.set_texture_rotation(myrotation, Vector2(16, 16))
			else:
				# If no tile exists at the current position, set texture to null
				tile_instance.set_texture(null)


# Function to set the dimensions for the area generator based on the dovermaparea data
func set_area_dimensions(dovermaparea: ROvermaparea) -> Vector2:
	var mywidth: int = int(width_spin_box.value)
	var myheight: int = int(height_spin_box.value)
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



# Setter method to update the selected area
func set_area(newarea: DOvermaparea) -> void:
	var rovermaparea: ROvermaparea = ROvermaparea.new(null,newarea.id)
	rovermaparea.overwrite_from_dovermaparea(newarea)
	myovermaparea = rovermaparea
