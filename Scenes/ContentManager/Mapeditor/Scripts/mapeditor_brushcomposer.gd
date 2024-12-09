extends VBoxContainer

# This script is intended to be used with the mapeditor_brushcomposer.tscn
# This brushcomposer allows the user to compose a brush made up of one or more
# tile brushes. When a brush is selected, you can hold ctrl and click another brush
# to add it to the selected brushes. When 2 or more brushes are selected, the map 
# editor will pick one at random and paint it onto the map.

# This allows you to compose a custom brush. For example, if I want to add a grass
# field where some dirt patches are randomly added, I can add the grass tile six times 
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
@export var areas_option_button: OptionButton
@export var area_editor: Popup
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
	return {
		"texture": original_tilebrush.get_texture(),
		"entityID": original_tilebrush.entityID,
		"entityType": original_tilebrush.entityType
	} if original_tilebrush else {}

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
	
	# Add the brush to the area data if an area is selected
	add_brush_to_area_data(properties)

# Function to add a brush to the area data
func add_brush_to_area_data(properties: Dictionary):
	# Get the selected area name
	var selected_area_name = get_selected_area_name()
	
	# If "None" is selected, do nothing
	if selected_area_name == "None":
		return
	
	# Find the selected area data in map_areas
	var selected_area_data = get_selected_area_data(selected_area_name)
	if selected_area_data.is_empty():
		print_debug("Selected area not found in mapData.")
		return
	
	
	# Add the brush to the appropriate category in the area data
	var entity_data = {"id": properties.entityID, "count": 1, "type": properties.entityType}
	if properties.entityType == "tile":
		add_entity_to_area(selected_area_data["tiles"], entity_data)
	else:
		add_entity_to_area(selected_area_data["entities"], entity_data)

	# Update the map areas in gridContainer
	gridContainer.update_map_areas(gridContainer.get_map_areas())

# Will append the entity id to the area list if it's not already in there
func add_entity_to_area(area_list: Array, entity_data: Dictionary):
	if not entity_exists_in_array(area_list, entity_data["id"]):
		area_list.append(entity_data)

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
	# Remove the brush from the brush container
	brush_container.remove_content_item(brush)
	remove_brush_from_area_data(extract_tilebrush_properties(brush))
	brush_removed.emit(brush)

# Function to remove a brush from the area data
func remove_brush_from_area_data(properties: Dictionary):
	# Get the selected area name
	var selected_area_name = get_selected_area_name()
	
	# If "None" is selected, do nothing
	if selected_area_name == "None":
		return
	
	var selected_area_data = get_selected_area_data(selected_area_name)
	if selected_area_data.is_empty():
		print_debug("Selected area not found in mapData.")
		return
	
	# Remove the brush from the entities in the area data
	remove_entity_from_area(selected_area_data["entities"], properties.entityID)
	
	# Update the map areas in gridContainer
	gridContainer.update_map_areas(gridContainer.get_map_areas())


# Function to remove an entity from an area list by its ID
func remove_entity_from_area(area_list: Array, entity_id: String):
	for i in range(area_list.size()):
		if area_list[i]["id"] == entity_id:
			area_list.erase(i)
			break


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
		return valid_brushes.pick_random()
	
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
	return [0, 90, 180, 270].pick_random() if rotation_button.button_pressed else original_rotation


# Custom function to determine if data can be dropped at the current location
# It will only accept itemgroups
func custom_can_drop_data(_mypos, dropped_data: Dictionary) -> bool:
	# Check if the data dictionary has the 'id' property
	if not dropped_data or not dropped_data.has("id"):
		return false
	
	# Fetch itemgroup data by ID from the Gamedata to ensure it exists and is valid
	if not Gamedata.itemgroups.has_id(dropped_data["id"]):
		return false

	# If all checks pass, return true
	return true


