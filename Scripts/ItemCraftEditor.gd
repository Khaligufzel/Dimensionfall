extends Control

# This scene is intended to be used inside the item editor
# It is supposed to edit exactly one craft recipe

@export var craftAmountNumber: SpinBox = null
@export var craftTimeNumber: SpinBox = null
@export var requiresLightCheckbox: CheckBox = null
@export var resourcesGridContainer: GridContainer = null


func _ready():
	pass


func get_properties() -> Dictionary:
	var properties = {
		"craft_amount": craftAmountNumber.value,
		"craft_time": craftTimeNumber.value,
		"flags": {"requires_light": requiresLightCheckbox.pressed},
		"resources": []
	}
	
	# Iterate over children of resourcesGridContainer to collect resource data
	var children = resourcesGridContainer.get_children()
	for i in range(0, children.size(), 2): # Step by 2 to handle label-spinbox pairs
		var label = children[i] as Label
		var spinBox = children[i + 1] as SpinBox
		properties["resources"].append({"id": label.text, "amount": spinBox.value})
	
	return properties


func set_properties(properties: Dictionary) -> void:
	# Clear existing resources
	resourcesGridContainer.queue_free()
	resourcesGridContainer = GridContainer.new()
	add_child(resourcesGridContainer)

	# Set the craft amount, time, and flags
	craftAmountNumber.value = properties.get("craft_amount", 1)
	craftTimeNumber.value = properties.get("craft_time", 0)
	requiresLightCheckbox.button_pressed = properties.get("flags", {}).get("requires_light", false)

	# Populate resources grid using the new function
	if properties.has("resources"):
		for resource in properties["resources"]:
			add_resource_entry(resource["id"], resource["amount"])


# This function should return true if the dragged data can be dropped here
func _can_drop_data(_newpos, data) -> bool:
	# Check if the data dictionary has the 'id' property
	if not data or not data.has("id"):
		return false
	
	# Fetch itemgroup data by ID from the Gamedata to ensure it exists and is valid
	var item_data = Gamedata.get_data_by_id(Gamedata.data.items, data["id"])
	if item_data.is_empty():
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
	# Dropped_data is a Dictionary that includes an 'id'
	if dropped_data and "id" in dropped_data:
		var item_id = dropped_data["id"]
		var item_data = Gamedata.get_data_by_id(Gamedata.data.items, item_id)
		if item_data.is_empty():
			print_debug("No item data found for ID: " + item_id)
			return
		
		# Add the resource entry using the new function
		add_resource_entry(item_id, 1)
	else:
		print_debug("Dropped data does not contain an 'id' key.")



func _delete_resource(elements_to_remove: Array) -> void:
	for element in elements_to_remove:
		resourcesGridContainer.remove_child(element)
		element.queue_free()  # Properly free the node to avoid memory leaks


func add_resource_entry(item_id: String, amount: int = 1):
	# Create a label for the item ID
	var label = Label.new()
	label.text = item_id
	resourcesGridContainer.add_child(label)
	
	# Create a SpinBox for the amount
	var amountSpinBox = SpinBox.new()
	amountSpinBox.value = amount
	resourcesGridContainer.add_child(amountSpinBox)
	
	# Create a delete button
	var deleteButton = Button.new()
	deleteButton.text = "X"
	deleteButton.pressed.connect(_delete_resource.bind([label, amountSpinBox, deleteButton]))
	resourcesGridContainer.add_child(deleteButton)
