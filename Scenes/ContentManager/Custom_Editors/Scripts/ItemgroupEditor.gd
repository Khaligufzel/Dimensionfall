extends Control

# This scene is intended to be used inside the content editor
# It is supposed to edit exactly one itemgroup
# It expects to save the data to a JSON file that contains all itemgroup data from a mod
# To load data, provide the name of the itemgroup data file and an ID

@export var itemgroupImageDisplay: TextureRect = null
@export var IDTextLabel: Label = null
@export var NameTextEdit: TextEdit = null
@export var DescriptionTextEdit: TextEdit = null
@export var itemgroupSelector: Popup = null
@export var imageNameStringLabel: Label = null
@export var modeOptionButton: OptionButton = null
@export var itemListContainer: GridContainer = null
@export var use_sprite_check_box: CheckBox = null
@export var amount_spin_box: SpinBox = null
@export var simulation_text_edit: TextEdit = null


# For controlling the focus when the tab button is pressed
var control_elements: Array = []
# This signal will be emitted when the user presses the save button
# This signal should alert the contenteditor to refresh the content list
signal data_changed()

var olddata: DItemgroup # Remember what the value of the data was before editing
# The data that represents this itemgroup
# The data is selected from the Gamedata.itemgroups dictionary
# based on the ID that the user has selected in the content editor
var ditemgroup: DItemgroup = null:
	set(value):
		ditemgroup = value
		load_itemgroup_data()
		itemgroupSelector.sprites_collection = Gamedata.itemgroups.sprites
		olddata = DItemgroup.new(ditemgroup.get_data().duplicate(true))


func _ready():
	control_elements = [itemgroupImageDisplay,NameTextEdit,DescriptionTextEdit]
	modeOptionButton.add_item("Collection")
	modeOptionButton.add_item("Distribution")
	modeOptionButton.selected = 0  # Default to Collection


# Refreshes the itemlist based on the contentdata
func update_item_list_with_probabilities():
	# Remove all children from the existing container
	while itemListContainer.get_child_count() > 0:
		var child = itemListContainer.get_child(0)
		itemListContainer.remove_child(child)
		child.queue_free()
	add_header_row()
	# Populate the container with new data
	for item: DItemgroup.Item in ditemgroup.items:
		add_item_entry(item)


# Adds a new item and controls to the itemlist
func add_item_entry(item: DItemgroup.Item):
	var item_icon = TextureRect.new()
	var item_sprite = Gamedata.items.sprite_by_id(item.get("id"))
	item_icon.texture = item_sprite
	item_icon.custom_minimum_size = Vector2(16, 16)

	var item_label = Label.new()
	item_label.text = item.get("id")

	var probability_spinbox = SpinBox.new()
	probability_spinbox.min_value = 0.0
	probability_spinbox.max_value = 100.0
	probability_spinbox.value = item.probability
	probability_spinbox.step = 1
	probability_spinbox.tooltip_text = "Set the item's spawn probability. Range: 0% (never)" +\
									" to 100% (always).\nCollection Mode: Each item is" + \
								  " picked independently. A probability of 100% means the " + \
								  "item always appears, while 0% means it never does.\n" + \
								  "Distribution Mode: One item is picked from the list. " + \
								  "The item's probability is relative to others. \n" + \
								  "E.g., if an item A has a probability of 30 and another " + \
								  "item B has 20, A's chance is 60% (30 out of 50) and " + \
								  "B's is 40% (20 out of 50)."

	var min_spinbox = SpinBox.new()
	min_spinbox.min_value = 0
	min_spinbox.max_value = 100
	min_spinbox.value = item.minc
	min_spinbox.step = 1
	min_spinbox.tooltip_text = "Minimum amount that can spawn"

	var max_spinbox = SpinBox.new()
	max_spinbox.min_value = 1
	max_spinbox.max_value = 100
	max_spinbox.value = item.maxc
	max_spinbox.step = 1
	max_spinbox.tooltip_text = "Maximum amount that can spawn"

	var delete_button = Button.new()
	delete_button.text = "X"
	delete_button.button_up.connect(_on_delete_item_button_pressed.bind(item.get("id")))

	# Add components to GridContainer
	itemListContainer.add_child(item_icon)
	itemListContainer.add_child(item_label)
	itemListContainer.add_child(probability_spinbox)
	itemListContainer.add_child(min_spinbox)
	itemListContainer.add_child(max_spinbox)
	itemListContainer.add_child(delete_button)