# Custom function to process the data drop
# It only accepts itemgroups and creates a brush out of it
func custom_drop_data(_mypos, dropped_data):
	# Dropped_data is a Dictionary that includes an 'id'
	if dropped_data and "id" in dropped_data:
		var itemgroup_id = dropped_data["id"]
		if not Gamedata.itemgroups.has_id(itemgroup_id):
			print_debug("No item data found for ID: " + itemgroup_id)
			return
		
		var properties: Dictionary = {
			"texture": Gamedata.itemgroups.sprite_by_id(itemgroup_id),
			"entityID": itemgroup_id,
			"entityType": "itemgroup"
		}
		add_tilebrush_to_container_with_properties(properties)
	else:
		print_debug("Dropped data does not contain an 'id' key.")


# Function to get the value of the selected option in areas_option_button
func get_selected_area_name() -> String:
	return areas_option_button.get_item_text(areas_option_button.selected)


# Function to process brushes and generate area data
func generate_area_data() -> Dictionary:
	# Get all brushes from the brush container
	var brushes = get_all_brushes()
	
	# Return if the brush list is empty
	if brushes.is_empty():
		return {}
	
	# Initialize the default area data
	var area_data: Dictionary = {
		"id": "area1",
		"tiles": [],
		"entities": [],
		"rotate_random": false,
		"spawn_chance": 100
	}
	
	# Loop over each brush and sort by entityType
	for brush in brushes:
		var entity_type: String = brush.entityType
		var entity_id: String = brush.entityID
		var entity_data = {"id": entity_id, "count": 1, "type": entity_type}
		
		# Only add the entities once and do not add duplicates of the same id
		match entity_type:
			"tile":
				add_entity_to_area(area_data["tiles"], entity_data)
			_:
				add_entity_to_area(area_data["entities"], entity_data)
	
	# Check if a area name is selected
	var selected_area_name: String = get_selected_area_name()
	if selected_area_name == "None":
		var new_id: String = generate_unique_area_id()
		area_data["id"] = new_id
		areas_option_button.add_item(new_id)  # Ensure the new ID is added to the areas_option_button
		areas_option_button.select(areas_option_button.get_item_count() - 1)  # Select the newly added item
	else: # One of the areas is already selected
		area_data["id"] = selected_area_name
	
	# Set rotate_random if the rotation button is pressed
	area_data["rotate_random"] = rotation_button.button_pressed
	
	return area_data


# Function to check if entity ID already exists in the array
func entity_exists_in_array(array: Array, entity_id: String) -> bool:
	for entity in array:
		if entity["id"] == entity_id:
			return true
	return false


# Function to generate a unique area ID not present in the areas_option_button
func generate_unique_area_id() -> String:
	var existing_ids = []
	for i in range(areas_option_button.get_item_count()):
		existing_ids.append(areas_option_button.get_item_text(i))

	var new_id: String
	while true:
		new_id = "area" + str(Time.get_ticks_msec())
		if not new_id in existing_ids:
			break

	return new_id


# The user presses the button that will show the area editor popup
func _on_map_area_settings_button_button_up():
	area_editor.populate_area_list(gridContainer.get_map_areas())
	area_editor.show()


# When the user selects one of the areas in the area option button
func _on_areas_option_button_item_selected(index):
	# Let the gridcontainer handle the selection as well
	gridContainer.on_areas_option_button_item_selected(areas_option_button, index)
	
	# Refresh the brush container based on the selected area
	refresh_brush_container_from_selected_area()

# Function to refresh the brush container based on the selected area
func refresh_brush_container_from_selected_area():
	var selected_area_name = get_selected_area_name()
	
	# If the selected area is "None", clear the brush container and return
	if selected_area_name == "None":
		clear_brush_container()
		return
		
	# Find the selected area data in map_areas
	var selected_area_data = get_selected_area_data(selected_area_name)
	if selected_area_data.is_empty():
		print_debug("Selected area not found in mapData.")
		return
	
	# Clear all the brushes from the brush_container
	clear_brush_container()
	
	# Add brushes from the selected area data to the brush_container
	var tilesdata: Array = selected_area_data["tiles"]
	add_brushes_from_area(tilesdata, "tile")
	var entitiesdata: Array = selected_area_data["entities"]
	add_brushes_from_area(entitiesdata)

