extends VBoxContainer

@export var region_name_label: Label = null
@export var min_range_h_slider: HSlider = null
@export var max_range_h_slider: HSlider = null
@export var maps_grid_container: GridContainer = null
@export var min_range_value_label: Label = null
@export var max_range_value_label: Label = null



# Example data:
#         "spawn_probability": {
#           "range": {
#             "start_range": 70,  // Will start spawning at 70% distance from the center
#             "end_range": 100     // Will stop spawning at 100% distance from the center
#           }
#         },
#         "maps": [
#           {
#             "id": "field_01",
#             "weight": 12
#           },
#           {
#             "id": "barn_01",
#             "weight": 6
#           },
#           {
#             "id": "tree_01",
#             "weight": 8
#           }


signal delete_button_pressed

# Initialize drag-and-drop forwarding for the maps_grid_container
func _ready() -> void:
	maps_grid_container.set_drag_forwarding(Callable(), _can_drop_map_data, _drop_map_data)


# Function to set the slider values and load map data based on a provided dictionary
func set_values(data: Dictionary) -> void:
	# Set the slider values for spawn probability range
	if data.has("spawn_probability") and data["spawn_probability"].has("range"):
		var range_data = data["spawn_probability"]["range"]
		if min_range_h_slider != null and range_data.has("start_range"):
			min_range_h_slider.value = range_data["start_range"]
		if max_range_h_slider != null and range_data.has("end_range"):
			max_range_h_slider.value = range_data["end_range"]

	# Load maps into the UI if they are present in the data
	if data.has("maps"):
		_load_maps_into_ui(data["maps"])


# Function to get the slider values and map data and return them as a dictionary
func get_values() -> Dictionary:
	var slider_data: Dictionary = {
		"spawn_probability": {
			"range": {
				"start_range": int(min_range_h_slider.value) if min_range_h_slider != null else 0,
				"end_range": int(max_range_h_slider.value) if max_range_h_slider != null else 0
			}
		},
		"maps": _get_maps_from_ui()  # Retrieve the current maps data from the UI
	}
	return slider_data


# Load maps into the maps_grid_container
func _load_maps_into_ui(maps: Array) -> void:
	# Clear previous map entries from the container
	for child in maps_grid_container.get_children():
		child.queue_free()

	# Populate the container with the maps data
	for map_data in maps:
		_add_map_entry(map_data)


# Get the current maps from the UI and return them as an array of dictionaries
func _get_maps_from_ui() -> Array:
	var maps = []
	var children = maps_grid_container.get_children()

	# Loop through the children and extract map information
	for i in range(0, children.size(), 4):  # Step by 5 to handle sprite-id-label-label-spinbox-delete entries
		var id_label = children[i + 1] as Label  # The label containing the map ID
		var spinbox = children[i + 2] as SpinBox  # The spinbox containing the map weight

		# Append map data to the list as a dictionary
		maps.append({"id": id_label.text, "weight": int(spinbox.value)})

	return maps


# Function to set the region name label
func set_region_name(newname: String) -> void:
	if region_name_label != null:
		region_name_label.text = newname

# Function to get the region name from the label
func get_region_name() -> String:
	return region_name_label.text if region_name_label != null else ""


# Function to determine if the dragged data can be dropped in the maps_grid_container
func _can_drop_map_data(_newpos, data) -> bool:
	# Check if the data dictionary has the 'id' property
	if not data or not data.has("id"):
		return false

	# Fetch map by ID from the Gamedata to ensure it exists and is valid
	if not Gamedata.mods.by_id(data["mod_id"]).maps.has_id(data["id"]):
		return false

	# Check if the map ID already exists in the maps grid
	var children = maps_grid_container.get_children()
	for i in range(1, children.size(), 3):  # Step by 3 to handle sprite-label-spinbox triples
		var label = children[i] as Label
		if label and label.text == data["id"]:
			# Return false if this map ID already exists in the maps grid
			return false

	# If all checks pass, return true
	return true


# Function to handle the data being dropped in the maps_grid_container
func _drop_map_data(newpos, data) -> void:
	if _can_drop_map_data(newpos, data):
		_handle_map_drop(data, newpos)


# Called when the user has successfully dropped data onto the maps_grid_container
# This function checks the dropped data for the 'id' property
func _handle_map_drop(dropped_data, _newpos) -> void:
	# dropped_data is a Dictionary that includes an 'id'
	if dropped_data and "id" in dropped_data:
		var map_id = dropped_data["id"]
		if not Gamedata.mods.by_id(dropped_data["mod_id"]).maps.has_id(map_id):
			print_debug("No map data found for ID: " + map_id)
			return
		
		# Add the map entry using the new function
		_add_map_entry({"id": map_id, "weight": 100, "mod_id": dropped_data["mod_id"]})  # Default weight set to 100
	else:
		print_debug("Dropped data does not contain an 'id' key.")


# Function to add a new map entry to the maps_grid_container
func _add_map_entry(map_data: Dictionary) -> void:
	var mymap = Gamedata.mods.get_content_by_id(DMod.ContentType.MAPS, map_data.id)

	# Create a TextureRect for the map sprite
	var texture_rect = TextureRect.new()
	texture_rect.texture = mymap.sprite
	texture_rect.custom_minimum_size = Vector2(32, 32)  # Ensure the texture is 32x32
	texture_rect.stretch_mode = TextureRect.STRETCH_SCALE  # Keep the aspect ratio centered
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	maps_grid_container.add_child(texture_rect)

	# Create a Label for the map ID
	var id_label = Label.new()
	id_label.text = mymap.id
	maps_grid_container.add_child(id_label)

	# Create a SpinBox for the map weight
	var weight_spinbox = SpinBox.new()
	weight_spinbox.min_value = 1
	weight_spinbox.max_value = 100
	weight_spinbox.value = map_data.weight
	weight_spinbox.tooltip_text = "Enter the weight for this map. This will be the weight \n" + \
								"relative to the other maps in this region. A higher weight \n" + \
								"will make it more likely that this map is picked. A lower \n" + \
								"weight makes it less likely for this map to spawn."
	maps_grid_container.add_child(weight_spinbox)

	# Create a Button to delete the map entry
	var delete_button = Button.new()
	delete_button.text = "X"
	delete_button.tooltip_text = "Delete this map entry."
	maps_grid_container.add_child(delete_button)

	# Connect the delete button's button_up signal to remove the map entry
	delete_button.button_up.connect(func():
		_remove_map_entry(texture_rect, id_label, weight_spinbox, delete_button)
	)


# Function to handle changes in the min_range_h_slider value
func _on_min_range_h_slider_value_changed(value: float) -> void:
	# Update the label with the percentage value
	if min_range_value_label != null:
		min_range_value_label.text = str(int(value)) + "%"

# Function to handle changes in the max_range_h_slider value
func _on_max_range_h_slider_value_changed(value: float) -> void:
	# Update the label with the percentage value
	if max_range_value_label != null:
		max_range_value_label.text = str(int(value)) + "%"


func _on_delete_button_button_up() -> void:
	delete_button_pressed.emit()


# Function to remove a map entry (called when the delete button is pressed)
func _remove_map_entry(texture_rect: TextureRect, id_label: Label, weight_spinbox: SpinBox, delete_button: Button) -> void:
	maps_grid_container.remove_child(texture_rect)
	texture_rect.queue_free()

	maps_grid_container.remove_child(id_label)
	id_label.queue_free()

	maps_grid_container.remove_child(weight_spinbox)
	weight_spinbox.queue_free()

	maps_grid_container.remove_child(delete_button)
	delete_button.queue_free()
