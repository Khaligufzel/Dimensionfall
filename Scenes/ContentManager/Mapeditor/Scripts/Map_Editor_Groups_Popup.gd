extends Popup

# This script works with the Map_Editor_Groups_Popup.tscn
# It allows users to edit groups in the mapeditor
# Groups are areas on the map grid that facilitate random spawning during runtime

@export var group_list: ItemList
@export var spawn_chance_spin_box: SpinBox
@export var entities_v_box_container: VBoxContainer
@export var random_rotation_check_box: CheckBox


# Variable to keep track of the currently selected group
var current_selected_group_id: String = ""
var groups_clone: Array = []
# Potential group data:
# {
#     "id": "group1",
#     "tiles": [{"id": entity_id, "count": 1}],
#     "furniture": [{"id": entity_id, "count": 1}],
#     "mobs": [{"id": entity_id, "count": 1}],
#     "itemgroups": [{"id": entity_id, "count": 1}],
#     "rotate_random": false,
#     "spawn_chance": 100
# }

#Will be sent when the user pressed OK
signal group_selected_ok(groups_clone: Array)

# Called when the node enters the scene tree for the first time.
func _ready():
	pass  # Replace with function body.


# Called after the user presses OK
func _on_ok_button_up():
	_save_current_group_data()
	group_selected_ok.emit(groups_clone.duplicate())
	groups_clone = []
	hide()


# Called after the users presses cancel on the popup
func _on_cancel_button_up():
	groups_clone = []
	hide()


# The user presses the move up button.
# We will move the group up in the GroupList
func _on_move_up_button_button_up():
	var selected_index = group_list.get_selected_items()[0]
	if selected_index > 0:
		# Swap the groups in groups_clone
		var temp = groups_clone[selected_index]
		groups_clone[selected_index] = groups_clone[selected_index - 1]
		groups_clone[selected_index - 1] = temp
		
		# Swap the items in group_list
		var selected_item = group_list.get_item_text(selected_index)
		var above_item = group_list.get_item_text(selected_index - 1)
		group_list.set_item_text(selected_index - 1, selected_item)
		group_list.set_item_text(selected_index, above_item)
		
		# Update the selected index
		group_list.select(selected_index - 1)
		current_selected_group_id = group_list.get_item_text(selected_index - 1)


# The user presses the move down button.
# We will move the group down in the GroupList
func _on_move_down_button_button_up():
	var selected_index = group_list.get_selected_items()[0]
	if selected_index < group_list.get_item_count() - 1:
		# Swap the groups in groups_clone
		var temp = groups_clone[selected_index]
		groups_clone[selected_index] = groups_clone[selected_index + 1]
		groups_clone[selected_index + 1] = temp
		
		# Swap the items in group_list
		var selected_item = group_list.get_item_text(selected_index)
		var below_item = group_list.get_item_text(selected_index + 1)
		group_list.set_item_text(selected_index + 1, selected_item)
		group_list.set_item_text(selected_index, below_item)
		
		# Update the selected index
		group_list.select(selected_index + 1)
		current_selected_group_id = group_list.get_item_text(selected_index + 1)


# The user presses the delete button
# We delete the group from the group list
func _on_delete_button_button_up():
	var selected_index = group_list.get_selected_items()[0]
	if selected_index != -1:
		# Remove the selected group from groups_clone
		groups_clone.remove_at(selected_index)
		
		# Remove the selected item from group_list
		group_list.remove_item(selected_index)
		
		# Reset the form controls
		current_selected_group_id = ""
		random_rotation_check_box.button_pressed = false
		spawn_chance_spin_box.value = 0
		for child in entities_v_box_container.get_children():
			child.queue_free()


# Function to populate the group_list with the IDs of groups from an array of dictionaries
func populate_group_list(groups: Array) -> void:
	groups_clone = groups.duplicate()
	group_list.clear()  # Clear the existing items in the group list

	# Loop over each group dictionary in the array
	for group in groups:
		if group.has("id"):
			group_list.add_item(group["id"])  # Add the group ID to the group list


# Function to update the UI based on the selected group
func _update_group_ui(group_id: String):
	# Clear all children of entities_v_box_container
	for child in entities_v_box_container.get_children():
		child.queue_free()

	# Find the selected group in groups_clone
	var selected_group = null
	for group in groups_clone:
		if group["id"] == group_id:
			selected_group = group
			break

	if selected_group:
		# Update random_rotation_check_box
		random_rotation_check_box.button_pressed = selected_group["rotate_random"]

		# Update spawn_chance_spin_box
		spawn_chance_spin_box.value = selected_group["spawn_chance"]

		# Loop over entity types and add UI elements
		var entity_types = ["tiles", "furniture", "mobs", "itemgroups"]
		for entity_type in entity_types:
			for entity in selected_group[entity_type]:
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

				# Add the HBoxContainer to entities_v_box_container
				entities_v_box_container.add_child(hbox)



# Function to handle deleting an entity from the list
func _on_delete_entity_button_pressed(hbox):
	entities_v_box_container.remove_child(hbox)
	hbox.queue_free()


# When the user presses the random rotation checkbox
func _on_random_rotation_check_box_button_up():
	pass # Replace with function body.


# An item has been selected from the list
func _on_group_list_item_selected(index):
	# Get the ID of the selected group
	var selected_group_id = group_list.get_item_text(index)
	
	# Check if another group is selected and the form is populated
	if current_selected_group_id != "":
		_save_current_group_data()

	# Update the current selected group ID
	current_selected_group_id = selected_group_id
	
	# Update the UI with the new group's data
	_update_group_ui(selected_group_id)


# Function to save the current group's data to groups_clone
func _save_current_group_data():
	# Find the current selected group in groups_clone
	for group in groups_clone:
		if group["id"] == current_selected_group_id:
			# Update the group's data
			group["rotate_random"] = random_rotation_check_box.button_pressed
			group["spawn_chance"] = spawn_chance_spin_box.value

			# Update entities data
			var entity_types = ["tiles", "furniture", "mobs", "itemgroups"]
			for entity_type in entity_types:
				group[entity_type].clear()
			for hbox in entities_v_box_container.get_children():
				var label = hbox.get_child(0) as Label
				var spinbox = hbox.get_child(1) as SpinBox
				var entity_type = hbox.get_meta("entity_type") as String  # Retrieve the entity type from metadata
				group[entity_type].append({"id": label.text, "count": spinbox.value})
			break
