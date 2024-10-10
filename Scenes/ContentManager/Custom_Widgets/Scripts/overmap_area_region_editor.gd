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
				"start_range": min_range_h_slider.value if min_range_h_slider != null else 0,
				"end_range": max_range_h_slider.value if max_range_h_slider != null else 0
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
	for i in range(0, children.size(), 3):  # Step by 3 to handle sprite-label-spinbox triples
		var label = children[i + 1] as Label  # The label containing the map ID
		var spinbox = children[i + 2] as SpinBox  # The spinbox containing the map weight

		# Append map data to the list as a dictionary
		maps.append({"id": label.text, "weight": int(spinbox.value)})

	return maps


# Function to set the region name label
func set_region_name(name: String) -> void:
	if region_name_label != null:
		region_name_label.text = name

# Function to get the region name from the label
func get_region_name() -> String:
	return region_name_label.text if region_name_label != null else ""


# Function to determine if the dragged data can be dropped in the maps_grid_container
func _can_drop_map_data(_newpos, data) -> bool:
	# Check if the data dictionary has the 'id' property
	if not data or not data.has("id"):
		return false

	# Fetch map by ID from the Gamedata to ensure it exists and is valid
	if not Gamedata.maps.has_id(data["id"]):
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
		if not Gamedata.maps.has_id(map_id):
			print_debug("No map data found for ID: " + map_id)
			return
		
		# Add the map entry using the new function
		_add_map_entry({"id": map_id, "weight": 100})  # Default weight set to 100
	else:
		print_debug("Dropped data does not contain an 'id' key.")


# Function to add a new map entry to the maps_grid_container
func _add_map_entry(map_data: Dictionary) -> void:
	var mymap = Gamedata.maps.by_id(map_data.id)

	# Create a TextureRect for the map sprite
	var texture_rect = TextureRect.new()
	texture_rect.texture = mymap.sprite
	texture_rect.custom_minimum_size = Vector2(32, 32)  # Ensure the texture is 32x32
	texture_rect.stretch_mode = TextureRect.STRETCH_SCALE  # Keep the aspect ratio centered
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	maps_grid_container.add_child(texture_rect)

	# Create a Label for the map ID
	var label = Label.new()
	label.text = mymap.id
	maps_grid_container.add_child(label)

	# Create a SpinBox for the map weight
	var weight_spinbox = SpinBox.new()
	weight_spinbox.min_value = 1
	weight_spinbox.max_value = 100
	weight_spinbox.value = map_data.weight
	maps_grid_container.add_child(weight_spinbox)


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
