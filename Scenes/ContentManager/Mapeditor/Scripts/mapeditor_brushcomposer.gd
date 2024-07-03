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
@export var rotation_button: Button


# Signals to indicate when a brush is added or removed
signal brush_added(brush: Control)
signal brush_removed(brush: Control)


# Called when the node enters the scene tree for the first time.
func _ready():
	# Set custom can_drop_func and drop_func for the brushcontainer, use default drag_func
	brush_container.set_drag_forwarding(Callable(), custom_can_drop_data, custom_drop_data)


# Function to clear the children of brush_container
func clear_brush_container():
	for child in brush_container.get_content_items():
		brush_container.remove_content_item(child)
		brush_removed.emit(child)
		child.queue_free()


# Extracts necessary properties from the original_tilebrush and returns them in a dictionary.
# This function collects the texture, entityID, and entityType from the original tilebrush.
func extract_tilebrush_properties(original_tilebrush: Control) -> Dictionary:
	if not original_tilebrush:
		return {}
	
	var properties: Dictionary = {}
	properties.texture = original_tilebrush.get_texture()
	properties.entityID = original_tilebrush.entityID
	properties.entityType = original_tilebrush.entityType
	
	return properties


# Creates a new tilebrush instance using the provided properties dictionary and adds it to the brush_container.
# The properties dictionary should contain the texture, entityID, and entityType.
func add_tilebrush_to_container_with_properties(properties: Dictionary):
	if properties.is_empty():
		return
	
	var brushInstance: Control = tileBrush.instantiate()
	brushInstance.set_tile_texture(properties.texture)
	brushInstance.entityID = properties.entityID
	brushInstance.entityType = properties.entityType
	brushInstance.tilebrush_clicked.connect(_on_tilebrush_clicked)
	brushInstance.set_minimum_size(Vector2(32, 32))
	brush_container.add_content_item(brushInstance)
	if not brushInstance.entityType == "itemgroup":
		brush_added.emit(brushInstance)


# Extracts properties from the original_tilebrush and uses them to create and add a new tilebrush instance to the container.
# This function first calls extract_tilebrush_properties to get the properties and then
# calls add_tilebrush_to_container_with_properties to add the new tilebrush instance to the brush_container.
func add_tilebrush_to_container(original_tilebrush: Control):
	var properties = extract_tilebrush_properties(original_tilebrush)
	add_tilebrush_to_container_with_properties(properties)


# Clears the brushcomposer and adds the new brush
func replace_all_with_brush(original_tilebrush: Control):
	clear_brush_container()
	add_tilebrush_to_container(original_tilebrush)


# Function to handle tilebrush click and remove it from the container
func _on_tilebrush_clicked(brush):
	brush_container.remove_content_item(brush)
	brush_removed.emit(brush)


# Function to get a random child from the brush_container
# Excludes those with entityType "itemgroup" unless only itemgroups are present
func get_random_brush() -> Control:
	var children = brush_container.get_content_items()
	var valid_brushes = []
	var itemgroup_brushes = []

	# Loop through the children and categorize brushes
	for child in children:
		if child.entityType == "itemgroup":
			itemgroup_brushes.append(child)
		else:
			valid_brushes.append(child)
	
	# If no valid brushes are found, return a random itemgroup brush
	if valid_brushes.size() == 0 and itemgroup_brushes.size() > 0:
		return itemgroup_brushes[randi() % itemgroup_brushes.size()]
	
	# If there are valid brushes, return a random valid brush
	if valid_brushes.size() > 0:
		return valid_brushes[randi() % valid_brushes.size()]
	
	# If no brushes are available, return null
	return null


# Function to get a list of entityIDs from children with entityType "itemgroup"
# If no such children are found, returns an empty array
func get_itemgroup_entity_ids() -> Array:
	var children = brush_container.get_content_items()
	var itemgroup_ids = []
	
	# Loop through the children and collect entityIDs of those with entityType "itemgroup"
	for child in children:
		if child.entityType == "itemgroup":
			itemgroup_ids.append(child.entityID)
	
	# Return the list of itemgroup IDs
	return itemgroup_ids


# Returns true if there are no brushes in the list. Otherwise it returns false
func is_empty() -> bool:
	return brush_container.get_content_items().size() == 0


# Returns a rotation amount based on whether or not the rotation button is checked
# If the rotation button is unchecked, we return the original rotation
# If the rotation button is checked, we return a random value of 0, 90, 180 or 270
func get_tilerotation(original_rotation: int) -> int:
	if rotation_button.button_pressed:
		var rotations = [0, 90, 180, 270]
		return rotations[randi() % rotations.size()]
	return original_rotation


# Custom function to determine if data can be dropped at the current location
# It will only accept itemgroups
func custom_can_drop_data(_mypos, dropped_data: Dictionary) -> bool:
	# Check if the data dictionary has the 'id' property
	if not dropped_data or not dropped_data.has("id"):
		return false
	
	# Fetch itemgroup data by ID from the Gamedata to ensure it exists and is valid
	var itemgroup_data = Gamedata.get_data_by_id(Gamedata.data.itemgroups, dropped_data["id"])
	if itemgroup_data.is_empty():
		return false

	# If all checks pass, return true
	return true


# Custom function to process the data drop
# It only accepts itemgroups and creates a brush out of it
func custom_drop_data(_mypos, dropped_data):
	# Dropped_data is a Dictionary that includes an 'id'
	if dropped_data and "id" in dropped_data:
		var itemgroup_id = dropped_data["id"]
		var itemgroup_data = Gamedata.get_data_by_id(Gamedata.data.itemgroups, itemgroup_id)
		if itemgroup_data.is_empty():
			print_debug("No item data found for ID: " + itemgroup_id)
			return
		
		var properties: Dictionary = {}
		properties.texture = Gamedata.get_sprite_by_id(Gamedata.data.itemgroups, itemgroup_id)
		properties.entityID = itemgroup_id
		properties.entityType = "itemgroup"
		add_tilebrush_to_container_with_properties(properties)
	else:
		print_debug("Dropped data does not contain an 'id' key.")
