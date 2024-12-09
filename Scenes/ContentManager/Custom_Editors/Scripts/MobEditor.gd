extends Control

# This scene is intended to be used inside the content editor
# It is supposed to edit exactly one mob (friend and foe)
# It expects to save the data to a DMob instance that contains all data from a mob
# To load data, provide the DMob to edit

@export var mobImageDisplay: TextureRect = null
@export var IDTextLabel: Label = null
@export var PathTextLabel: Label = null
@export var NameTextEdit: TextEdit = null
@export var DescriptionTextEdit: TextEdit = null
@export var mobSelector: Popup = null
@export var melee_range_numedit: SpinBox
@export var melee_cooldown_spinbox: SpinBox = null
@export var melee_knockback_spinbox: SpinBox = null
@export var health_numedit: SpinBox
@export var moveSpeed_numedit: SpinBox
@export var idle_move_speed_numedit: SpinBox
@export var sightRange_numedit: SpinBox
@export var senseRange_numedit: SpinBox
@export var hearingRange_numedit: SpinBox
@export var ItemGroupTextEdit: TextEdit = null
@export var dash_check_box: CheckBox = null
@export var dash_speed_multiplier_spin_box: SpinBox = null
@export var dash_duration_spin_box: SpinBox = null
@export var dash_cooldown_spin_box: SpinBox = null
@export var any_of_attributes_grid_container: GridContainer = null
@export var all_of_attributes_grid_container: GridContainer = null



signal data_changed()
var olddata: DMob # Remember what the value of the data was before editing
# The data that represents this mob
# The data is selected from dmob.parent
# based on the ID that the user has selected in the content editor
var dmob: DMob:
	set(value):
		dmob = value
		load_mob_data()
		mobSelector.sprites_collection = dmob.parent.sprites
		olddata = DMob.new(dmob.get_data().duplicate(true), null)



# Forward drag-and-drop functionality to the attributesGridContainer
func _ready() -> void:
	any_of_attributes_grid_container.set_drag_forwarding(Callable(), _can_drop_attribute_data, _drop_any_of_attribute_data)
	all_of_attributes_grid_container.set_drag_forwarding(Callable(), _can_drop_attribute_data, _drop_all_of_attribute_data)

# This function update the form based on the DMob data that has been loaded
func load_mob_data() -> void:
	if mobImageDisplay != null:
		mobImageDisplay.texture = dmob.sprite
		PathTextLabel.text = dmob.spriteid
	if IDTextLabel != null:
		IDTextLabel.text = str(dmob.id)
	if NameTextEdit != null:
		NameTextEdit.text = dmob.name
	if DescriptionTextEdit != null:
		DescriptionTextEdit.text = dmob.description
	if melee_range_numedit != null:
		melee_range_numedit.value = dmob.melee_range
	if melee_cooldown_spinbox != null:
		melee_cooldown_spinbox.value = dmob.melee_cooldown
	if melee_knockback_spinbox != null:
		melee_knockback_spinbox.value = dmob.melee_knockback
	if health_numedit != null:
		health_numedit.value = dmob.health
	if moveSpeed_numedit != null:
		moveSpeed_numedit.value = dmob.move_speed
	if idle_move_speed_numedit != null:
		idle_move_speed_numedit.value = dmob.idle_move_speed
	if sightRange_numedit != null:
		sightRange_numedit.value = dmob.sight_range
	if senseRange_numedit != null:
		senseRange_numedit.value = dmob.sense_range
	if hearingRange_numedit != null:
		hearingRange_numedit.value = dmob.hearing_range
	if ItemGroupTextEdit != null:
		ItemGroupTextEdit.text = dmob.loot_group

	# Load dash data if available in special_moves
	var dash_data = dmob.special_moves.get("dash", {})
	dash_check_box.set_pressed(not dash_data.is_empty())
	dash_speed_multiplier_spin_box.value = dash_data.get("speed_multiplier", 2)
	dash_duration_spin_box.value = dash_data.get("duration", 0.5)
	dash_cooldown_spin_box.value = dash_data.get("cooldown", 5)
	# Enable or disable dash controls based on checkbox state
	_on_dash_check_box_toggled(dash_check_box.is_pressed())
	
	# Load 'any_of' and 'all_of' attributes into their respective grids
	if dmob.targetattributes.has("any_of"):
		_load_attributes_into_grid(any_of_attributes_grid_container, dmob.targetattributes["any_of"])
	if dmob.targetattributes.has("all_of"):
		_load_attributes_into_grid(all_of_attributes_grid_container, dmob.targetattributes["all_of"])


