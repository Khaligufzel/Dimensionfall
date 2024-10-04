extends Control

@export var panWindow: Control = null
@export var mapScrollWindow: ScrollContainer = null
@export var gridContainer: ColorRect = null
@export var tileGrid: GridContainer = null
@export var map_preview: Popup = null

# Settings controls:
@export var name_text_edit: TextEdit
@export var description_text_edit: TextEdit
@export var categories_list: Control
@export var weight_spin_box: SpinBox


# Neighbor key controls to manage the keys assigned to this map
@export var neighbor_key_option_button: OptionButton = null
@export var neighbor_key_text_edit: TextEdit = null
@export var neighbor_key_grid_container: GridContainer = null


# Connection controls
@export var north_check_box: CheckBox = null # Checked if this map has a road connection north
@export var east_check_box: CheckBox = null # Checked if this map has a road connection east
@export var south_check_box: CheckBox = null # Checked if this map has a road connection south
@export var west_check_box: CheckBox = null # Checked if this map has a road connection west

# Controls to add categories to the list of neighbors
@export var gridkey_option_button: OptionButton = null
@export var neighbor_north_check_box: CheckBox = null
@export var neighbor_east_check_box: CheckBox = null
@export var neighbor_south_check_box: CheckBox = null
@export var neighbor_west_check_box: CheckBox = null

# Controls to display existing neighbors connections
@export var neighbors_grid_container: GridContainer = null
@export var north_h_flow_container: HFlowContainer = null
@export var east_h_flow_container: HFlowContainer = null
@export var south_h_flow_container: HFlowContainer = null
@export var west_h_flow_container: HFlowContainer = null


signal zoom_level_changed(value: int)

# This signal should alert the content_list that a refresh is needed
@warning_ignore("unused_signal")
signal data_changed()
var tileSize: int = 128
var mapHeight: int = 32
var mapWidth: int = 32
var currentMap: DMap:
	set(newMap):
		currentMap = newMap
		set_settings_values()
		tileGrid.on_map_data_changed()


var zoom_level: int = 20:
	set(val):
		zoom_level = val
		zoom_level_changed.emit(zoom_level)


func _ready():
	setPanWindowSize()
	populate_gridkey_options() # For the neighbors grid
	populate_neighbor_key_options() # For the keys assigned to this map
	zoom_level = 20
	
func setPanWindowSize():
	var panWindowWidth: float = 0.8*tileSize*mapWidth
	var panWindowHeight: float = 0.8*tileSize*mapHeight
	panWindow.custom_minimum_size = Vector2(panWindowWidth, panWindowHeight)


var mouse_button_pressed: bool = false

func _input(event):
	if not visible:
		return
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_MIDDLE: 
				if event.pressed:
					mouse_button_pressed = true
				else:
					mouse_button_pressed = false
	
	#When the users presses and holds the mouse wheel, we scoll the grid
	if event is InputEventMouseMotion:
		if mouse_button_pressed:
			mapScrollWindow.scroll_horizontal = mapScrollWindow.scroll_horizontal - event.relative.x
			mapScrollWindow.scroll_vertical = mapScrollWindow.scroll_vertical - event.relative.y


#Scroll to the center when the scroll window is ready
func _on_map_scroll_window_ready():
	await get_tree().create_timer(0.5).timeout
	mapScrollWindow.scroll_horizontal = int(panWindow.custom_minimum_size.x/3.5)
	mapScrollWindow.scroll_vertical = int(panWindow.custom_minimum_size.y/3.5)

func _on_zoom_scroller_zoom_level_changed(value):
	zoom_level = value

func _on_tile_grid_zoom_level_changed(value):
	zoom_level = value

#The editor is closed, destroy the instance
#TODO: Check for unsaved changes
func _on_close_button_button_up():
	# If the user has pressed the save button before closing the editor, the tileGrid.oldmap should
	# contain the same data as currentMap, so it shouldn't make a difference
	# If the user did not press the save button, we reset the map to what it was before the last save
	currentMap.set_data(tileGrid.oldmap.get_data().duplicate(true))
	queue_free()


func _on_rotate_map_button_up():
	tileGrid.rotate_map()


# When the user presses the map preview button
func _on_preview_map_button_up():
	map_preview.mapData = currentMap.get_data()
	map_preview.show()