# The user has pressed the delete button next to an item in the itemlist
# Remove the entire row of the item
func _on_delete_item_button_pressed(item_id):
	var num_columns = itemListContainer.columns  # Make sure this matches the number of elements per item in your grid
	var children_to_remove = []
	
	# Find the label with the matching item_id to determine which row to delete
	for i in range(itemListContainer.get_child_count()):
		var child = itemListContainer.get_child(i)
		if child is Label and child.text == item_id:
			# Calculate the start of the row
			var start_index = i - (i % num_columns)
			# Queue all elements in this row for removal by offsetting from the start_index
			for j in range(num_columns):
				children_to_remove.append(itemListContainer.get_child(start_index + j))
			break  # Once we find the right row, no need to check further
	
	# Remove and free all queued children
	for child in children_to_remove:
		itemListContainer.remove_child(child)
		child.queue_free()


# Loads the data into the editor. contentData describes exactly one itemgroup
func load_itemgroup_data():
	if itemgroupImageDisplay and ditemgroup.spriteid and not ditemgroup.spriteid.is_empty():
		itemgroupImageDisplay.texture = ditemgroup.sprite
		imageNameStringLabel.text = ditemgroup.spriteid
	if IDTextLabel:
		IDTextLabel.text = ditemgroup.id
	if NameTextEdit:
		NameTextEdit.text = ditemgroup.name
	if DescriptionTextEdit:
		DescriptionTextEdit.text = ditemgroup.description
	if use_sprite_check_box:
		use_sprite_check_box.button_pressed = ditemgroup.use_sprite
	# Set the mode from itemgroup
	select_option_by_string(modeOptionButton, ditemgroup.mode)
	update_item_list_with_probabilities()


# This function will select the option in the option_button that matches the given string.
# If no match is found, it does nothing.
func select_option_by_string(option_button: OptionButton, option_string: String) -> void:
	for i in range(option_button.get_item_count()):
		if option_button.get_item_text(i) == option_string:
			option_button.selected = i
			return
	print_debug("No matching option found for the string: " + option_string)


#The editor is closed, destroy the instance
#TODO: Check for unsaved changes
func _on_close_button_button_up():
	queue_free()


# This function takes all data from the form elements stores them in the contentData
# Since contentData is a reference to an item in Gamedata.itemgroup
# the central array for itemgroupdata is updated with the changes as well
# The function will signal to Gamedata that the data has changed and needs to be saved
func _on_save_button_button_up():
	ditemgroup.sprite = itemgroupImageDisplay.texture
	ditemgroup.spriteid = imageNameStringLabel.text
	ditemgroup.name = NameTextEdit.text
	ditemgroup.description = DescriptionTextEdit.text
	ditemgroup.use_sprite = use_sprite_check_box.button_pressed
	ditemgroup.mode = modeOptionButton.get_item_text(modeOptionButton.selected)
	
	var new_items: Array[DItemgroup.Item] = []
	var num_children = itemListContainer.get_child_count()
	var num_columns = itemListContainer.columns

	# Start from index 6 to skip header, which occupies the first 6 indices (0 to 5)
	for i in range(6, num_children, num_columns):
		var item_id = itemListContainer.get_child(i + 1).text  # Second child in each row is the item ID label
		var probability = itemListContainer.get_child(i + 2).get_value()  # Third child is the SpinBox for probability
		var min_amount = itemListContainer.get_child(i + 3).get_value()  # Fourth child is the SpinBox for minimum count
		var max_amount = itemListContainer.get_child(i + 4).get_value()  # Fifth child is the SpinBox for maximum count

		new_items.append(DItemgroup.Item.new({
			"id": item_id, 
			"probability": probability, 
			"min": min_amount, 
			"max": max_amount
		}))
	
	ditemgroup.items = new_items
	ditemgroup.changed(olddata)
	data_changed.emit()
	olddata = DItemgroup.new(ditemgroup.get_data().duplicate(true))