# The editor is closed, destroy the instance
# TODO: Check for unsaved changes
func _on_close_button_button_up() -> void:
	queue_free()

# This function takes all data from the form elements and stores them in the DMob instance
# The function will signal to Gamedata that the data has changed and needs to be saved
func _on_save_button_button_up() -> void:
	dmob.spriteid = PathTextLabel.text
	dmob.sprite = mobImageDisplay.texture
	dmob.name = NameTextEdit.text
	dmob.description = DescriptionTextEdit.text
	dmob.melee_range = melee_range_numedit.value
	dmob.melee_cooldown = melee_cooldown_spinbox.value
	dmob.melee_knockback = melee_knockback_spinbox.value
	dmob.health = int(health_numedit.value)
	dmob.move_speed = moveSpeed_numedit.value
	dmob.idle_move_speed = idle_move_speed_numedit.value
	dmob.sight_range = int(sightRange_numedit.value)
	dmob.sense_range = int(senseRange_numedit.value)
	dmob.hearing_range = int(hearingRange_numedit.value)
	dmob.loot_group = ItemGroupTextEdit.text if ItemGroupTextEdit.text else ""
	
	# Set dash special move data based on checkbox
	if dash_check_box.button_pressed:
		dmob.special_moves["dash"] = {
			"speed_multiplier": dash_speed_multiplier_spin_box.value,
			"cooldown": dash_cooldown_spin_box.value,
			"duration": dash_duration_spin_box.value
		}
	else:
		dmob.special_moves = {}  # Clear dash if checkbox is unchecked

	# Save attributes
	dmob.targetattributes = _get_attributes_from_ui()

	dmob.changed(olddata)
	data_changed.emit()
	olddata = DMob.new(dmob.get_data().duplicate(true), null)

# When the mobImageDisplay is clicked, the user will be prompted to select an image from 
# "res://Mods/Core/mobs/". The texture of the mobImageDisplay will change to the selected image
func _on_mob_image_display_gui_input(event) -> void:
	if event is InputEventMouseButton and event.pressed:
		mobSelector.show()

func _on_sprite_selector_sprite_selected_ok(clicked_sprite) -> void:
	var mobTexture: Resource = clicked_sprite.get_texture()
	mobImageDisplay.texture = mobTexture
	PathTextLabel.text = mobTexture.resource_path.get_file()

# This function should return true if the dragged data can be dropped here
func _can_drop_data(_newpos, data) -> bool:
	# Check if the data dictionary has the 'id' property
	if not data or not data.has("id"):
		return false
	
	# Fetch itemgroup data by ID from the Gamedata to ensure it exists and is valid
	if not Gamedata.itemgroups.has_id(data["id"]):
		return false

	# If all checks pass, return true
	return true

# This function handles the data being dropped
func _drop_data(newpos, data) -> void:
	if _can_drop_data(newpos, data):
		_handle_item_drop(data, newpos)

# Called when the user has successfully dropped data onto the ItemGroupTextEdit
# We have to check the dropped_data for the id property
func _handle_item_drop(dropped_data, _newpos) -> void:
	# Assuming dropped_data is a Dictionary that includes an 'id'
	if dropped_data and "id" in dropped_data:
		var item_id = dropped_data["id"]
		if not Gamedata.itemgroups.has_id(item_id):
			print_debug("No item data found for ID: " + item_id)
			return
		ItemGroupTextEdit.text = item_id
	else:
		print_debug("Dropped data does not contain an 'id' key.")

func _on_item_group_clear_button_button_up():
	ItemGroupTextEdit.clear()


# Helper function to load attributes into a specified grid container
func _load_attributes_into_grid(container: GridContainer, attributes: Array) -> void:
	# Clear previous entries
	for child in container.get_children():
		child.queue_free()

	# Populate the container with attributes
	for attribute in attributes:
		_add_attribute_entry_to_grid(container, attribute)