# Function to set the values of the controls
func set_settings_values() -> void:
	# Set basic properties
	name_text_edit.text = currentMap.name
	description_text_edit.text = currentMap.description
	if not currentMap.categories.is_empty():
		categories_list.set_items(currentMap.categories)
	weight_spin_box.value = currentMap.weight

	# Set road connections using currentMap.get_connection()
	north_check_box.button_pressed = currentMap.get_connection("north") == "road"
	east_check_box.button_pressed = currentMap.get_connection("east") == "road"
	south_check_box.button_pressed = currentMap.get_connection("south") == "road"
	west_check_box.button_pressed = currentMap.get_connection("west") == "road"

	# Update neighbors
	var south_neighbors: Array = currentMap.get_neighbors("south")
	populate_neighbors_container(south_h_flow_container, south_neighbors)

	var north_neighbors: Array = currentMap.get_neighbors("north")
	populate_neighbors_container(north_h_flow_container, north_neighbors)

	var east_neighbors: Array = currentMap.get_neighbors("east")
	populate_neighbors_container(east_h_flow_container, east_neighbors)

	var west_neighbors: Array = currentMap.get_neighbors("west")
	populate_neighbors_container(west_h_flow_container, west_neighbors)
	
	# Clear existing neighbor keys
	Helper.free_all_children(neighbor_key_grid_container)
	
	# Populate neighbor keys from currentMap
	for key in currentMap.neighbor_keys.keys():
		var weight = currentMap.neighbor_keys[key]
		_add_neighbor_key_controls(key, weight)
		


# Function to get the values of the controls
func update_settings_values():
	# Update basic properties
	currentMap.name = name_text_edit.text
	currentMap.description = description_text_edit.text
	currentMap.categories = categories_list.get_items()
	currentMap.weight = int(weight_spin_box.value)

	# Update road connections using currentMap.set_connection()
	if north_check_box.button_pressed:
		currentMap.set_connection("north","road")
	else:
		currentMap.set_connection("north","ground")
	if east_check_box.button_pressed:
		currentMap.set_connection("east","road")
	else:
		currentMap.set_connection("east","ground")
	if south_check_box.button_pressed:
		currentMap.set_connection("south","road")
	else:
		currentMap.set_connection("south","ground")
	if west_check_box.button_pressed:
		currentMap.set_connection("west","road")
	else:
		currentMap.set_connection("west","ground")

	# Update neighbors for all directions
	var north_neighbors = get_neighbors_from_container(north_h_flow_container)
	currentMap.set_neighbors("north", north_neighbors)

	var east_neighbors = get_neighbors_from_container(east_h_flow_container)
	currentMap.set_neighbors("east", east_neighbors)

	var south_neighbors = get_neighbors_from_container(south_h_flow_container)
	currentMap.set_neighbors("south", south_neighbors)

	var west_neighbors = get_neighbors_from_container(west_h_flow_container)
	currentMap.set_neighbors("west", west_neighbors)

	# Clear current neighbor keys in the map
	currentMap.neighbor_keys.clear()

	# Read values from neighbor_key_grid_container
	var children = neighbor_key_grid_container.get_children()
	for i in range(0, children.size(), 3):  # Iterate in sets of 3 (Label, SpinBox, Button)
		var key_label = children[i] as Label
		var weight_spinbox = children[i + 1] as SpinBox
		# Add the key-value pair to currentMap.neighbor_keys
		currentMap.neighbor_keys[key_label.text] = weight_spinbox.value


# The user presses the "add" button in the neighbors controls
# We create a new HBox for each direction that was checked on.
func _on_add_neighbor_button_button_up() -> void:
	var selected_category = gridkey_option_button.get_item_text(gridkey_option_button.selected)

	# If the south neighbor checkbox is checked, add the neighbor to the south container
	if neighbor_south_check_box.button_pressed:
		create_neighbor_hbox(selected_category, 100, south_h_flow_container)

	# If the north neighbor checkbox is checked, add the neighbor to the north container
	if neighbor_north_check_box.button_pressed:
		create_neighbor_hbox(selected_category, 100, north_h_flow_container)

	# If the east neighbor checkbox is checked, add the neighbor to the east container
	if neighbor_east_check_box.button_pressed:
		create_neighbor_hbox(selected_category, 100, east_h_flow_container)

	# If the west neighbor checkbox is checked, add the neighbor to the west container
	if neighbor_west_check_box.button_pressed:
		create_neighbor_hbox(selected_category, 100, west_h_flow_container)


func populate_gridkey_options() -> void:
	var unique_neighborkeys = Gamedata.maps.get_unique_neighbor_keys()
	gridkey_option_button.clear()  # Clear previous options
	for neighborkey in unique_neighborkeys:
		gridkey_option_button.add_item(neighborkey)


func get_neighbors_from_container(container: HFlowContainer) -> Array:
	var neighbors = []
	for child in container.get_children():
		if child is HBoxContainer:
			var neighbor_key = ""
			var weight = 0
			# Loop through the children of HBoxContainer
			for hbox_child in child.get_children():
				if hbox_child is Label:
					neighbor_key = hbox_child.text
				elif hbox_child is SpinBox:
					weight = hbox_child.value
			neighbors.append({"neighbor_key": neighbor_key, "weight": weight})
	return neighbors