func _input(event):
	if event.is_action_pressed("ui_focus_next"):
		for myControl in control_elements:
			if myControl.has_focus():
				if Input.is_key_pressed(KEY_SHIFT):  # Check if Shift key
					if !myControl.focus_previous.is_empty():
						myControl.get_node(myControl.focus_previous).grab_focus()
				else:
					if !myControl.focus_next.is_empty():
						myControl.get_node(myControl.focus_next).grab_focus()
				break
		get_viewport().set_input_as_handled()


#When the itemgroupImageDisplay is clicked, the user will be prompted to select an image from 
# "res://Mods/Core/Itemgroups/". The texture of the itemgroupImageDisplay will change to the selected image
func _on_itemgroup_image_display_gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		itemgroupSelector.show()


# Sets the sprite in the editor based on what sprite the user has selected
func _on_sprite_selector_sprite_selected_ok(clicked_sprite) -> void:
	var itemgroupTexture: Resource = clicked_sprite.get_texture()
	itemgroupImageDisplay.texture = itemgroupTexture
	imageNameStringLabel.text = itemgroupTexture.resource_path.get_file()


# This function should return true if the dragged data can be dropped here
func _can_drop_data(_newpos, data) -> bool:
	# Check if the data dictionary has the 'id' property
	if not data or not data.has("id"):
		return false
	
	# Fetch item data by ID from Gamedata to ensure it exists and is valid
	if not Gamedata.items.has_id(data["id"]):
		return false

	# Check if the ID of the dragged item already exists in the itemListContainer
	for child in itemListContainer.get_children():
		if child is HBoxContainer:
			var label = child.get_child(1)  # Assuming the ID label is the second child
			if label.text == data["id"]:
				return false  # The item is already in the list

	# If all checks pass, return true
	return true


# This function handles the data being dropped
func _drop_data(newpos, data) -> void:
	if _can_drop_data(newpos, data):
		_handle_item_drop(data, newpos)


# Called when the user has successfully dropped data onto the itemList
func _handle_item_drop(dropped_data, _newpos) -> void:
	# Assuming dropped_data is a Dictionary that includes an 'id'
	if dropped_data and "id" in dropped_data:
		var item_id = dropped_data["id"]
		if not Gamedata.items.has_id(item_id):
			return
		
		# Check if the item already exists in the itemListContainer to avoid duplicates
		for child in itemListContainer.get_children():
			if child is HBoxContainer:
				var label = child.get_child(1)  # Assuming the ID label is the second child
				if label.text == item_id:
					print_debug("Item already exists in the list: " + item_id)
					return

		# If item is not already in the list, add it, use default probability if not specified
		add_item_entry(DItemgroup.Item.new({"id": item_id, "probability": 20}))
	else:
		print_debug("Dropped data does not contain an 'id' key.")


# Adds a header to the itemlist
func add_header_row():
	# Define a common style for all header labels
	var header_style = StyleBoxFlat.new()
	header_style.bg_color = Color(0.2, 0.2, 0.2)  # Dark gray color
	header_style.border_width_top = 1
	header_style.border_width_bottom = 1
	header_style.border_color = Color(0.5, 0.5, 0.5)  # Lighter gray for the border

	# Create header labels with the specified style
	var headers = ["Icon", "Item ID", "Probability (%)", "Min Count", "Max Count", "Delete"]
	var tooltips = [
		"",  # Icon doesn't need a tooltip
		"",  # Item ID is self-explanatory
		"Set the item's spawn probability. Range: 0% (never) to 100% (always).",
		"Minimum amount that can spawn of this item.",
		"Maximum amount that can spawn of this item.",
		""  # Delete is self-explanatory
	]

	for i in range(headers.size()):
		var header = Label.new()
		header.text = headers[i]
		header.tooltip_text = tooltips[i]
		header.set_horizontal_alignment(HORIZONTAL_ALIGNMENT_CENTER)
		header.add_theme_stylebox_override("normal",header_style)
		header.set("custom_styles/panel", header_style.duplicate())  # Use duplicate to ensure each header can customize further if needed
		itemListContainer.add_child(header)