# Function to get the selected area data
func get_selected_area_data(selected_area_name: String) -> Dictionary:
	var map_areas = gridContainer.get_map_areas()
	for area in map_areas:
		if area["id"] == selected_area_name:
			return area
	return {}

# Function to add tile brushes to the container based on entity type
func add_brushes_from_area(entity_list: Array, entity_type: String = "entity"):
	for entity in entity_list:
		if entity["id"] == "null":
			_on_null_tile_button_up()
			continue
		var properties: Dictionary = {
			"entityID": entity["id"],
			"entityType": entity_type
		}
		var newtype: String = entity.get("type", "tile")
		# Get the appropriate sprite based on the entity type
		match newtype:
			"tile":
				properties["texture"] = Gamedata.mods.by_id("Core").tiles.sprite_by_id(entity["id"])
			"mob":
				properties["texture"] = Gamedata.mods.get_content_by_id(DMod.ContentType.MOBS,entity["id"]).sprite
			"furniture":
				properties["texture"] = Gamedata.furnitures.sprite_by_id(entity["id"])
			"itemgroup":
				properties["texture"] = Gamedata.itemgroups.sprite_by_id(entity["id"])
			"mobgroup":  # Add support for mobgroup
				properties["texture"] = Gamedata.mobgroups.sprite_by_id(entity["id"])  # Ensure mobgroup textures exist
			_:
				continue  # Skip unsupported entity types

		add_tilebrush_to_container_with_properties(properties)


# The user has selected OK in the areas editor popup menu.
# We now receive a modified areas list that we have to send back to the GridContainer.
func _on_area_editor_area_selected_ok(areas_clone: Array):
	set_area_data(areas_clone)

# Provide an array of area objects and it will be loaded into the brushcomposer
func set_area_data(areas_clone: Array):
	# Remember the selected area ID from the areas_option_button.
	var selected_area_id = get_selected_area_name()
	
	# Update the map areas in gridContainer with the areas_clone data.
	gridContainer.update_map_areas(areas_clone)
	
	# Clear the current items in the areas_option_button.
	areas_option_button.clear()
	
	# Add the "None" option as the first item.
	areas_option_button.add_item("None")
	
	# Get the list of all area IDs from the areas_clone list.
	var area_ids = areas_clone.map(func(area): return area["id"])
	
	# Add each area ID to the areas_option_button.
	for area_id in area_ids:
		areas_option_button.add_item(area_id)
	
	# Re-select the previously selected area if it's still present.
	if selected_area_id in area_ids:
		for i in range(areas_option_button.get_item_count()):
			if areas_option_button.get_item_text(i) == selected_area_id:
				areas_option_button.select(i)
				
				# Collect data for the selected area from areas_clone.
				var area_data = areas_clone.filter(func(area): return area["id"] == selected_area_id)[0]
				
				# Check the area_data["rotate_random"] property and set the rotation button accordingly.
				rotation_button.button_pressed = area_data["rotate_random"]
				break
	else:
		# If the previously selected area is not present, select "None".
		areas_option_button.select(0)
		clear_brush_container()
		
	# Refresh the brush container based on the selected area
	refresh_brush_container_from_selected_area()


# Function to be called when the null tile button is pressed
func _on_null_tile_button_up():
	var null_tile_properties = {
		"texture": load("res://Scenes/ContentManager/Mapeditor/Images/nulltile_32.png"),
		"entityID": "null",
		"entityType": "tile"
	}
	add_tilebrush_to_container_with_properties(null_tile_properties)