# Takes a list of neighbors and creates controls in the corresponding HFlowContainer to manage 
# the neighbors. Each direction has a separate HFlowContainer
func populate_neighbors_container(container: HFlowContainer, neighbors: Array) -> void:
	Helper.free_all_children(container)  # Remove previous neighbors
	for neighbor in neighbors:
		create_neighbor_hbox(neighbor["neighbor_key"], neighbor["weight"], container)


# The user has clicked on the delete button on a neighbor in the list. We remove the Hbox for the neighbor
func _on_delete_neighbor(hbox_to_remove: HBoxContainer) -> void:
	# Remove the HBoxContainer from its parent (the HFlowContainer)
	var parent_container = hbox_to_remove.get_parent()
	if parent_container:
		parent_container.remove_child(hbox_to_remove)
		hbox_to_remove.queue_free()  # Properly free the HBoxContainer from memory


# Create a new Hbox for the provided category and direction
# cateory: for example: "urban", "suburban", "plains"
# weight: for example: 100. A higher number will increase the chance to be picked during runtime
# container: for example: south_h_flow_container. Adds the category controls Hbox as a child
func create_neighbor_hbox(category: String, weight: int, container: HFlowContainer) -> HBoxContainer:
	var hbox = HBoxContainer.new()

	# Add a Label for the category
	var category_label = Label.new()
	category_label.text = category
	hbox.add_child(category_label)

	# Add a SpinBox for the weight
	var weight_spinbox = SpinBox.new()
	weight_spinbox.min_value = 0
	weight_spinbox.max_value = 100
	weight_spinbox.value = weight
	hbox.add_child(weight_spinbox)

	# Add a delete button
	var delete_button = Button.new()
	delete_button.text = "X"
	delete_button.pressed.connect(_on_delete_neighbor.bind(hbox))
	hbox.add_child(delete_button)

	# Add the HBoxContainer to the appropriate HFlowContainer
	container.add_child(hbox)

	return hbox


# Called when the user presses the add_neighbor_key_button
func _on_add_neighbor_key_button_button_up() -> void:
	var new_key: String = ""
	
	# Step 1: Check if neighbor_key_text_edit contains a value
	if neighbor_key_text_edit.text.strip_edges() != "":
		new_key = neighbor_key_text_edit.text.strip_edges()
	else:
		# Step 2: If neighbor_key_text_edit is empty, read the option from neighbor_key_option_button
		new_key = neighbor_key_option_button.get_item_text(neighbor_key_option_button.selected)
	
	# Clear the text field after reading the key
	neighbor_key_text_edit.clear()
	
	# Step 3: Check if the key already exists in neighbor_key_grid_container
	for child in neighbor_key_grid_container.get_children():
		if child is Label and child.text == new_key:
			return  # If the key already exists, exit the function
	
	# Step 4: Add the new key to gridkey_option_button if it's not already in the list
	var key_exists = false
	for i in range(gridkey_option_button.item_count):
		if gridkey_option_button.get_item_text(i) == new_key:
			key_exists = true
			break
	if not key_exists:
		gridkey_option_button.add_item(new_key)

	# Step 5: Add controls to neighbor_key_grid_container
	_add_neighbor_key_controls(new_key, 100)  # Default weight is 100


# Helper function to add a key with a label, spinbox, and delete button directly to the grid container
func _add_neighbor_key_controls(key: String, weight: int) -> void:
	# Add a Label for the key
	var key_label = Label.new()
	key_label.text = key
	neighbor_key_grid_container.add_child(key_label)  # Add the label directly to the grid container

	# Add a SpinBox for the weight
	var weight_spinbox = SpinBox.new()
	weight_spinbox.min_value = 0
	weight_spinbox.max_value = 100
	weight_spinbox.value = weight
	neighbor_key_grid_container.add_child(weight_spinbox)  # Add the spinbox directly to the grid container

	# Add a delete button to remove the key
	var delete_button = Button.new()
	delete_button.text = "X"
	delete_button.pressed.connect(_on_delete_neighbor_key.bind(delete_button, key_label, weight_spinbox))
	neighbor_key_grid_container.add_child(delete_button)  # Add the button directly to the grid container


# Deletes a neighbor key from the grid container
func _on_delete_neighbor_key(delete_button: Button, key_label: Label, weight_spinbox: SpinBox) -> void:
	# Remove the key label, weight spinbox, and delete button from the grid container
	neighbor_key_grid_container.remove_child(key_label)
	neighbor_key_grid_container.remove_child(weight_spinbox)
	neighbor_key_grid_container.remove_child(delete_button)

	# Properly free the nodes
	key_label.queue_free()
	weight_spinbox.queue_free()
	delete_button.queue_free()


# Populates the neighbor_key_option_button with unique neighbor keys from Gamedata.maps
func populate_neighbor_key_options() -> void:
	var unique_neighbor_keys = Gamedata.maps.get_unique_neighbor_keys()
	neighbor_key_option_button.clear()  # Clear previous options
	for key in unique_neighbor_keys:
		neighbor_key_option_button.add_item(key)
