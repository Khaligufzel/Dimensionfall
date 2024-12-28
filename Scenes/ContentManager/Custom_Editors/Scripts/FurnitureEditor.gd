extends Control

#This scene is intended to be used inside the content editor
#It is supposed to edit exactly one piece of furniture
#It expects to save the data to a JSON file that contains all furniture data from a mod
#To load data, provide the name of the furniture data file and an ID

@export var tab_container: TabContainer

@export var furnitureImageDisplay: TextureRect = null
@export var IDTextLabel: Label = null
@export var NameTextEdit: TextEdit = null
@export var DescriptionTextEdit: TextEdit = null
@export var CategoriesList: Control = null
@export var furnitureSelector: Popup = null
@export var imageNameStringLabel: Label = null
@export var moveableCheckboxButton: CheckBox = null # The player can push it if selected
@export var weightLabel: Label = null
@export var weightSpinBox: SpinBox = null # The wight considered when pushing
@export var edgeSnappingOptionButton: OptionButton = null # Apply edge snapping if selected
@export var doorOptionButton: OptionButton = null # Maks the furniture as a door
@export var containerCheckBox: CheckBox = null # Marks the furniture as a container
@export var containerTextEdit: HBoxContainer = null # Might contain the id of a loot group
@export var regeneration_label: Label = null
@export var regeneration_spin_box: SpinBox = null # The time in days before regeneration

@export var destroyHboxContainer: HBoxContainer = null # contains destroy controls
@export var canDestroyCheckbox: CheckBox = null # If the furniture can be destroyed or not
@export var destructionTextEdit: HBoxContainer = null # Might contain the id of a loot group
@export var destructionImageDisplay: TextureRect = null # What it looks like when destroyed
@export var destructionSpriteNameLabel: Label = null # The name of the destroyed sprite

@export var disassemblyHboxContainer: HBoxContainer = null # contains destroy controls
@export var canDisassembleCheckbox: CheckBox = null # If the furniture can be disassembled or not
@export var disassemblyTextEdit: HBoxContainer = null # Might contain the id of a loot group
@export var disassemblyImageDisplay: TextureRect = null # What it looks like when disassembled
@export var disassemblySpriteNameLabel: Label = null # The name of the disassembly sprite

# Controls for the shape:
@export var support_shape_option_button: OptionButton
@export var width_scale_label: Label = null
@export var depth_scale_label: Label = null
@export var radius_scale_label: Label = null
@export var width_scale_spin_box: SpinBox
@export var depth_scale_spin_box: SpinBox
@export var radius_scale_spin_box: SpinBox
@export var heigth_spin_box: SpinBox
@export var color_picker: ColorPicker
@export var sprite_texture_rect: TextureRect
@export var transparent_check_box: CheckBox

# Container for items that can be crafted
@export var items_grid_container: GridContainer = null
# Container for items that are requires to construct this furniture.
@export var construction_items_grid_container: GridContainer = null

# For controlling the focus when the tab button is pressed
var control_elements: Array = []
# Tracks which image display control is currently being updated
var current_image_display: String = ""


# This signal will be emitted when the user presses the save button
signal data_changed()


var olddata: DFurniture # Remember what the value of the data was before editing
# The DFurniture that represents this furniture
var dfurniture: DFurniture:
	set(value):
		dfurniture = value
		load_furniture_data()
		furnitureSelector.sprites_collection = dfurniture.parent.sprites
		if not data_changed.is_connected(dfurniture.parent.on_data_changed):
			data_changed.connect(dfurniture.parent.on_data_changed)
		olddata = DFurniture.new(dfurniture.get_data().duplicate(true), null)


func _ready():
	# For properly using the tab key to switch elements
	control_elements = [furnitureImageDisplay,NameTextEdit,DescriptionTextEdit]
	#data_changed.connect(dfurniture.parent.on_data_changed)
	set_drop_functions()
	
	# Connect the toggle signal to the function
	moveableCheckboxButton.toggled.connect(_on_moveable_checkbox_toggled)
	items_grid_container.set_drag_forwarding(Callable(), _can_item_drop, _item_drop)


