extends VBoxContainer

# This script is intended to be used with the mapeditor_brushcomposer.tscn
# This brushcomposer allows the user to compose a brush made up of one or more
# tile brushes. When a brush is selected, you can hold ctrl and click another brush
# to add it to the selected brushes. When 2 or more brushes are selected, the map 
# editor will pick one at random and paint it onto the map.

# This allows you to compose a custom brush. For example, if I want to add a grass
# field where some dirt patches are randomy added, I can add the grass tile six times 
# and the dirt tile 1 time and then start painting to have it randomly distributed.

#Additional features:

	# TODO: Have a button to add a 'null' tile that will include an empty brush. 
	# To demonstrate the use case: Add 6 null tiles and 1 mob and you can 
	# randomly distribute mobs on your map, having them spawn 1 in 7 chance
	
	# TODO: Have a button to enable/disable random rotation while painting
	
	# TODO: Have a button to toggle whether you want to pick a random tile each brush 
	# stroke or each click. When selecting 'each brush stroke', it will pick a 
	# random one each time it would paint a tile, so when clicking and dragging. 
	# When selecting 'each click', it will pick one tile and keep painting it 
	# until you release the mouse button. This is useful for painting house 
	# floors where you might want a random floor, but have each tile in the 
	# floor be the same.
	
	# TODO: Add an erase button to clear the brush
	# TODO: Have the brush be remembered when leaving the map editor

@export var brush_container: Control
@export var tileBrush: PackedScene = null


# Signals to indicate when a brush is added or removed
signal brush_added(brush: Control)
signal brush_removed(brush: Control)


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


# Function to clear the children of brush_container
func clear_brush_container():
	for child in brush_container.get_children():
		brush_container.remove_child(child)
		child.queue_free()


# Function to add a new tilebrush to the brush_container
func add_tilebrush_to_container(original_tilebrush: Control):
	var brushInstance: Control = tileBrush.instantiate()
	brushInstance.set_tile_texture(original_tilebrush.get_texture())
	brushInstance.tileID = original_tilebrush.tileID
	brushInstance.tilebrush_clicked.connect(_on_tilebrush_clicked)
	brushInstance.entityType = original_tilebrush.entityType
	brushInstance.set_minimum_size(Vector2(32,32))
	brush_container.add_content_item(brushInstance)
	emit_signal("brush_added", brushInstance)


# Function to handle tilebrush click and remove it from the container
func _on_tilebrush_clicked(brush):
	if brush_container.has_node(brush.get_path()):
		brush_container.remove_child(brush)
		brush.queue_free()
		emit_signal("brush_removed", brush)


# Function to get a random child from the brush_container
func get_random_brush() -> Control:
	var children = brush_container.get_children()
	if children.size() == 0:
		return null
	return children[randi() % children.size()]
