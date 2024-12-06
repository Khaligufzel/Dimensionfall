extends Control

# This scene is intended to be used inside the item editor
# It is supposed to edit exactly one type of food

# Form elements
@export var attributesGridContainer: GridContainer = null

var ditem: DItem = null:
	set(value):
		if not value:
			return
		ditem = value
		load_properties()


# Forward drag-and-drop functionality to the attributesGridContainer
func _ready() -> void:
	attributesGridContainer.set_drag_forwarding(Callable(), _can_drop_attribute_data, _drop_attribute_data)

# Save the properties from the UI back to the ditem
func save_properties() -> void:
	if not ditem.food:
		ditem.food = DItem.Food.new({})
	
	# Save attributes
	ditem.food.attributes = _get_attributes_from_ui()


# Load the properties from the ditem into the UI
func load_properties() -> void:
	# Check if ditem.food is not null
	if ditem.food == null:
		print_debug("ditem.food is null, skipping property loading.")
		return
	
	# Load attributes into the UI
	_load_attributes_into_ui(ditem.food.attributes)


# Load attributes into the attributesGridContainer
func _load_attributes_into_ui(attributes: Array) -> void:
	# Clear previous entries
	for child in attributesGridContainer.get_children():
		child.queue_free()
	
	# Populate the container with attributes
	for attribute in attributes:
		_add_attribute_entry(attribute)


# Get the current attributes from the UI
func _get_attributes_from_ui() -> Array:
	var attributes = []
	var children = attributesGridContainer.get_children()
	for i in range(0, children.size(), 3):  # Step by 3 to handle label-spinbox-deleteButton triples
		var label = children[i] as Label
		var spinBox = children[i + 1] as SpinBox
		attributes.append({"id": label.text, "amount": spinBox.value})
	return attributes

# Add a new attribute entry to the attributesGridContainer
func _add_attribute_entry(attribute: Dictionary) -> void:
	var attribute_name = attribute.id
	var amount = attribute.amount
	# Create a Label for the attribute name
	var label = Label.new()
	label.text = attribute_name
	attributesGridContainer.add_child(label)
	
	# Create a SpinBox for the attribute value
	var amountSpinBox = SpinBox.new()
	amountSpinBox.value = amount
	attributesGridContainer.add_child(amountSpinBox)
	
	# Create a Button to delete the attribute entry
	var deleteButton = Button.new()
	deleteButton.text = "X"
	deleteButton.pressed.connect(_delete_attribute_entry.bind([label, amountSpinBox, deleteButton]))
	attributesGridContainer.add_child(deleteButton)

# Delete an attribute entry from the attributesGridContainer
func _delete_attribute_entry(elements_to_remove: Array) -> void:
	for element in elements_to_remove:
		attributesGridContainer.remove_child(element)
		element.queue_free()  # Properly free the node to avoid memory leaks


# Function to determine if the dragged data can be dropped in the attributesGridContainer
func _can_drop_attribute_data(_newpos, data) -> bool:
	# Check if the data dictionary has the 'id' property
	if not data or not data.has("id"):
		return false

	# Fetch attribute by ID from the Gamedata to ensure it exists and is valid
	if not Gamedata.mods.by_id("Core").playerattributes.has_id(data["id"]):
		return false

	# Check if the attribute ID already exists in the attributes grid
	var children = attributesGridContainer.get_children()
	for i in range(0, children.size(), 3):  # Step by 3 to handle label-spinbox-deleteButton triples
		var label = children[i] as Label
		if label.text == data["id"]:
			# Return false if this attribute ID already exists in the attributes grid
			return false

	# If all checks pass, return true
	return true

# Function to handle the data being dropped in the attributesGridContainer
func _drop_attribute_data(newpos, data) -> void:
	if _can_drop_attribute_data(newpos, data):
		_handle_attribute_drop(data, newpos)


# Called when the user has successfully dropped data onto the attributesGridContainer
# We have to check the dropped_data for the id property
func _handle_attribute_drop(dropped_data, _newpos) -> void:
	# dropped_data is a Dictionary that includes an 'id'
	if dropped_data and "id" in dropped_data:
		var attribute_id = dropped_data["id"]
		if not Gamedata.mods.by_id("Core").playerattributes.has_id(attribute_id):
			print_debug("No attribute data found for ID: " + attribute_id)
			return
		
		# Add the attribute entry using the new function
		_add_attribute_entry({"id":attribute_id, "amount":1})
		# Here you would update your data structure if needed, similar to how you did for resources
	else:
		print_debug("Dropped data does not contain an 'id' key.")