# Modified function to add a new attribute entry to a specified grid container
func _add_attribute_entry_to_grid(container: GridContainer, attribute: Dictionary) -> void:
	var myattribute: DPlayerAttribute = Gamedata.mods.by_id("Core").playerattributes.by_id(attribute.id)

	# Create a TextureRect for the sprite
	var texture_rect = TextureRect.new()
	texture_rect.texture = myattribute.sprite
	texture_rect.custom_minimum_size = Vector2(32, 32)  # Ensure the texture is 32x32
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED  # Keep the aspect ratio centered
	container.add_child(texture_rect)

	# Create a Label for the attribute name
	var label = Label.new()
	label.text = myattribute.id
	container.add_child(label)

	# Create a SpinBox for the damage amount
	var spinbox = SpinBox.new()
	spinbox.min_value = -100
	spinbox.max_value = 100
	spinbox.value = attribute.get("damage", 0)  # Default to 0 if not provided
	spinbox.tooltip_text = "The amount of damage this attribute will receive. Use positive \n" + \
							"number to drain the attribute (i.e. damage), use a negative \n" + \
							"number to add to the attribute (ex. poison)"
	container.add_child(spinbox)

	# Create a Button to delete the attribute entry
	var deleteButton = Button.new()
	deleteButton.text = "X"
	deleteButton.pressed.connect(_delete_attribute_entry.bind([texture_rect, label, spinbox, deleteButton]))
	container.add_child(deleteButton)


# Modified function to gather attributes from the UI and structure them as a dictionary
func _get_attributes_from_ui() -> Dictionary:
	var target_attributes: Dictionary = {"any_of": [], "all_of": []}

	# Collect attributes from 'any_of' grid container
	var any_of_children = any_of_attributes_grid_container.get_children()
	for i in range(1, any_of_children.size(), 4):  # Step by 4 to handle sprite-label-spinbox-deleteButton
		var label = any_of_children[i] as Label
		var spinbox = any_of_children[i + 1] as SpinBox
		if label and spinbox:
			target_attributes["any_of"].append({"id": label.text, "damage": spinbox.value})

	# Collect attributes from 'all_of' grid container
	var all_of_children = all_of_attributes_grid_container.get_children()
	for i in range(1, all_of_children.size(), 4):  # Step by 4 to handle sprite-label-spinbox-deleteButton
		var label = all_of_children[i] as Label
		var spinbox = all_of_children[i + 1] as SpinBox
		if label and spinbox:
			target_attributes["all_of"].append({"id": label.text, "damage": spinbox.value})

	return target_attributes



# Delete an attribute entry from a specified grid container
func _delete_attribute_entry(elements_to_remove: Array) -> void:
	var parent_container = elements_to_remove[0].get_parent()  # Get the parent container dynamically
	if parent_container in [any_of_attributes_grid_container, all_of_attributes_grid_container]:
		for element in elements_to_remove:
			parent_container.remove_child(element)
			element.queue_free()  # Properly free the node to avoid memory leaks


# Function to determine if the dragged data can be dropped in the attribute grid container
func _can_drop_attribute_data(_newpos, data) -> bool:
	# Check if the data dictionary has the 'id' property
	if not data or not data.has("id"):
		return false

	# Fetch attribute by ID from the Gamedata to ensure it exists and is valid
	if not Gamedata.mods.by_id("Core").playerattributes.has_id(data["id"]):
		return false

	# Check if the attribute ID already exists in either of the attribute grids
	for grid in [any_of_attributes_grid_container, all_of_attributes_grid_container]:
		var children = grid.get_children()
		for i in range(1, children.size(), 4):  # Step by 3 to handle sprite-label-deleteButton triples
			var label = children[i] as Label
			if label and label.text == data["id"]:
				# Return false if this attribute ID already exists in any of the grids
				return false

	# If all checks pass, return true
	return true


# Function to handle the data being dropped in the any_of_attributes_grid_container
func _drop_any_of_attribute_data(newpos, data) -> void:
	if _can_drop_attribute_data(newpos, data):
		_handle_attribute_drop(data, any_of_attributes_grid_container)


# Function to handle the data being dropped in the all_of_attributes_grid_container
func _drop_all_of_attribute_data(newpos, data) -> void:
	if _can_drop_attribute_data(newpos, data):
		_handle_attribute_drop(data, all_of_attributes_grid_container)


# Called when the user has successfully dropped data onto an attribute grid container
# We have to check the dropped_data for the id property and add it to the appropriate container
func _handle_attribute_drop(dropped_data, container: GridContainer) -> void:
	if dropped_data and "id" in dropped_data:
		var attribute_id = dropped_data["id"]
		if not Gamedata.mods.by_id("Core").playerattributes.has_id(attribute_id):
			print_debug("No attribute data found for ID: " + attribute_id)
			return

		# Add the attribute entry to the specified container
		_add_attribute_entry_to_grid(container, {"id": attribute_id})
	else:
		print_debug("Dropped data does not contain an 'id' key.")


# Toggle the state of dash controls based on dash checkbox status
func _on_dash_check_box_toggled(pressed: bool) -> void:
	dash_speed_multiplier_spin_box.editable = pressed
	dash_duration_spin_box.editable = pressed
	dash_cooldown_spin_box.editable = pressed