func _on_simulation_button_button_up() -> void:
	# Step 1: Read items from itemListContainer, including min and max amounts
	var items_data: Array = []
	var num_children = itemListContainer.get_child_count()
	var num_columns = itemListContainer.columns

	# Start from index 6 to skip header, which occupies the first 6 indices
	for i in range(6, num_children, num_columns):
		var item_id = itemListContainer.get_child(i + 1).text  # Second child in each row is the item ID label
		var probability = itemListContainer.get_child(i + 2).get_value()  # Third child is the probability SpinBox
		var min_amount = itemListContainer.get_child(i + 3).get_value()  # Fourth child is the minimum SpinBox
		var max_amount = itemListContainer.get_child(i + 4).get_value()  # Fifth child is the maximum SpinBox

		items_data.append({
			"id": item_id,
			"probability": probability,
			"min": int(min_amount),
			"max": int(max_amount)
		})

	# Step 2: Read the selected mode from modeOptionButton (Collection or Distribution)
	var selected_mode: String = modeOptionButton.get_item_text(modeOptionButton.selected)

	# Step 3: Read the number from amount_spin_box (number of simulations)
	var num_simulations: int = int(amount_spin_box.value)

	# Prepare the results array
	var simulation_results: Dictionary = {}

	# Step 4: Simulate the generation for the specified number of times
	for i in range(num_simulations):
		if selected_mode == "Collection":
			_simulate_collection_mode(items_data, simulation_results)
		elif selected_mode == "Distribution":
			_simulate_distribution_mode(items_data, simulation_results)

	# Step 5: Sort the results by the amount generated (in descending order)
	var sorted_results: Array = simulation_results.keys().map(
		func(item_id):
			return {"id": item_id, "amount": simulation_results[item_id]}
	)
	
	# Sort the array based on the "amount" value in descending order
	sorted_results.sort_custom(func(a, b):
		return b["amount"] < a["amount"]
	)

	# Step 6: Print the sorted simulation results to simulation_text_edit
	var result_text: String = ""
	for result in sorted_results:
		result_text += str(result["id"]) + ": " + str(result["amount"]) + "\n"

	simulation_text_edit.text = result_text  # Display the results in the text edit



func _simulate_collection_mode(items: Array, results: Dictionary) -> void:
	# Loop through each item and simulate its generation
	for item in items:
		var item_id = item["id"]
		var probability = item["probability"]
		var minc = item["min"]
		var maxc = item["max"]

		if randi_range(0, 100) <= probability:  # Check if the item should be added based on probability
			var quantity = randi_range(minc, maxc)
			if not results.has(item_id):
				results[item_id] = 0
			results[item_id] += quantity

func _simulate_distribution_mode(items: Array, results: Dictionary) -> void:
	var total_probability = 0
	# Calculate the total probability
	for item in items:
		total_probability += item["probability"]

	# Generate a random value between 0 and total_probability - 1
	var random_value = randi_range(0, total_probability - 1)
	var cumulative_probability = 0

	# Iterate through items to select one based on the random value
	for item in items:
		cumulative_probability += item["probability"]
		if random_value < cumulative_probability:
			var item_id = item["id"]
			var quantity = randi_range(item["min"], item["max"])
			if not results.has(item_id):
				results[item_id] = 0
			results[item_id] += quantity
			return  # Only one item is selected in Distribution mode