func load_furniture_data():
	if furnitureImageDisplay and dfurniture.sprite:
		furnitureImageDisplay.texture = dfurniture.sprite
		imageNameStringLabel.text = dfurniture.spriteid
		update_sprite_texture_rect(furnitureImageDisplay.texture)
	if IDTextLabel:
		IDTextLabel.text = dfurniture.id
	if NameTextEdit:
		NameTextEdit.text = dfurniture.name
	if DescriptionTextEdit:
		DescriptionTextEdit.text = dfurniture.description
	if CategoriesList:
		_update_categories()
	if moveableCheckboxButton:
		moveableCheckboxButton.button_pressed = dfurniture.moveable
		_on_moveable_checkbox_toggled(dfurniture.moveable)
	if weightSpinBox:
		weightSpinBox.value = dfurniture.weight
	if edgeSnappingOptionButton:
		select_option_by_string(edgeSnappingOptionButton, dfurniture.edgesnapping)
	if doorOptionButton:
		update_door_option(dfurniture.function.door)

	if not dfurniture.destruction.get_data().is_empty():
		canDestroyCheckbox.button_pressed = true
		destructionTextEdit.set_text(dfurniture.destruction.group)
		if not dfurniture.destruction.sprite == "":
			destructionImageDisplay.texture = dfurniture.parent.sprite_by_file(dfurniture.destruction.sprite)
		destructionSpriteNameLabel.text = dfurniture.destruction.sprite
		set_visibility_for_children(destructionTextEdit, true)
	else:
		canDestroyCheckbox.button_pressed = false
		set_visibility_for_children(destructionTextEdit, false)

	if not dfurniture.disassembly.get_data().is_empty():
		canDisassembleCheckbox.button_pressed = true
		disassemblyTextEdit.set_text(dfurniture.disassembly.group)
		disassemblyImageDisplay.texture = dfurniture.parent.sprite_by_file(dfurniture.disassembly.sprite)
		disassemblySpriteNameLabel.text = dfurniture.disassembly.sprite
		set_visibility_for_children(disassemblyTextEdit, true)
	else:
		canDisassembleCheckbox.button_pressed = false
		set_visibility_for_children(disassemblyTextEdit, false)

	# Load container data if it exists within the 'Function' property
	if dfurniture.function.is_container:
		containerCheckBox.button_pressed = true  # Check the container checkbox
		var itemgroup: String = dfurniture.function.container_group
		if not itemgroup == "":
			containerTextEdit.set_text(itemgroup)
		else:
			containerTextEdit.mytextedit.clear()  # Clear the text edit if no itemgroup is specified
		
		# Load regeneration time if applicable
		if dfurniture.function.container_regeneration_time >= 0.0:
			regeneration_spin_box.value = dfurniture.function.container_regeneration_time
		else:
			regeneration_spin_box.value = -1.0  # Default to -1.0 if no regeneration time is set
	else:
		containerCheckBox.button_pressed = false  # Uncheck the container checkbox
		containerTextEdit.mytextedit.clear()  # Clear the text edit as no container data is present
		regeneration_spin_box.value = -1.0  # Reset regeneration spin box

	# Call the function to load the support shape data
	load_support_shape_option()
	update_item_list()
	update_construction_item_list()


func _update_categories():
		CategoriesList.clear_list()
		for category in dfurniture.categories:
			CategoriesList.add_item_to_list(category)


# Function to load support shape data into the form
func load_support_shape_option():
	var supportshape = dfurniture.support_shape
	var shape = supportshape.shape

	# Select the appropriate shape in the option button
	for i in range(support_shape_option_button.get_item_count()):
		if support_shape_option_button.get_item_text(i) == shape:
			support_shape_option_button.selected = i
			break

	color_picker.color = Color.html(supportshape.color)

	transparent_check_box.button_pressed = supportshape.transparent
	heigth_spin_box.value = supportshape.height

	if shape == "Box":
		width_scale_spin_box.value = supportshape.width_scale
		depth_scale_spin_box.value = supportshape.depth_scale
		width_scale_spin_box.visible = true
		depth_scale_spin_box.visible = true
		width_scale_label.visible = true
		depth_scale_label.visible = true
		radius_scale_spin_box.visible = false
		radius_scale_label.visible = false
	elif shape == "Cylinder":
		radius_scale_spin_box.value = supportshape.radius_scale
		width_scale_spin_box.visible = false
		depth_scale_spin_box.visible = false
		width_scale_label.visible = false
		depth_scale_label.visible = false
		radius_scale_spin_box.visible = true
		radius_scale_label.visible = true


