extends Popup

# This script works with the Map_Editor_areas_Popup.tscn
# It allows users to edit areas in the mapeditor
# areas are areas on the map grid that facilitate random spawning during runtime

@export var area_list: ItemList
@export var spawn_chance_spin_box: SpinBox
@export var entities_grid_container: GridContainer
@export var random_rotation_check_box: CheckBox
@export var pick_one_check_box: CheckBox
@export var controls_h_box: HBoxContainer
@export var id_text_edit: TextEdit
@export var areas_option_button: OptionButton
@export var chance_modification_list: VBoxContainer


# Variable to keep track of the currently selected area
var current_selected_area_id: String = ""
var areas_clone: Array = []
# Potential area data:
# {
#     "id": "area1",
#     "tiles": [{"id": entity_id, "count": 1}],
#     "entities": [{"id": entity_id, "type": entity_type, "count": 1}],
#     "rotate_random": false,
#     "pick_one": false,
#     "spawn_chance": 100
#     "chance_modifications": [{"id": area_id, "chance": -100}]
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
	current_selected_area_id = ""
	hide()


# Called after the users presses cancel on the popup
func _on_cancel_button_up():
	areas_clone = []
	current_selected_area_id = ""
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
		pick_one_check_box.button_pressed = false
		spawn_chance_spin_box.value = 0
		for child in entities_grid_container.get_children():
			child.queue_free()
		controls_h_box.visible = false  # Hide controls when the last item is deleted


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
	# Clear all children of entities_grid_container
	for child in entities_grid_container.get_children():
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
		if selected_area.has("pick_one"):
			pick_one_check_box.button_pressed = selected_area["pick_one"]

		# Update spawn_chance_spin_box
		spawn_chance_spin_box.value = selected_area["spawn_chance"]

		# Update id_text_edit
		id_text_edit.text = selected_area["id"]

		# Loop over tiles and add UI elements
		for tile in selected_area["tiles"]:
			create_entity_controls(tile, "tile")

		# Loop over entities and add UI elements
		for entity in selected_area["entities"]:
			create_entity_controls(entity, entity["type"])

		# Load the chance_modification list
		for child in chance_modification_list.get_children():
			child.queue_free()
		if selected_area.has("chance_modification"):
			for chance_modification in selected_area["chance_modification"]:
				create_chance_mod_hbox(chance_modification.id, chance_modification.chance)

		# Call the new function to populate areas_option_button
		populate_areas_option_button(area_id)


# Function to create and add entity controls to the grid container
func create_entity_controls(entity: Dictionary, entity_type: String):
	# Create a label with the entity id
	var label = Label.new()
	label.text = entity["id"]
	entities_grid_container.add_child(label)

	# Create a spinbox with the entity count
	var spinbox = SpinBox.new()
	spinbox.min_value = 1
	spinbox.max_value = 10000  # Set an appropriate max value
	spinbox.tooltip_text = "The proportion of tiles this area will generate in this \n" + \
							"area. Imagine each tile having a count of 1 and being \n" + \
							"added to a list. The generator will then pick 1 of them \n" + \
							"in equal proportion. If you give a tile a count of 100, \n" + \
							"it will be as though that tile appears in the list 100 times, \n" + \
							"while the rest only appears once. When picking a random tile \n" + \
							"from the list, the one with 100 is more likely to be picked."
	spinbox.value = entity["count"]
	spinbox.update_on_text_changed = true
	entities_grid_container.add_child(spinbox)

	# Create a delete button
	var delete_button = Button.new()
	delete_button.text = "X"
	delete_button.pressed.connect(_on_delete_entity_button_pressed.bind(delete_button))
	delete_button.set_meta("entity_type", entity_type)  # Store the entity type in metadata
	entities_grid_container.add_child(delete_button)


# Function to populate areas_option_button with the IDs of areas in areas_clone
# chance_modification the currently selected area and always adds "Select area..." as the first option
func populate_areas_option_button(area_id: String):
	areas_option_button.clear()
	areas_option_button.add_item("Select area...")

	# Collect chance_modificationd area IDs into a set for quick lookup
	var chance_modificationd_ids = get_chance_modifications().map(func(area): return area["id"])

	for area in areas_clone:
		if area["id"] != area_id and area["id"] not in chance_modificationd_ids:
			areas_option_button.add_item(area["id"])


# Function to handle deleting an entity from the list
func _on_delete_entity_button_pressed(control):
	var index = entities_grid_container.get_children().find(control)
	for i in range(3):
		entities_grid_container.remove_child(entities_grid_container.get_child(index - (index % 3)))
	control.queue_free()


# When the user presses the random rotation checkbox
func _on_random_rotation_check_box_button_up():
	pass  # Replace with function body.


# An item has been selected from the list, so we update the UI
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
	controls_h_box.visible = true  # Ensure controls are visible when an item is selected



