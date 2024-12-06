extends Control

# This scene is intended to be used inside the item editor
# It is supposed to edit exactly one medical type item

# Form elements
@export var amount_spin_box: SpinBox  # SpinBox for the general amount
@export var order_option_button: OptionButton  # OptionButton for the order of applying amounts
@export var attributes_container: VBoxContainer = null  # Container for attribute entries

var ditem: DItem = null:
	set(value):
		if value:
			ditem = value
			load_properties()


# Forward drag-and-drop functionality to the attributes_container
func _ready() -> void:
	attributes_container.set_drag_forwarding(Callable(), _can_drop_attribute_data, _drop_attribute_data)
	_initialize_order_option_button()

# Initialize the order option button with the possible values
func _initialize_order_option_button() -> void:
	order_option_button.clear()
	var options = ["Ascending", "Descending", "Lowest first", "Highest first", "Random"]
	for option in options:
		order_option_button.add_item(option)

# Save the properties from the UI back to the ditem
func save_properties() -> void:
	if not ditem.medical:
		ditem.medical = DItem.Medical.new({})
	
	# Save general amount and order
	ditem.medical.amount = amount_spin_box.value
	ditem.medical.order = order_option_button.get_item_text(order_option_button.selected)

	# Save attributes
	ditem.medical.attributes = _get_attributes_from_ui()


# Load the properties from the ditem into the UI
func load_properties() -> void:
	# Check if ditem.medical is not null
	if ditem.medical == null:
		print_debug("ditem.medical is null, skipping property loading.")
		return
	
	# Load general amount and order
	amount_spin_box.value = ditem.medical.amount
	order_option_button.select(_get_order_option_index(ditem.medical.order))

	# Load attributes into the UI
	_load_attributes_into_ui(ditem.medical.attributes)


# Get the index of the order option based on the text
func _get_order_option_index(order_text: String) -> int:
	for i in range(order_option_button.get_item_count()):
		if order_option_button.get_item_text(i) == order_text:
			return i
	return 0  # Default to the first option if not found


# Load attributes into the attributes_container
func _load_attributes_into_ui(attributes: Array) -> void:
	# Clear previous entries
	for child in attributes_container.get_children():
		child.queue_free()
	
	# Populate the container with attributes
	for attribute in attributes:
		_add_attribute_entry(attribute)


# Get the current attributes from the UI
func _get_attributes_from_ui() -> Array:
	var attributes = []
	var children = attributes_container.get_children()
	for hbox in children:
		if hbox is HBoxContainer:
			var label = hbox.get_child(1) as Label  # The Label is the second child
			var spin_box = hbox.get_child(2) as SpinBox  # The SpinBox is the third child
			attributes.append({"id": label.text, "amount": spin_box.value})
	return attributes


# Add a new attribute entry to the attributes_container
func _add_attribute_entry(attribute: Dictionary) -> void:
	var dattribute: DPlayerAttribute = Gamedata.mods.by_id("Core").playerattributes.by_id(attribute.id)
	var sprite: Texture = dattribute.sprite
	var attribute_name = attribute.id
	var amount = attribute.amount

	# Create an HBoxContainer to hold the elements
	var hbox = HBoxContainer.new()

	# Create a TextureRect for the sprite
	var texture_rect = TextureRect.new()
	texture_rect.texture = sprite
	texture_rect.custom_minimum_size = Vector2(32, 32)  # Ensure the texture is 32x32
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED  # Keep the aspect ratio centered
	hbox.add_child(texture_rect)

	# Create a Label for the attribute name
	var label = Label.new()
	label.text = attribute_name
	hbox.add_child(label)

	# Create a SpinBox for the attribute value
	var amountSpinBox = SpinBox.new()
	amountSpinBox.value = amount
	amountSpinBox.min_value = -100  # Set the minimum value
	amountSpinBox.max_value = 100   # Set the maximum value
	amountSpinBox.tooltip_text = "This amount will be used to modify the value of \n" + \
								"the assigned attribute by the given amount. It  \n" + \
								"can be positive or negative. This is an extra amount  \n" + \
								"on top of the general amount given by the item. If  \n" + \
								"no specific amount should be added to the attribute, enter 0."
	hbox.add_child(amountSpinBox)
	
	# Create a Button to delete the attribute entry
	var deleteButton = Button.new()
	deleteButton.text = "X"
	deleteButton.pressed.connect(_delete_attribute_entry.bind([hbox]))
	hbox.add_child(deleteButton)

	# Create an Up Button to move the entry up
	var upButton = Button.new()
	upButton.text = "▲"
	upButton.pressed.connect(_move_entry_up.bind(hbox))
	hbox.add_child(upButton)

	# Create a Down Button to move the entry down
	var downButton = Button.new()
	downButton.text = "▼"
	downButton.pressed.connect(_move_entry_down.bind(hbox))
	hbox.add_child(downButton)

	# Add the HBoxContainer to the attributes_container
	attributes_container.add_child(hbox)


# Delete an attribute entry from the attributes_container
func _delete_attribute_entry(elements_to_remove: Array) -> void:
	for element in elements_to_remove:
		attributes_container.remove_child(element)
		element.queue_free()  # Properly free the node to avoid memory leaks


# Function to determine if the dragged data can be dropped in the attributes_container
func _can_drop_attribute_data(_newpos, data) -> bool:
	# Check if the data dictionary has the 'id' property
	if not data or not data.has("id"):
		return false

	# Fetch attribute by ID from the Gamedata to ensure it exists and is valid
	if not Gamedata.mods.by_id("Core").playerattributes.has_id(data["id"]):
		return false

	# Check if the attribute ID already exists in the attributes grid
	var children = attributes_container.get_children()
	for hbox in children:
		if hbox is HBoxContainer:
			var label = hbox.get_child(1) as Label  # The Label is the second child
			if label.text == data["id"]:
				# Return false if this attribute ID already exists in the attributes grid
				return false

	# If all checks pass, return true
	return true


# Function to handle the data being dropped in the attributes_container
func _drop_attribute_data(newpos, data) -> void:
	if _can_drop_attribute_data(newpos, data):
		_handle_attribute_drop(data, newpos)


# Called when the user has successfully dropped data onto the attributes_container
# We have to check the dropped_data for the id property
func _handle_attribute_drop(dropped_data, _newpos) -> void:
	# dropped_data is a Dictionary that includes an 'id'
	if dropped_data and "id" in dropped_data:
		var attribute_id = dropped_data["id"]
		if not Gamedata.mods.by_id("Core").playerattributes.has_id(attribute_id):
			print_debug("No attribute data found for ID: " + attribute_id)
			return
		
		# Add the attribute entry using the new function
		_add_attribute_entry({"id":attribute_id, "amount":0})
		# Here you would update your data structure if needed, similar to how you did for resources
	else:
		print_debug("Dropped data does not contain an 'id' key.")


# Move the entry up by one position in the attributes_container
func _move_entry_up(hbox: HBoxContainer) -> void:
	var index = attributes_container.get_child_index(hbox)
	if index > 0:  # Ensure it's not the first element
		attributes_container.move_child(hbox, index - 1)


# Move the entry down by one position in the attributes_container
func _move_entry_down(hbox: HBoxContainer) -> void:
	var index = attributes_container.get_child_index(hbox)
	if index < attributes_container.get_child_count() - 1:  # Ensure it's not the last element
		attributes_container.move_child(hbox, index + 1)