func update_door_option(door_state):
	var items = doorOptionButton.get_item_count()
	for i in range(items):
		if doorOptionButton.get_item_text(i) == door_state or (door_state not in ["Open", "Closed"] and doorOptionButton.get_item_text(i) == "None"):
			doorOptionButton.selected = i
			return
	print_debug("No matching door state option found: " + door_state)


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
	queue_free.call_deferred()


# Updates the sprite_texture_rect with the given texture
func update_sprite_texture_rect(texture: Texture):
	if sprite_texture_rect:
		sprite_texture_rect.texture = texture


# This function takes all data from the form elements and stores them in the dfurniture.
func _on_save_button_button_up():
	dfurniture.spriteid = imageNameStringLabel.text
	dfurniture.sprite = furnitureImageDisplay.texture
	dfurniture.name = NameTextEdit.text
	dfurniture.description = DescriptionTextEdit.text
	dfurniture.categories = CategoriesList.get_items()
	dfurniture.moveable = moveableCheckboxButton.button_pressed
	dfurniture.weight = weightSpinBox.value
	dfurniture.edgesnapping = edgeSnappingOptionButton.get_item_text(edgeSnappingOptionButton.selected)

	# Handle saving or erasing the support shape data
	handle_support_shape_option()
	handle_door_option()
	handle_container_option()
	handle_destruction_option()
	handle_disassembly_option()

	# Save crafting and construction items
	save_crafting_items()
	save_construction_items()

	dfurniture.on_data_changed(olddata)
	data_changed.emit()
	olddata = DFurniture.new(dfurniture.get_data().duplicate(true), null)


# Function to handle saving or erasing the support shape data
func handle_support_shape_option():
	if not moveableCheckboxButton.button_pressed:
		var shape = support_shape_option_button.get_item_text(support_shape_option_button.selected)
		dfurniture.support_shape.shape = shape
		dfurniture.support_shape.height = heigth_spin_box.value
		dfurniture.support_shape.color = color_picker.color.to_html()
		dfurniture.support_shape.transparent = transparent_check_box.button_pressed
		if shape == "Box":
			dfurniture.support_shape.width_scale = width_scale_spin_box.value
			dfurniture.support_shape.depth_scale = depth_scale_spin_box.value
		elif shape == "Cylinder":
			dfurniture.support_shape.radius_scale = radius_scale_spin_box.value


# If the door function is set, we save the value to contentData
# Else, if the door state is set to none, we erase the value from contentdata
func handle_door_option():
	var door_state = doorOptionButton.get_item_text(doorOptionButton.selected)
	dfurniture.function.door = door_state


func handle_container_option():
	if containerCheckBox.is_pressed():
		dfurniture.function.is_container = true
		dfurniture.function.container_group = containerTextEdit.get_text()
		# Save the regeneration time
		dfurniture.function.container_regeneration_time = regeneration_spin_box.value
	else:
		dfurniture.function.is_container = false
		dfurniture.function.container_group = ""
		# Reset the regeneration time
		dfurniture.function.container_regeneration_time = -1


func handle_destruction_option():
	if canDestroyCheckbox.is_pressed():
		dfurniture.destruction.group = destructionTextEdit.get_text()
		dfurniture.destruction.sprite = destructionSpriteNameLabel.text
	else:
		dfurniture.destruction.group = ""
		dfurniture.destruction.sprite = ""


func handle_disassembly_option():
	if canDestroyCheckbox.is_pressed():
		dfurniture.disassembly.group = disassemblyTextEdit.get_text()
		dfurniture.disassembly.sprite = disassemblySpriteNameLabel.text
	else:
		dfurniture.disassembly.group = ""
		dfurniture.disassembly.sprite = ""


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


func _on_container_check_box_toggled(toggled_on):
	if not toggled_on:
		containerTextEdit.mytextedit.clear()


# Called when the user has successfully dropped data onto the ItemGroupTextEdit
# We have to check the dropped_data for the id property
# We are expecting a dictionary like this:
#	{
#		"id": selected_item_id,
#		"text": selected_item_text,
#		"mod_id": mod_id,
#		"contentType": contentType
#	}
func itemgroup_drop(dropped_data: Dictionary, texteditcontrol: HBoxContainer) -> void:
	# Assuming dropped_data is a Dictionary that includes an 'id'
	if dropped_data and "id" in dropped_data:
		var itemgroup_id = dropped_data["id"]
		if not Gamedata.mods.by_id(dropped_data["mod_id"]).itemgroups.has_id(itemgroup_id):
			print_debug("No item data found for ID: " + itemgroup_id)
			return
		texteditcontrol.set_text(itemgroup_id)
		# If it's the container group, we always set the container checkbox to true
		if texteditcontrol == containerTextEdit:
			containerCheckBox.button_pressed = true
		if texteditcontrol == destructionTextEdit:
			canDestroyCheckbox.button_pressed = true
		if texteditcontrol == disassemblyTextEdit:
			canDisassembleCheckbox.button_pressed = true
	else:
		print_debug("Dropped data does not contain an 'id' key.")