# Function to save the current area's data to areas_clone
func _save_current_area_data():
	# Find the current selected area in areas_clone
	for area in areas_clone:
		if area["id"] == current_selected_area_id:
			# Update the area's data
			area["rotate_random"] = random_rotation_check_box.button_pressed
			area["pick_one"] = pick_one_check_box.button_pressed
			area["spawn_chance"] = spawn_chance_spin_box.value
			var newid: String = id_text_edit.text

			if area["id"] != newid:
				# Only set previd if it hasn't been set already
				if not area.has("previd"):
					area["previd"] = area["id"]  # Save the previous ID

				# Find the item in area_list with the old area ID and update it
				for i in range(area_list.get_item_count()):
					if area_list.get_item_text(i) == area["id"]:
						area_list.set_item_text(i, newid)
						break
			
			# Save the new ID
			area["id"] = newid

			# Clear and update other area properties (tiles, entities, etc.)
			area["tiles"].clear()
			area["entities"].clear()

			# Update tiles and entities data
			var children = entities_grid_container.get_children()
			for i in range(0, children.size(), 3):
				var label = children[i] as Label
				var spinbox = children[i + 1] as SpinBox
				var entity_type = children[i + 2].get_meta("entity_type") as String

				var entity_data = {"id": label.text, "count": spinbox.value}

				if entity_type == "tile":
					area["tiles"].append(entity_data)
				else:
					entity_data["type"] = entity_type
					area["entities"].append(entity_data)

			# Update chance_modifications using get_chance_modifications
			var chance_modifications = get_chance_modifications()
			if chance_modifications.size() > 0:
				area["chance_modifications"] = chance_modifications
			else:
				if area.has("chance_modifications"):
					area.erase("chance_modifications")

			break


# When the user selects an item from the area option button
func _on_areas_option_button_item_selected(index):
	# Get the selected area ID
	var selected_area_id = areas_option_button.get_item_text(index)
	if selected_area_id == "Select area...":
		return  # Exit the function if "Select area..." is selected.
	else:
		# Remove the selected option from the areas_option_button
		areas_option_button.remove_item(index)
		areas_option_button.select(0)
		
		# Add the selected area ID to the chance_modification_item_list
		create_chance_mod_hbox(selected_area_id, -100)


# Function to return the selected value from areas_option_button
func get_selected_area_option() -> String:
	return areas_option_button.get_item_text(areas_option_button.selected)


# Function to create an HBoxContainer for the chance modification list
# This function creates a label, spinbox, and delete button for the area and returns the HBoxContainer
func create_chance_mod_hbox(area_id: String, spawn_chance: int) -> HBoxContainer:
	# Create a new HBoxContainer
	var hbox = HBoxContainer.new()
	
	# Create a label with the area id
	var label = Label.new()
	label.text = area_id
	hbox.add_child(label)
	
	# Create a spinbox for the spawn chance
	var spinbox = SpinBox.new()
	spinbox.min_value = -100
	spinbox.max_value = 100
	spinbox.tooltip_text = "When this area gets picked, the spawn chance of the \n" + area_id + \
							" area will be modified by the amount you enter here. Can \n" + \
							"be a number between -100 and 100. Use this to control \n" + \
							"the odds of other areas that may overlap this one. For \n" + \
							"example, if your area contains some items, you may want \n" + \
							"to lower the chance of an overlapping area that also produces \n" + \
							"items. Setting it to -100 will exclude the \n" + area_id + \
							" area entirely from spawning if this area is picked."
	spinbox.value = spawn_chance
	spinbox.update_on_text_changed = true
	hbox.add_child(spinbox)
	
	# Create a delete button
	var delete_button = Button.new()
	delete_button.text = "X"
	delete_button.button_up.connect(_on_delete_chance_mod_button_pressed.bind(hbox))
	hbox.add_child(delete_button)
	
	chance_modification_list.add_child(hbox)
	return hbox


# Function to handle deleting a chance modification from the list
func _on_delete_chance_mod_button_pressed(hbox):
	# Add the selected item to the areas_option_button
	areas_option_button.add_item(hbox.get_child(0).text)
	chance_modification_list.remove_child(hbox)
	hbox.queue_free()


# Function to create an array of objects with "id" and "chance" properties from chance_modification_list children
func get_chance_modifications() -> Array:
	var chance_modifications = []
	for child in chance_modification_list.get_children():
		var id = child.get_child(0).text  # Assuming the first child is the label with the ID
		var chance = child.get_child(1).value  # Assuming the second child is the spinbox with the chance value
		chance_modifications.append({"id": id, "chance": chance})
	return chance_modifications


func _on_visibility_changed():
	if visible:
		_update_area_ui(current_selected_area_id)


# When the user release the mouse press on the checkbox
func _on_pick_one_check_box_button_up() -> void:
	pass # Replace with function body.
