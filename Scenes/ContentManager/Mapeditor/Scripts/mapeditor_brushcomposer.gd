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
@export var groups_option_button: OptionButton
@export var group_editor: Popup
# Reference to the gridcontainer in the mapeditor
@export var gridContainer: GridContainer


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


# Function to get all brushes in the brushcomposer. Could be empty.
func get_all_brushes() -> Array:
	return brush_container.get_content_items()


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


# Function to get the value of the selected option in groups_option_button
func get_selected_group_name() -> String:
	return groups_option_button.get_item_text(groups_option_button.selected)


# Function to process brushes and generate group data
func generate_group_data() -> Dictionary:
	# Get all brushes from the brush container
	var brushes = get_all_brushes()
	
	# Return if the brush list is empty
	if brushes.is_empty():
		return {}
	
	# Initialize the default group data
	var group_data: Dictionary = {
		"id": "group1",
		"tiles": [],
		"furniture": [],
		"mobs": [],
		"itemgroups": [],
		"rotate_random": false,
		"spawn_chance": 100
	}
	
	
	# Loop over each brush and sort by entityType
	for brush in brushes:
		var entity_type: String = brush.entityType
		var entity_id: String = brush.entityID
		var entity_data = {"id": entity_id, "count": 1}
		
		# Only add the entities once and do not add duplicates of the same id
		match entity_type:
			"tile":
				if not entity_exists_in_array(group_data["tiles"], entity_id):
					group_data["tiles"].append(entity_data)
			"mob":
				if not entity_exists_in_array(group_data["mobs"], entity_id):
					group_data["mobs"].append(entity_data)
			"furniture":
				if not entity_exists_in_array(group_data["furniture"], entity_id):
					group_data["furniture"].append(entity_data)
			"itemgroup":
				if not entity_exists_in_array(group_data["itemgroups"], entity_id):
					group_data["itemgroups"].append(entity_data)
	
	# Check if a group name is selected
	var selected_group_name: String = get_selected_group_name()
	print_debug("selected_group_name = " + selected_group_name)
	if selected_group_name == "None":
		var new_id: String = generate_unique_group_id()
		group_data["id"] = new_id
		groups_option_button.add_item(new_id)  # Ensure the new ID is added to the groups_option_button
		groups_option_button.select(groups_option_button.get_item_count() - 1)  # Select the newly added item
	else: # One of the groups is already selected
		group_data["id"] = selected_group_name
	
	# Set rotate_random if the rotation button is pressed
	if rotation_button.button_pressed:
		group_data["rotate_random"] = true
	
	return group_data


# Function to check if entity ID already exists in the array
func entity_exists_in_array(array: Array, entity_id: String) -> bool:
	for entity in array:
		if entity["id"] == entity_id:
			return true
	return false


# Function to generate a unique group ID not present in the groups_option_button
func generate_unique_group_id() -> String:
	var existing_ids = []
	for i in range(groups_option_button.get_item_count()):
		existing_ids.append(groups_option_button.get_item_text(i))

	var new_id: String
	while true:
		new_id = "group" + str(Time.get_ticks_msec())
		if new_id not in existing_ids:
			break

	return new_id


# The user presses the button that will show the group editor popup
func _on_map_group_settings_button_button_up():
	group_editor.populate_group_list(gridContainer.get_map_groups())
	group_editor.show()


# When the user selects a group from the group optionbutton
# Populate the brushcomposer with the brushes from the group
func _on_groups_option_button_item_selected(index):
	# Get the selected group name
	var selected_group_name = groups_option_button.get_item_text(index)
	
	# Get the current map groups from mapData
	var map_groups = gridContainer.get_map_groups()
	
	# Find the selected group data in map_groups
	var selected_group_data = null
	for group in map_groups:
		if group["id"] == selected_group_name:
			selected_group_data = group
			break
	
	# Let the gridcontainer handle the selection as well
	gridContainer.on_groups_option_button_item_selected(groups_option_button, index)

	# If the selected group is not found in mapData, return
	if selected_group_data == null:
		print_debug("Selected group not found in mapData.")
		return
	
	# Clear all the brushes from the brush_container
	clear_brush_container()
	
	# Add brushes from the selected group data to the brush_container
	add_brushes_from_group(selected_group_data["tiles"], "tile")
	add_brushes_from_group(selected_group_data["furniture"], "furniture")
	add_brushes_from_group(selected_group_data["mobs"], "mob")
	add_brushes_from_group(selected_group_data["itemgroups"], "itemgroup")


# Function to add tile brushes to the container based on entity type
func add_brushes_from_group(entity_list: Array, entity_type: String):
	for entity in entity_list:
		var properties: Dictionary = {
			"entityID": entity["id"],
			"entityType": entity_type
		}
		# Get the appropriate sprite based on the entity type
		match entity_type:
			"tile":
				properties["texture"] = Gamedata.get_sprite_by_id(Gamedata.data.tiles, entity["id"])
			"furniture":
				properties["texture"] = Gamedata.get_sprite_by_id(Gamedata.data.furniture, entity["id"])
			"mob":
				properties["texture"] = Gamedata.get_sprite_by_id(Gamedata.data.mobs, entity["id"])
			"itemgroup":
				properties["texture"] = Gamedata.get_sprite_by_id(Gamedata.data.itemgroups, entity["id"])

		add_tilebrush_to_container_with_properties(properties)


# The user has selected OK in the groups editor popup menu.
# We now receive a modified groups list that we have to send back to the GridContainer.
func _on_group_editor_group_selected_ok(groups_clone: Array):
	# Update the map groups in gridContainer with the groups_clone data.
	gridContainer.update_map_groups(groups_clone)
	
	# Get the list of all group IDs from the groups_clone list.
	var group_ids = groups_clone.map(func(group): return group["id"])
	
	# Get the list of items from groups_option_button.
	var item_count = groups_option_button.get_item_count()
	var items_to_remove = []
	
	# Loop over the names in the groups_option_button.
	for i in range(item_count):
		var item_text = groups_option_button.get_item_text(i)
		# If the name is not present in the group_ids list, mark it for removal.
		if item_text not in group_ids:
			items_to_remove.append(i)
	
	# Remove items from groups_option_button starting from the highest index to avoid shifting issues.
	for i in range(items_to_remove.size() - 1, -1, -1):
		groups_option_button.remove_item(items_to_remove[i])