# We are expecting a dictionary like this:
#	{
#		"id": selected_item_id,
#		"text": selected_item_text,
#		"mod_id": mod_id,
#		"contentType": contentType
#	}
func can_itemgroup_drop(dropped_data: Dictionary):
	# Check if the data dictionary has the 'id' property
	if not dropped_data or not dropped_data.has("id"):
		return false
	
	# Fetch itemgroup data by ID from the Gamedata to ensure it exists and is valid
	if not Gamedata.mods.by_id(dropped_data["mod_id"]).itemgroups.has_id(dropped_data["id"]):
		return false

	# If all checks pass, return true
	return true


func set_drop_functions():
	containerTextEdit.drop_function = itemgroup_drop.bind(containerTextEdit)
	containerTextEdit.can_drop_function = can_itemgroup_drop
	disassemblyTextEdit.drop_function = itemgroup_drop.bind(disassemblyTextEdit)
	disassemblyTextEdit.can_drop_function = can_itemgroup_drop
	destructionTextEdit.drop_function = itemgroup_drop.bind(destructionTextEdit)
	destructionTextEdit.can_drop_function = can_itemgroup_drop
	
	construction_items_grid_container.set_drag_forwarding(Callable(), _can_construction_item_drop, _construction_item_drop)


# When the furnitureImageDisplay is clicked, the user will be prompted to select an image from
# "res://Mods/Core/Furnitures/". The texture of the furnitureImageDisplay will change to the selected image
func _on_furniture_image_display_gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		current_image_display = "furniture"
		furnitureSelector.show()

func _on_disassemble_image_display_gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		current_image_display = "disassemble"
		furnitureSelector.show()

func _on_destruction_image_display_gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		current_image_display = "destruction"
		furnitureSelector.show()

func _on_sprite_selector_sprite_selected_ok(clicked_sprite) -> void:
	var furnitureTexture: Resource = clicked_sprite.get_texture()
	if current_image_display == "furniture":
		furnitureImageDisplay.texture = furnitureTexture
		imageNameStringLabel.text = furnitureTexture.resource_path.get_file()
		update_sprite_texture_rect(furnitureTexture)
	elif current_image_display == "disassemble":
		disassemblyImageDisplay.texture = furnitureTexture
		disassemblySpriteNameLabel.text = furnitureTexture.resource_path.get_file()
	elif current_image_display == "destruction":
		destructionImageDisplay.texture = furnitureTexture
		destructionSpriteNameLabel.text = furnitureTexture.resource_path.get_file()


# Utility function to set the visibility of all children of the given container except the first one
func set_visibility_for_children(container: Control, isvisible: bool):
	for i in range(1, container.get_child_count()):
		container.get_child(i).visible = isvisible

func _on_can_destroy_check_box_toggled(toggled_on):
	if not toggled_on:
		destructionTextEdit.mytextedit.clear()
		destructionSpriteNameLabel.text = ""
		destructionImageDisplay.texture = load("res://Scenes/ContentManager/Mapeditor/Images/emptyTile.png")
	set_visibility_for_children(destructionTextEdit, toggled_on)

func _on_can_disassemble_check_box_toggled(toggled_on):
	if not toggled_on:
		disassemblyTextEdit.mytextedit.clear()
		disassemblySpriteNameLabel.text = ""
		disassemblyImageDisplay.texture = load("res://Scenes/ContentManager/Mapeditor/Images/emptyTile.png")
	set_visibility_for_children(disassemblyHboxContainer, toggled_on)


# Function to handle the toggle state of the checkbox
func _on_moveable_checkbox_toggled(button_pressed):
	weightLabel.visible = button_pressed
	weightSpinBox.visible = button_pressed


