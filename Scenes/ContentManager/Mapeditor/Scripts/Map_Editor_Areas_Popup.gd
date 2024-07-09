extends Popup

# This script works with the Map_Editor_areas_Popup.tscn
# It allows users to edit areas in the mapeditor
# areas are areas on the map grid that facilitate random spawning during runtime

@export var area_list: ItemList
@export var spawn_chance_spin_box: SpinBox
@export var entities_v_box_container: VBoxContainer
@export var random_rotation_check_box: CheckBox

# Variable to keep track of the currently selected area
var current_selected_area_id: String = ""
var areas_clone: Array = []
# Potential area data:
# {
#     "id": "area1",
#     "tiles": [{"id": entity_id, "count": 1}],
#     "entities": [{"id": entity_id, "type": entity_type, "count": 1}],
#     "rotate_random": false,
#     "spawn_chance": 100
# }

# Will be sent when the user pressed OK
signal area_selected_ok(areas_clone: Array)

# Called when the node enters the scene tree for the first time.
func _ready():
	pass  # Replace with function body.

# Called after the user presses OK
func _on_ok_button_up():
	_save_current_area_data()
	area_selected_ok.emit(areas_clone.duplicate())
	areas_clone = []
	hide()

# Called after the users presses cancel on the popup
func _on_cancel_button_up():
	areas_clone = []
	hide()

# The user presses the move up button.
# We will move the area up in the areaList
func _on_move_up_button_button_up():
	var selected_index = area_list.get_selected_items()[0]
	if selected_index > 0:
		# Swap the areas in areas_clone
		var temp = areas_clone[selected_index]
		areas_clone[selected_index] = areas_clone[selected_index - 1]
		areas_clone[selected_index - 1] = temp
		
		# Swap the items in area_list
		var selected_item = area_list.get_item_text(selected_index)
		var above_item = area_list.get_item_text(selected_index - 1)
		area_list.set_item_text(selected_index - 1, selected_item)
		area_list.set_item_text(selected_index, above_item)
		
		# Update the selected index
		area_list.select(selected_index - 1)
		current_selected_area_id = area_list.get_item_text(selected_index - 1)

# The user presses the move down button.
# We will move the area down in the areaList
func _on_move_down_button_button_up():
	var selected_index = area_list.get_selected_items()[0]
	if selected_index < area_list.get_item_count() - 1:
		# Swap the areas in areas_clone
		var temp = areas_clone[selected_index]
		areas_clone[selected_index] = areas_clone[selected_index + 1]
		areas_clone[selected_index + 1] = temp
		
		# Swap the items in area_list
		var selected_item = area_list.get_item_text(selected_index)
		var below_item = area_list.get_item_text(selected_index + 1)
		area_list.set_item_text(selected_index + 1, selected_item)
		area_list.set_item_text(selected_index, below_item)
		
		# Update the selected index
		area_list.select(selected_index + 1)
		current_selected_area_id = area_list.get_item_text(selected_index + 1)

# The user presses the delete button
# We delete the area from the area list
func _on_delete_button_button_up():
	var selected_index = area_list.get_selected_items()[0]
	if selected_index != -1:
		# Remove the selected area from areas_clone
		areas_clone.remove_at(selected_index)
		
		# Remove the selected item from area_list
		area_list.remove_item(selected_index)
		
		# Reset the form controls
		current_selected_area_id = ""
		random_rotation_check_box.button_pressed = false
		spawn_chance_spin_box.value = 0
		for child in entities_v_box_container.get_children():
			child.queue_free()


# Function to populate the area_list with the IDs of areas from an array of dictionaries
func populate_area_list(areas: Array) -> void:
	areas_clone = areas.duplicate()
	area_list.clear()  # Clear the existing items in the area list

	# Loop over each area dictionary in the array
	for area in areas:
		if area.has("id"):
			area_list.add_item(area["id"])  # Add the area ID to the area list


# Function to update the UI based on the selected area
# Makes a list of tiles, furniture, mobs and itemgroups in this area
# Also displays controls for setting the count and deleting it from the area
func _update_area_ui(area_id: String):
	# Clear all children of entities_v_box_container
	for child in entities_v_box_container.get_children():
		child.queue_free()

	# Find the selected area in areas_clone
	var selected_area = null
	for area in areas_clone:
		if area["id"] == area_id:
			selected_area = area
			break

	if selected_area:
		# Update random_rotation_check_box
		random_rotation_check_box.button_pressed = selected_area["rotate_random"]

		# Update spawn_chance_spin_box
		spawn_chance_spin_box.value = selected_area["spawn_chance"]

		# Loop over tiles and add UI elements
		for tile in selected_area["tiles"]:
			# Create and add the HBoxContainer for the tile
			var hbox = create_entity_hbox(tile, "tile")
			entities_v_box_container.add_child(hbox)

		# Loop over entities and add UI elements
		for entity in selected_area["entities"]:
			# Create and add the HBoxContainer for the entity
			var hbox = create_entity_hbox(entity, entity["type"])
			entities_v_box_container.add_child(hbox)


# Function to create an HBoxContainer for an entity or tile
# This function creates a label, spinbox, and delete button for the entity/tile and returns the HBoxContainer
func create_entity_hbox(entity: Dictionary, entity_type: String) -> HBoxContainer:
	# Create a new HBoxContainer
	var hbox = HBoxContainer.new()
	hbox.set_meta("entity_type", entity_type)  # Store the entity type in metadata

	# Create a label with the entity id
	var label = Label.new()
	label.text = entity["id"]
	hbox.add_child(label)

	# Create a spinbox with the entity count
	var spinbox = SpinBox.new()
	spinbox.min_value = 1
	spinbox.max_value = 10000  # Set an appropriate max value
	spinbox.value = entity["count"]
	hbox.add_child(spinbox)

	# Create a delete button
	var delete_button = Button.new()
	delete_button.text = "X"
	delete_button.pressed.connect(_on_delete_entity_button_pressed.bind(hbox))
	hbox.add_child(delete_button)

	return hbox


# Function to handle deleting an entity from the list
func _on_delete_entity_button_pressed(hbox):
	entities_v_box_container.remove_child(hbox)
	hbox.queue_free()


# When the user presses the random rotation checkbox
func _on_random_rotation_check_box_button_up():
	pass  # Replace with function body.


# An item has been selected from the list
func _on_area_list_item_selected(index):
	# Get the ID of the selected area
	var selected_area_id = area_list.get_item_text(index)
	
	# Check if another area is selected and the form is populated
	if current_selected_area_id != "":
		_save_current_area_data()

	# Update the current selected area ID
	current_selected_area_id = selected_area_id
	
	# Update the UI with the new area's data
	_update_area_ui(selected_area_id)

# Function to save the current area's data to areas_clone
func _save_current_area_data():
	# Find the current selected area in areas_clone
	for area in areas_clone:
		if area["id"] == current_selected_area_id:
			# Update the area's data
			area["rotate_random"] = random_rotation_check_box.button_pressed
			area["spawn_chance"] = spawn_chance_spin_box.value

			# Clear the existing data
			area["tiles"].clear()
			area["entities"].clear()

			# Update tiles and entities data
			for hbox in entities_v_box_container.get_children():
				var label = hbox.get_child(0) as Label
				var spinbox = hbox.get_child(1) as SpinBox
				var entity_type = hbox.get_meta("entity_type") as String  # Retrieve the entity type from metadata
				
				var entity_data = {"id": label.text, "count": spinbox.value}

				if entity_type == "tile":
					area["tiles"].append(entity_data)
				else:
					entity_data["type"] = entity_type
					area["entities"].append(entity_data)
			break

