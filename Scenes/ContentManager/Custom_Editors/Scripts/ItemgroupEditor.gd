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
@export var modeOptionButton: OptionButton
@export var itemListContainer: GridContainer
# For controlling the focus when the tab button is pressed
var control_elements: Array = []


# This signal will be emitted when the user presses the save button
# This signal should alert Gamedata that the mob data array should be saved to disk
signal data_changed(game_data: Dictionary, new_data: Dictionary, old_data: Dictionary)

var olddata: Dictionary # Remember what the value of the data was before editing
# The data that represents this itemgroup
# The data is selected from the Gamedata.data.itemgroup.data array
# based on the ID that the user has selected in the content editor
var contentData: Dictionary = {}:
	set(value):
		contentData = value
		load_itemgroup_data()
		itemgroupSelector.sprites_collection = Gamedata.data.itemgroups.sprites
		olddata = contentData.duplicate(true)


func _ready():
	control_elements = [itemgroupImageDisplay,NameTextEdit,DescriptionTextEdit]
	data_changed.connect(Gamedata.on_data_changed)
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
	for item in contentData.get("items", []):
		add_item_entry(item)


# Adds a new item and controls to the itemlist
func add_item_entry(item):
	var item_icon = TextureRect.new()
	var item_sprite = Gamedata.get_sprite_by_id(Gamedata.data.items, item.get("id"))
	item_icon.texture = item_sprite
	item_icon.custom_minimum_size = Vector2(16, 16)

	var item_label = Label.new()
	item_label.text = item.get("id")

	var probability_spinbox = SpinBox.new()
	probability_spinbox.min_value = 0.0
	probability_spinbox.max_value = 100.0
	probability_spinbox.value = item.get("probability", 20)
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
	min_spinbox.value = item.get("min", 1)
	min_spinbox.step = 1
	min_spinbox.tooltip_text = "Minimum amount that can spawn"

	var max_spinbox = SpinBox.new()
	max_spinbox.min_value = 1
	max_spinbox.max_value = 100
	max_spinbox.value = item.get("max", 1)
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
	if itemgroupImageDisplay and contentData.has("sprite") and not contentData["sprite"].is_empty():
		itemgroupImageDisplay.texture = Gamedata.data.itemgroups.sprites[contentData["sprite"]]
		imageNameStringLabel.text = contentData["sprite"]
	if IDTextLabel:
		IDTextLabel.text = str(contentData["id"])
	if NameTextEdit and contentData.has("name"):
		NameTextEdit.text = contentData["name"]
	if DescriptionTextEdit and contentData.has("description"):
		DescriptionTextEdit.text = contentData["description"]
	# Set the mode from contentData
	if contentData.has("mode"):
		select_option_by_string(modeOptionButton, contentData["mode"])

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
# Since contentData is a reference to an item in Gamedata.data.itemgroup.data
# the central array for itemgroupdata is updated with the changes as well
# The function will signal to Gamedata that the data has changed and needs to be saved
func _on_save_button_button_up():
	contentData["sprite"] = imageNameStringLabel.text
	contentData["name"] = NameTextEdit.text
	contentData["description"] = DescriptionTextEdit.text
	contentData["mode"] = modeOptionButton.get_item_text(modeOptionButton.selected)
	
	var new_items = []
	var num_children = itemListContainer.get_child_count()
	var num_columns = itemListContainer.columns

	# Start from index 6 to skip header, which occupies the first 6 indices (0 to 5)
	for i in range(6, num_children, num_columns):
		var item_id = itemListContainer.get_child(i + 1).text  # Second child in each row is the item ID label
		var probability = itemListContainer.get_child(i + 2).get_value()  # Third child is the SpinBox for probability
		var min_amount = itemListContainer.get_child(i + 3).get_value()  # Fourth child is the SpinBox for minimum count
		var max_amount = itemListContainer.get_child(i + 4).get_value()  # Fifth child is the SpinBox for maximum count

		new_items.append({
			"id": item_id, 
			"probability": probability, 
			"min": min_amount, 
			"max": max_amount
		})
	
	contentData["items"] = new_items
	data_changed.emit(Gamedata.data.itemgroups, contentData, olddata)
	olddata = contentData.duplicate(true)



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
	var item_data = Gamedata.get_data_by_id(Gamedata.data.items, data["id"])
	if item_data.is_empty():
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
# We have to check the dropped_data for the id property
# Then we have to get the item data from Gamedata.get_data_by_id(Gamedata.data.items, id)
# Then we have to get the sprite using Gamedata.get_sprite_by_id(Gamedata.data.items, id)
func _handle_item_drop(dropped_data, _newpos) -> void:
	# Assuming dropped_data is a Dictionary that includes an 'id'
	if dropped_data and "id" in dropped_data:
		var item_id = dropped_data["id"]
		var item_data = Gamedata.get_data_by_id(Gamedata.data.items, item_id)
		if item_data.is_empty():
			print_debug("No item data found for ID: " + item_id)
			return

		# Check if the item already exists in the itemListContainer to avoid duplicates
		for child in itemListContainer.get_children():
			if child is HBoxContainer:
				var label = child.get_child(1)  # Assuming the ID label is the second child
				if label.text == item_id:
					print_debug("Item already exists in the list: " + item_id)
					return

		# If item is not already in the list, add it
		add_item_entry({"id": item_id, "probability": 20})  # Default probability if not specified
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