# When the user selects a shape from the optionbutton
func _on_support_shape_option_button_item_selected(index):
	if index == 0:  # Box is selected
		width_scale_spin_box.visible = true
		depth_scale_spin_box.visible = true
		width_scale_label.visible = true
		depth_scale_label.visible = true
		radius_scale_label.visible = false
		radius_scale_spin_box.visible = false
	elif index == 1:  # Cylinder is selected
		width_scale_spin_box.visible = false
		depth_scale_spin_box.visible = false
		width_scale_label.visible = false
		depth_scale_label.visible = false
		radius_scale_label.visible = true
		radius_scale_spin_box.visible = true


# When the user toggles the moveable checkbox
# We only show the shape tab if the furniture is not moveable but static
func _on_unmoveable_check_box_toggled(toggled_on):
	# Check if the checkbox is toggled on
	if toggled_on:
		# Hide the second tab in the tab container
		tab_container.set_tab_hidden(1, true)
		# Hide the regeneration controls
		regeneration_label.visible = false
		regeneration_spin_box.visible = false
	else:
		# Show the second tab in the tab container
		tab_container.set_tab_hidden(1, false)
		# Show the regeneration controls
		regeneration_label.visible = true
		regeneration_spin_box.visible = true


# Check if the dragged item can be dropped into the items_grid_container
func _can_item_drop(_newpos: Vector2, data: Dictionary) -> bool:
	# Validate that data is a dictionary and contains the required "id" key
	if not data or not data.has("id"):
		return false

	# Validate that the item exists in Gamedata
	if not Gamedata.mods.by_id(data["mod_id"]).items.has_id(data["id"]):
		return false
	
	var ditem: DItem = Gamedata.mods.by_id(data["mod_id"]).items.by_id(data["id"])
	if not ditem.is_craftable():
		return false

	# Check for duplicate items in the grid container
	for child in items_grid_container.get_children():
		if child is Label and child.text == data["id"]:
			return false  # Item already exists

	return true  # Passed all validation checks


# Handle the drop of an item into the items_grid_container
func _item_drop(_newpos: Vector2, data: Dictionary) -> void:
	# Validate if the item can be dropped
	if not _can_item_drop(_newpos, data):
		return

	# Handle the drop and add the item to the grid
	_handle_item_drop(data)


# Function to handle adding the dropped item to the grid container
func _handle_item_drop(dropped_data: Dictionary) -> void:
	# Retrieve item details from Gamedata
	var item_id = dropped_data["id"]
	var item_sprite = Gamedata.mods.get_content_by_id(DMod.ContentType.ITEMS, item_id).sprite

	# Create components for the dropped item row
	var item_icon = TextureRect.new()
	item_icon.texture = item_sprite
	item_icon.custom_minimum_size = Vector2(32, 32)  # Ensure a minimum size for the icon

	var item_label = Label.new()
	item_label.text = item_id

	var delete_button = Button.new()
	delete_button.text = "X"
	delete_button.tooltip_text = "Remove this item"
	delete_button.button_up.connect(_on_delete_item_button_pressed.bind(item_id))

	# Add components to the grid container
	items_grid_container.add_child(item_icon)
	items_grid_container.add_child(item_label)
	items_grid_container.add_child(delete_button)

	# Ensure the furniture is marked as a container
	if not dfurniture.function.is_container:
		dfurniture.function.is_container = true
		containerCheckBox.button_pressed = true  # Reflect the change in the UI


# Handle the deletion of an item from the items_grid_container
func _on_delete_item_button_pressed(item_id: String) -> void:
	# Determine the number of columns in the grid container
	var num_columns = items_grid_container.columns
	var children_to_remove = []

	# Find and queue the row containing the matching item ID
	for i in range(items_grid_container.get_child_count()):
		var child = items_grid_container.get_child(i)
		if child is Label and child.text == item_id:
			var start_index = i - (i % num_columns)
			for j in range(num_columns):
				children_to_remove.append(items_grid_container.get_child(start_index + j))
			break

	# Remove and free the queued children
	for child in children_to_remove:
		items_grid_container.remove_child(child)
		child.queue_free()


# Refreshes the items list in the grid container
func update_item_list():
	# Clear existing items from the grid
	Helper.free_all_children(items_grid_container)

	if not dfurniture.crafting:
		return
	# Add items back into the grid
	for item_id in dfurniture.crafting.items:
		_handle_item_drop({"id":item_id})


