extends Control

# This scene is intended to be used inside the content editor
# It is supposed to edit exactly one Attack
# It expects to save the data to a JSON file
# To load data, provide the name of the attack data file and an ID


@export var type_option_button: OptionButton = null # Allows selecting "melee" or "ranged"
@export var image_label: Label = null # The label in front of the sprite display
@export var attackImageDisplay: TextureRect = null # The sprite for the projectile
@export var path_label: Label = null # Label in front of the path text label
@export var PathTextLabel: Label = null # shows the path to the sprite
@export var IDTextLabel: Label = null # Shows the id of this attack
@export var NameTextEdit: TextEdit = null # Shows the name of this attack
@export var DescriptionTextEdit: TextEdit = null
@export var attackSelector: Popup = null # Allows the user to select a sprite from a popup

@export var stats_range_spinbox: SpinBox = null
@export var stats_cooldown_spinbox: SpinBox = null
@export var stats_knockback_spinbox: SpinBox = null
@export var stats_projectile_speed_label: Label = null
@export var stats_projectile_speed_spinbox: SpinBox = null

@export var any_of_attributes_grid_container: GridContainer = null
@export var all_of_attributes_grid_container: GridContainer = null

# This signal will be emitted when the user presses the save button
# This signal should alert Gamedata that the attack data array should be saved to disk
signal data_changed()

var olddata: DAttack # Remember what the value of the data was before editing

# The data that represents this attack
# The data is selected from the Gamedata.mods.by_id("Core").attacks
# based on the ID that the user has selected in the content editor
var dattack: DAttack = null:
	set(value):
		dattack = value
		load_attack_data()
		attackSelector.sprites_collection = dattack.parent.sprites
		olddata = DAttack.new(dattack.get_data().duplicate(true), dattack.parent)

# Forward drag-and-drop functionality to the attributesGridContainer
func _ready() -> void:
	any_of_attributes_grid_container.set_drag_forwarding(Callable(), _can_drop_attribute_data, _drop_any_of_attribute_data)
	all_of_attributes_grid_container.set_drag_forwarding(Callable(), _can_drop_attribute_data, _drop_all_of_attribute_data)

	# Connect the selection change signal to a new function
	if type_option_button:
		type_option_button.item_selected.connect(_on_type_option_button_selected)

# This function updates the form based on the DAttack that has been loaded
func load_attack_data() -> void:
	# Set the type_option_button selection based on dattack.type
	if type_option_button:
		for i in range(type_option_button.item_count):
			if type_option_button.get_item_text(i) == dattack.type:
				type_option_button.select(i)
				break

	if attackImageDisplay != null and dattack.spriteid != "":
		attackImageDisplay.texture = dattack.sprite
		PathTextLabel.text = dattack.spriteid
	if IDTextLabel != null:
		IDTextLabel.text = str(dattack.id)
	if NameTextEdit != null:
		NameTextEdit.text = dattack.name
	if DescriptionTextEdit != null:
		DescriptionTextEdit.text = dattack.description
	if stats_range_spinbox != null:
		stats_range_spinbox.value = dattack.range
	if stats_cooldown_spinbox != null:
		stats_cooldown_spinbox.value = dattack.cooldown
	if stats_knockback_spinbox != null:
		stats_knockback_spinbox.value = dattack.knockback
	if stats_projectile_speed_spinbox != null:
		stats_projectile_speed_spinbox.value = dattack.projectile_speed if dattack.type == "ranged" else 0.0
	
	# Load 'any_of' and 'all_of' attributes into their respective grids
	if dattack.targetattributes.has("any_of"):
		_load_attributes_into_grid(any_of_attributes_grid_container, dattack.targetattributes["any_of"])
	if dattack.targetattributes.has("all_of"):
		_load_attributes_into_grid(all_of_attributes_grid_container, dattack.targetattributes["all_of"])
	_toggle_ranged_controls(dattack.type == "ranged")  # Update UI based on type

# The editor is closed, destroy the instance
# TODO: Check for unsaved changes
func _on_close_button_button_up() -> void:
	queue_free()

# This function takes all data from the form elements and stores them in the DAttack instance
# Since dattack is a reference to an item in Gamedata.mods.by_id("Core").attacks
# the central array for attack data is updated with the changes as well
# The function will signal to Gamedata that the data has changed and needs to be saved
func _on_save_button_button_up() -> void:
	# Get the selected attack type from type_option_button and save it
	if type_option_button:
		dattack.type = type_option_button.get_item_text(type_option_button.selected)

	dattack.spriteid = PathTextLabel.text
	dattack.name = NameTextEdit.text
	dattack.description = DescriptionTextEdit.text
	dattack.sprite = attackImageDisplay.texture
	dattack.range = stats_range_spinbox.value
	dattack.cooldown = stats_cooldown_spinbox.value
	dattack.knockback = stats_knockback_spinbox.value
	dattack.projectile_speed = stats_projectile_speed_spinbox.value if dattack.type == "ranged" else 0.0  # Only save for ranged attacks

	dattack.targetattributes = _get_attributes_from_ui()
	dattack.save_to_disk()
	data_changed.emit()
	olddata = DAttack.new(dattack.get_data().duplicate(true), dattack.parent)

# When the attackImageDisplay is clicked, the user will be prompted to select an image from 
# "res://Mods/Core/Attacks/". The texture of the attackImageDisplay will change to the selected image
func _on_stat_image_display_gui_input(event) -> void:
	if event is InputEventMouseButton and event.pressed:
		attackSelector.show()

func _on_sprite_selector_sprite_selected_ok(clicked_sprite) -> void:
	var attackTexture: Resource = clicked_sprite.get_texture()
	attackImageDisplay.texture = attackTexture
	PathTextLabel.text = attackTexture.resource_path.get_file()


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
	var myattribute: DPlayerAttribute = Gamedata.mods.get_content_by_id(DMod.ContentType.PLAYERATTRIBUTES, attribute.id)

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
# We are expecting a dictionary like this:
#	{
#		"id": selected_item_id,
#		"text": selected_item_text,
#		"mod_id": mod_id,
#		"contentType": contentType
#	}
func _can_drop_attribute_data(_newpos, data) -> bool:
	# Check if the data dictionary has the 'id' property
	if not data or not data.has("id"):
		return false

	# Fetch attribute by ID from the Gamedata to ensure it exists and is valid
	if not Gamedata.mods.by_id(data["mod_id"]).playerattributes.has_id(data["id"]):
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
		if not Gamedata.mods.by_id(dropped_data["mod_id"]).playerattributes.has_id(attribute_id):
			print_debug("No attribute data found for ID: " + attribute_id)
			return

		# Add the attribute entry to the specified container
		_add_attribute_entry_to_grid(container, {"id": attribute_id})
	else:
		print_debug("Dropped data does not contain an 'id' key.")

# Hide these controls if the type is melee, otherwise show them
func _toggle_ranged_controls(is_ranged: bool) -> void:
	image_label.visible = is_ranged
	attackImageDisplay.visible = is_ranged
	path_label.visible = is_ranged
	PathTextLabel.visible = is_ranged
	stats_projectile_speed_label.visible = is_ranged
	stats_projectile_speed_spinbox.visible = is_ranged

func _on_type_option_button_selected(index: int) -> void:
	var selected_type: String = type_option_button.get_item_text(index)
	_toggle_ranged_controls(selected_type == "ranged")
