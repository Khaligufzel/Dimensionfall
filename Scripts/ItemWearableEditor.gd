extends Control

# This scene is intended to be used inside the item editor
# It is supposed to edit exactly one type of wearable

# Form elements
@export var slot_drop_enabled_text_edit: HBoxContainer = null
@export var attributtes_grid_container: GridContainer = null

var ditem: DItem = null:
	set(value):
		if not value:
			return
		ditem = value
		load_properties()

func _ready():
	slot_drop_enabled_text_edit.content_types = [DMod.ContentType.WEARABLESLOTS] as Array[DMod.ContentType]
	# Set custom can_drop_func and drop_func for the attributtes_grid_container, use default drag_func
	attributtes_grid_container.set_drag_forwarding(Callable(), can_drop_attribute, attribute_drop)

# Load properties from ditem.wearable and update the UI elements
func load_properties() -> void:
	if not ditem.wearable:
		return
	
	# Update the slot option button based on the slot in ditem.wearable
	if ditem.wearable.slot != "":
		slot_drop_enabled_text_edit.set_text(ditem.wearable.slot)
	
	# Load player attributes into attributtes_grid_container
	for attribute in ditem.wearable.player_attributes:
		add_attribute_entry(attribute["id"], attribute["value"], true)

# Save the selected slot and player attributes back to ditem.wearable
func save_properties() -> void:
	# Save slot from SlotOptionButton
	var slotvalue: String = slot_drop_enabled_text_edit.get_text()
	if not ditem.wearable:
		ditem.wearable = DItem.Wearable.new({"slot": slotvalue})
	else:
		ditem.wearable.slot = slotvalue
	
	# Save player attributes from attributtes_grid_container
	ditem.wearable.player_attributes.clear()
	for i in range(0, attributtes_grid_container.get_child_count(), 3):
		var label = attributtes_grid_container.get_child(i) as Label
		var spinbox = attributtes_grid_container.get_child(i + 1) as SpinBox
		var attribute = {
			"id": label.text,
			"value": spinbox.value
		}
		ditem.wearable.player_attributes.append(attribute)

# Add a new attribute entry to the attributtes_grid_container
func add_attribute_entry(attribute_id: String, value: int = 0, use_loaded_value: bool = false):
	if not Gamedata.mods.by_id("Core").playerattributes.has_id(attribute_id):
		print_debug("Invalid attribute ID: " + attribute_id)
		return

	# Prevent duplicates
	for i in range(0, attributtes_grid_container.get_child_count(), 3):
		var mylabel = attributtes_grid_container.get_child(i) as Label
		if mylabel.text == attribute_id:
			print_debug("Attribute " + attribute_id + " already added.")
			return
	
	# Create UI elements for the attribute
	var label = Label.new()
	label.text = attribute_id
	attributtes_grid_container.add_child(label)

	var value_spinbox = SpinBox.new()
	value_spinbox.min_value = -5000
	value_spinbox.max_value = 5000
	if use_loaded_value:
		value_spinbox.value = value
	attributtes_grid_container.add_child(value_spinbox)

	# Create a delete button to remove the attribute
	var delete_button = Button.new()
	delete_button.text = "X"
	delete_button.pressed.connect(_delete_attribute.bind([label, value_spinbox, delete_button]))
	attributtes_grid_container.add_child(delete_button)

# Function to delete an attribute from the attributtes_grid_container
func _delete_attribute(elements_to_remove: Array) -> void:
	for element in elements_to_remove:
		attributtes_grid_container.remove_child(element)
		element.queue_free()  # Properly free the node to avoid memory leaks

# This function will check if an attribute can be dropped
func can_drop_attribute(_at_position: Vector2, dropped_data: Dictionary) -> bool:
	if not dropped_data or not dropped_data.has("id"):
		return false
	
	# Check if the attribute ID exists in playerattributes
	if not Gamedata.mods.by_id(dropped_data.get("mod_id")).playerattributes.has_id(dropped_data["id"]):
		return false

	# Prevent duplicates in the attributtes_grid_container
	for i in range(0, attributtes_grid_container.get_child_count(), 3):
		var label = attributtes_grid_container.get_child(i) as Label
		if label.text == dropped_data["id"]:
			return false  # Attribute is already present

	return true

# Function to handle dropping an attribute into the attributtes_grid_container
func attribute_drop(at_position: Vector2, dropped_data: Dictionary) -> void:
	if dropped_data and dropped_data.has("id") and can_drop_attribute(at_position, dropped_data):
		add_attribute_entry(dropped_data["id"], 0, false)
	else:
		print_debug("Failed to drop attribute: Invalid or duplicate entry.")