# Check if the dragged item can be dropped into the construction_items_grid_container
func _can_construction_item_drop(_newpos: Vector2, data: Dictionary) -> bool:
	# Validate that data is a dictionary and contains the required "id" key
	if not data or not data.has("id"):
		return false

	# Validate that the item exists in Gamedata
	if not Gamedata.mods.by_id(data["mod_id"]).items.has_id(data["id"]):
		return false
	
	# Check for duplicate items in the grid container
	for child in construction_items_grid_container.get_children():
		if child is Label and child.text == data["id"]:
			return false  # Item already exists

	return true  # Passed all validation checks

# Handle the drop of an item into the construction_items_grid_container
func _construction_item_drop(_newpos: Vector2, data: Dictionary) -> void:
	# Validate if the item can be dropped
	if not _can_construction_item_drop(_newpos, data):
		return

	# Handle the drop and add the item to the grid
	_handle_construction_item_drop(data)

# Function to handle adding the dropped item to the construction grid container
func _handle_construction_item_drop(dropped_data: Dictionary) -> void:
	# Retrieve item details from Gamedata
	var item_id = dropped_data["id"]
	var item_sprite = Gamedata.mods.get_content_by_id(DMod.ContentType.ITEMS, item_id).sprite

	# Create components for the dropped item row
	var item_icon = TextureRect.new()
	item_icon.texture = item_sprite
	item_icon.custom_minimum_size = Vector2(32, 32)  # Ensure a minimum size for the icon

	var item_label = Label.new()
	item_label.text = item_id

	var delete_button = Button.new()
	delete_button.text = "X"
	delete_button.tooltip_text = "Remove this item"
	delete_button.button_up.connect(_on_delete_construction_item_button_pressed.bind(item_id))

	# Add components to the grid container
	construction_items_grid_container.add_child(item_icon)
	construction_items_grid_container.add_child(item_label)
	construction_items_grid_container.add_child(delete_button)

	# Ensure the construction items are properly recorded
	if not dfurniture.construction:
		dfurniture.construction = {}  # Initialize if not already present
	if not dfurniture.construction.items:
		dfurniture.construction.items = []
	dfurniture.construction.items.append(item_id)

# Handle the deletion of an item from the construction_items_grid_container
func _on_delete_construction_item_button_pressed(item_id: String) -> void:
	# Determine the number of columns in the grid container
	var num_columns = construction_items_grid_container.columns
	var children_to_remove = []

	# Find and queue the row containing the matching item ID
	for i in range(construction_items_grid_container.get_child_count()):
		var child = construction_items_grid_container.get_child(i)
		if child is Label and child.text == item_id:
			var start_index = i - (i % num_columns)
			for j in range(num_columns):
				children_to_remove.append(construction_items_grid_container.get_child(start_index + j))
			break

	# Remove and free the queued children
	for child in children_to_remove:
		construction_items_grid_container.remove_child(child)
		child.queue_free()

	# Remove the item ID from dfurniture.construction.items
	if dfurniture.construction and dfurniture.construction.items:
		dfurniture.construction.items.erase(item_id)


# Refreshes the items list in the construction grid container
func update_construction_item_list():
	# Clear existing items from the grid
	Helper.free_all_children(construction_items_grid_container)

	if not dfurniture.construction or not dfurniture.construction.items:
		return

	# Add items back into the grid
	for item_id in dfurniture.construction.items:
		_handle_construction_item_drop({"id": item_id})


# Saves the crafting items from items_grid_container into dfurniture.crafting.items
func save_crafting_items():
	var new_items: Array[String] = []
	var num_children = items_grid_container.get_child_count()
	var num_columns = items_grid_container.columns

	for i in range(0, num_children, num_columns):
		var item_label = items_grid_container.get_child(i + 1)  # Second child is the label with item ID
		if item_label is Label:
			new_items.append(item_label.text)

	dfurniture.crafting.items = new_items  # Update furniture's crafting item list

# Saves the construction items from construction_items_grid_container into dfurniture.construction.items
func save_construction_items():
	var new_items: Array[String] = []
	var num_children = construction_items_grid_container.get_child_count()
	var num_columns = construction_items_grid_container.columns

	for i in range(0, num_children, num_columns):
		var item_label = construction_items_grid_container.get_child(i + 1)  # Second child is the label with item ID
		if item_label is Label:
			new_items.append(item_label.text)

	if not dfurniture.construction:
		dfurniture.construction = {}  # Initialize if not present
	dfurniture.construction.items = new_items  # Update furniture's construction item list
