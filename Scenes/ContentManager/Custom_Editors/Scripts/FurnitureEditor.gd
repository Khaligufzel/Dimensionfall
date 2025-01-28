extends Control

# This scene is for editing a single piece of furniture.
# It loads and saves data to a JSON file containing furniture data for a mod.
# Provide the name of the furniture data file and an ID to load.

# -------------------------------
# Exported Variables (UI Elements)
# -------------------------------
@export_group("General Metadata")
@export var tab_container: TabContainer
@export var furniture_image_display: TextureRect
@export var id_label: Label
@export var name_edit: TextEdit
@export var description_edit: TextEdit
@export var categories_list: Control
@export var furniture_selector: Popup
@export var image_name_label: Label
@export var moveable_checkbox: CheckBox
@export var weight_label: Label = null
@export var weight_spinbox: SpinBox
@export var edge_snapping_option: OptionButton
@export var door_option: OptionButton

@export_group("Container Settings")
@export var container_checkbox: CheckBox
@export var container_text_edit: HBoxContainer
@export var regeneration_label: Label = null
@export var regeneration_spin_box: SpinBox
@export var sprite_mode_option_button: OptionButton

@export_group("Destruction Settings")
@export var destroy_container: HBoxContainer
@export var can_destroy_checkbox: CheckBox
@export var destruction_text_edit: HBoxContainer
@export var destruction_image_display: TextureRect
@export var destruction_sprite_label: Label

@export_group("Disassembly Settings")
@export var disassembly_container: HBoxContainer
@export var can_disassemble_checkbox: CheckBox
@export var disassembly_text_edit: HBoxContainer
@export var disassembly_image_display: TextureRect
@export var disassembly_sprite_label: Label

@export_group("Support Shape")
@export var support_shape_option_button: OptionButton
@export var width_scale_label: Label = null
@export var depth_scale_label: Label = null
@export var radius_scale_label: Label = null
@export var width_scale_spin_box: SpinBox
@export var depth_scale_spin_box: SpinBox
@export var radius_scale_spin_box: SpinBox
@export var height_spin_box: SpinBox
@export var color_picker: ColorPicker
@export var sprite_texture_rect: TextureRect
@export var transparent_check_box: CheckBox

@export_group("CraftingConstruction")
@export var crafting_items_container: GridContainer
@export var construction_items_container: GridContainer

@export_group("Consumption Settings")
@export var pool_spin_box: SpinBox
@export var drain_rate_spin_box: SpinBox
@export var transform_into_text_edit: HBoxContainer
@export var button_text_edit: TextEdit
@export var consumption_items_grid_container: GridContainer

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
		_load_furniture_data()
		furniture_selector.sprites_collection = dfurniture.parent.sprites
		if not data_changed.is_connected(dfurniture.parent.on_data_changed):
			data_changed.connect(dfurniture.parent.on_data_changed)
		olddata = DFurniture.new(dfurniture.get_data().duplicate(true), null)


func _ready():
	# For properly using the tab key to switch elements
	control_elements = [furniture_image_display,name_edit,description_edit]
	#data_changed.connect(dfurniture.parent.on_data_changed)
	set_drop_functions()
	
	# Connect the toggle signal to the function
	moveable_checkbox.toggled.connect(_on_moveable_checkbox_toggled)
	crafting_items_container.set_drag_forwarding(Callable(), _can_item_drop, _item_drop)
	container_text_edit.text_changed.connect(_on_container_text_edit_text_changed)


# -------------------------
# Furniture Data Loading
# -------------------------
func _load_furniture_data():
	# Load and display furniture metadata
	_load_metadata()
	_update_categories()
	_load_destruction_data()
	_load_disassembly_data()
	_load_container_data()
	_load_support_shape_data()
	_load_consumption_data()
	# Refresh crafting and construction item lists
	update_item_list()
	update_construction_item_list()

func _load_metadata():
	# Populate general metadata
	id_label.text = dfurniture.id
	name_edit.text = dfurniture.name
	description_edit.text = dfurniture.description
	image_name_label.text = dfurniture.spriteid
	furniture_image_display.texture = dfurniture.sprite if dfurniture.sprite else null
	moveable_checkbox.button_pressed = dfurniture.moveable
	weight_spinbox.value = dfurniture.weight
	select_option_by_string(edge_snapping_option, dfurniture.edgesnapping)

func _load_destruction_data():
	# Load destruction-specific data
	if not dfurniture.destruction.get_data().is_empty():
		can_destroy_checkbox.button_pressed = true
		destruction_text_edit.set_text(dfurniture.destruction.group)
		destruction_image_display.texture = dfurniture.parent.sprite_by_file(dfurniture.destruction.sprite)
		destruction_sprite_label.text = dfurniture.destruction.sprite
		set_visibility_for_children(destroy_container, true)
	else:
		can_destroy_checkbox.button_pressed = false
		set_visibility_for_children(destroy_container, false)

func _load_disassembly_data():
	# Load disassembly-specific data
	if not dfurniture.disassembly.get_data().is_empty():
		can_disassemble_checkbox.button_pressed = true
		disassembly_text_edit.set_text(dfurniture.disassembly.group)
		disassembly_image_display.texture = dfurniture.parent.sprite_by_file(dfurniture.disassembly.sprite)
		disassembly_sprite_label.text = dfurniture.disassembly.sprite
		set_visibility_for_children(disassembly_container, true)
	else:
		can_disassemble_checkbox.button_pressed = false
		set_visibility_for_children(disassembly_container, false)

func _load_container_data():
	# Load container-specific data
	container_checkbox.button_pressed = dfurniture.function.is_container
	container_text_edit.set_text(dfurniture.function.container_group if dfurniture.function.container_group != "" else "")
	regeneration_spin_box.value = max(dfurniture.function.container_regeneration_time, -1.0)
	select_option_by_string(sprite_mode_option_button, dfurniture.function.container_sprite_mode)
	update_container_controls_visibility()

func _load_support_shape_data():
	# Load support shape-specific data
	var support_shape: DFurniture.SupportShape = dfurniture.support_shape
	select_option_by_string(support_shape_option_button, support_shape.shape)
	color_picker.color = Color.html(support_shape.color)
	transparent_check_box.button_pressed = support_shape.transparent
	height_spin_box.value = support_shape.height
	width_scale_spin_box.value = support_shape.width_scale
	depth_scale_spin_box.value = support_shape.depth_scale
	radius_scale_spin_box.value = support_shape.radius_scale
	_update_shape_visibility(support_shape.shape)


func _update_categories():
		categories_list.clear_list()
		for category in dfurniture.categories:
			categories_list.add_item_to_list(category)


func update_door_option(door_state):
	var items = door_option.get_item_count()
	for i in range(items):
		if door_option.get_item_text(i) == door_state or (door_state not in ["Open", "Closed"] and door_option.get_item_text(i) == "None"):
			door_option.selected = i
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
	dfurniture.spriteid = image_name_label.text
	dfurniture.sprite = furniture_image_display.texture
	dfurniture.name = name_edit.text
	dfurniture.description = description_edit.text
	dfurniture.categories = categories_list.get_items()
	dfurniture.moveable = moveable_checkbox.button_pressed
	dfurniture.weight = weight_spinbox.value
	dfurniture.edgesnapping = edge_snapping_option.get_item_text(edge_snapping_option.selected)

	# Handle saving or erasing the support shape data
	handle_support_shape_option()
	handle_door_option()
	handle_container_option()
	handle_destruction_option()
	handle_disassembly_option()
	# Save consumption values
	dfurniture.consumption.pool = int(pool_spin_box.value)
	dfurniture.consumption.drain_rate = int(drain_rate_spin_box.value)
	dfurniture.consumption.transform_into = transform_into_text_edit.get_text()
	dfurniture.consumption.button_text = button_text_edit.text

	# Save crafting and construction items
	_save_crafting_items()
	_save_construction_items()
	_save_consumption_items()

	dfurniture.on_data_changed(olddata)
	data_changed.emit()
	olddata = DFurniture.new(dfurniture.get_data().duplicate(true), null)


# Function to handle saving or erasing the support shape data
func handle_support_shape_option():
	if not moveable_checkbox.button_pressed:
		var shape = support_shape_option_button.get_item_text(support_shape_option_button.selected)
		dfurniture.support_shape.shape = shape
		dfurniture.support_shape.height = height_spin_box.value
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
	var door_state = door_option.get_item_text(door_option.selected)
	dfurniture.function.door = door_state


func handle_container_option():
	if container_checkbox.is_pressed():
		dfurniture.function.is_container = true
		dfurniture.function.container_group = container_text_edit.get_text()
		# Save the regeneration time
		dfurniture.function.container_regeneration_time = regeneration_spin_box.value
		# Save the selected sprite mode
		dfurniture.function.container_sprite_mode = sprite_mode_option_button.get_item_text(sprite_mode_option_button.selected)
	else:
		dfurniture.function.is_container = false
		dfurniture.function.container_group = ""
		# Reset the regeneration time
		dfurniture.function.container_regeneration_time = -1
		# Reset the sprite mode to default
		dfurniture.function.container_sprite_mode = "default"


func handle_destruction_option():
	if can_destroy_checkbox.is_pressed():
		dfurniture.destruction.group = destruction_text_edit.get_text()
		dfurniture.destruction.sprite = destruction_sprite_label.text
	else:
		dfurniture.destruction.group = ""
		dfurniture.destruction.sprite = ""


func handle_disassembly_option():
	if can_destroy_checkbox.is_pressed():
		dfurniture.disassembly.group = disassembly_text_edit.get_text()
		dfurniture.disassembly.sprite = disassembly_sprite_label.text
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


# The user has checked the 'container' checkbox
# Since some functionality relies on the furniture being a container,
# We need to hide the controls if this furniture is not a container.
func _on_container_check_box_toggled(toggled_on: bool):
	# Clear the text field if the container checkbox is toggled off
	if not toggled_on:
		container_text_edit.mytextedit.clear()
	
	# Find the tab index for the "Consumption" tab
	var tabIndex = get_tab_by_title("Consumption")
	if tabIndex != -1:  # Check if a valid tab index is returned
		tab_container.set_tab_hidden(tabIndex, !toggled_on)  # Hide or show the tab


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
		if texteditcontrol == container_text_edit:
			container_checkbox.button_pressed = true
		if texteditcontrol == destruction_text_edit:
			can_destroy_checkbox.button_pressed = true
		if texteditcontrol == disassembly_text_edit:
			can_disassemble_checkbox.button_pressed = true
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
	container_text_edit.drop_function = itemgroup_drop.bind(container_text_edit)
	container_text_edit.can_drop_function = can_itemgroup_drop
	disassembly_text_edit.drop_function = itemgroup_drop.bind(disassembly_text_edit)
	disassembly_text_edit.can_drop_function = can_itemgroup_drop
	destruction_text_edit.drop_function = itemgroup_drop.bind(destruction_text_edit)
	destruction_text_edit.can_drop_function = can_itemgroup_drop
	
	construction_items_container.set_drag_forwarding(Callable(), _can_construction_item_drop, _construction_item_drop)
	consumption_items_grid_container.set_drag_forwarding(Callable(), _can_consumption_item_drop, _consumption_item_drop)
	# Assign drop functions for transform_into_text_edit
	transform_into_text_edit.drop_function = furniture_drop.bind(transform_into_text_edit)
	transform_into_text_edit.can_drop_function = can_furniture_drop


# When the furniture_image_display is clicked, the user will be prompted to select an image from
# "res://Mods/Core/Furnitures/". The texture of the furniture_image_display will change to the selected image
func _on_furniture_image_display_gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		current_image_display = "furniture"
		furniture_selector.show()

func _on_disassemble_image_display_gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		current_image_display = "disassemble"
		furniture_selector.show()

func _on_destruction_image_display_gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		current_image_display = "destruction"
		furniture_selector.show()

func _on_sprite_selector_sprite_selected_ok(clicked_sprite) -> void:
	var furnitureTexture: Resource = clicked_sprite.get_texture()
	if current_image_display == "furniture":
		furniture_image_display.texture = furnitureTexture
		image_name_label.text = furnitureTexture.resource_path.get_file()
		update_sprite_texture_rect(furnitureTexture)
	elif current_image_display == "disassemble":
		disassembly_image_display.texture = furnitureTexture
		disassembly_sprite_label.text = furnitureTexture.resource_path.get_file()
	elif current_image_display == "destruction":
		destruction_image_display.texture = furnitureTexture
		destruction_sprite_label.text = furnitureTexture.resource_path.get_file()


# Utility function to set the visibility of all children of the given container except the first one
func set_visibility_for_children(container: Control, isvisible: bool):
	for i in range(1, container.get_child_count()):
		container.get_child(i).visible = isvisible

func _on_can_destroy_check_box_toggled(toggled_on):
	if not toggled_on:
		destruction_text_edit.mytextedit.clear()
		destruction_sprite_label.text = ""
		destruction_image_display.texture = load("res://Scenes/ContentManager/Mapeditor/Images/emptyTile.png")
	set_visibility_for_children(destroy_container, toggled_on)

func _on_can_disassemble_check_box_toggled(toggled_on):
	if not toggled_on:
		disassembly_text_edit.mytextedit.clear()
		disassembly_sprite_label.text = ""
		disassembly_image_display.texture = load("res://Scenes/ContentManager/Mapeditor/Images/emptyTile.png")
	set_visibility_for_children(disassembly_container, toggled_on)


# Function to handle the toggle state of the checkbox
func _on_moveable_checkbox_toggled(button_pressed):
	weight_label.visible = button_pressed
	weight_spinbox.visible = button_pressed


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


# Check if the dragged item can be dropped into the crafting_items_container
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
	for child in crafting_items_container.get_children():
		if child is Label and child.text == data["id"]:
			return false  # Item already exists

	return true  # Passed all validation checks


# Handle the drop of an item into the crafting_items_container
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
	crafting_items_container.add_child(item_icon)
	crafting_items_container.add_child(item_label)
	crafting_items_container.add_child(delete_button)

	# Ensure the furniture is marked as a container
	if not dfurniture.function.is_container:
		dfurniture.function.is_container = true
		container_checkbox.button_pressed = true  # Reflect the change in the UI


# Handle the deletion of an item from the crafting_items_container
func _on_delete_item_button_pressed(item_id: String) -> void:
	# Determine the number of columns in the grid container
	var num_columns = crafting_items_container.columns
	var children_to_remove = []

	# Find and queue the row containing the matching item ID
	for i in range(crafting_items_container.get_child_count()):
		var child = crafting_items_container.get_child(i)
		if child is Label and child.text == item_id:
			var start_index = i - (i % num_columns)
			for j in range(num_columns):
				children_to_remove.append(crafting_items_container.get_child(start_index + j))
			break

	# Remove and free the queued children
	for child in children_to_remove:
		crafting_items_container.remove_child(child)
		child.queue_free()


# Refreshes the items list in the grid container
func update_item_list():
	# Clear existing items from the grid
	Helper.free_all_children(crafting_items_container)

	if not dfurniture.crafting:
		return
	# Add items back into the grid
	for item_id in dfurniture.crafting.items:
		_handle_item_drop({"id":item_id})


# Check if the dragged item can be dropped into the construction_items_container
func _can_construction_item_drop(_newpos: Vector2, data: Dictionary) -> bool:
	# Validate that data is a dictionary and contains the required "id" key
	if not data or not data.has("id"):
		return false

	# Validate that the item exists in Gamedata
	if not Gamedata.mods.by_id(data["mod_id"]).items.has_id(data["id"]):
		return false
	
	# Check for duplicate items in the grid container
	for child in construction_items_container.get_children():
		if child is Label and child.text == data["id"]:
			return false  # Item already exists

	return true  # Passed all validation checks

# Handle the drop of an item into the construction_items_container
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

	# Add a SpinBox to allow setting the required amount
	var amount_spinbox = SpinBox.new()
	amount_spinbox.min_value = 1
	amount_spinbox.value = dfurniture.construction.items.get(item_id, 1)  # Default to 1 if not set
	amount_spinbox.custom_minimum_size = Vector2(50, 32)

	var delete_button = Button.new()
	delete_button.text = "X"
	delete_button.tooltip_text = "Remove this item"
	delete_button.button_up.connect(_on_delete_construction_item_button_pressed.bind(item_id))

	# Add components to the grid container
	construction_items_container.add_child(item_icon)
	construction_items_container.add_child(item_label)
	construction_items_container.add_child(amount_spinbox)
	construction_items_container.add_child(delete_button)



# Handle the deletion of an item from the construction_items_container
func _on_delete_construction_item_button_pressed(item_id: String) -> void:
	# Determine the number of columns in the grid container
	var num_columns = construction_items_container.columns
	var children_to_remove = []

	# Find and queue the row containing the matching item ID
	for i in range(construction_items_container.get_child_count()):
		var child = construction_items_container.get_child(i)
		if child is Label and child.text == item_id:
			var start_index = i - (i % num_columns)
			for j in range(num_columns):
				children_to_remove.append(construction_items_container.get_child(start_index + j))
			break

	# Remove and free the queued children
	for child in children_to_remove:
		construction_items_container.remove_child(child)
		child.queue_free()

	# Remove the item ID from dfurniture.construction.items
	if dfurniture.construction and dfurniture.construction.items:
		dfurniture.construction.items.erase(item_id)


# Refreshes the items list in the construction grid container
func update_construction_item_list():
	# Clear existing items from the grid
	Helper.free_all_children(construction_items_container)

	if not dfurniture.construction or not dfurniture.construction.items:
		return

	# Add items back into the grid
	for item_id in dfurniture.construction.items.keys():
		_handle_construction_item_drop({"id": item_id})


# Saves the crafting items from crafting_items_container into dfurniture.crafting.items
func _save_crafting_items():
	dfurniture.crafting.items = _extract_items_from_container(crafting_items_container)

# Saves the construction items from construction_items_container into dfurniture.construction.items
func _save_construction_items():
	var new_items: Dictionary = {}
	var num_children = construction_items_container.get_child_count()
	var num_columns = construction_items_container.columns

	for i in range(0, num_children, num_columns):
		var item_label = construction_items_container.get_child(i + 1)  # Second child is the label with item ID
		var amount_spinbox = construction_items_container.get_child(i + 2)  # Third child is the SpinBox
		if item_label is Label and amount_spinbox is SpinBox:
			new_items[item_label.text] = int(amount_spinbox.value)

	dfurniture.construction.items = new_items  # Update furniture's construction items


func _extract_items_from_container(container: GridContainer) -> Array:
	var items = []
	for child in container.get_children():
		if child is Label:
			items.append(child.text)
	return items


func update_container_controls_visibility():
	# Check if container_text_edit has a value
	var has_value = container_text_edit.get_text() != ""
	
	# Toggle visibility based on value
	regeneration_label.visible = has_value
	regeneration_spin_box.visible = has_value


func _on_container_text_edit_text_changed(_new_text: String):
	update_container_controls_visibility()


# ----------------------------
# Utility and Helper Functions
# ----------------------------
func set_child_visibility(container: Control, isvisible: bool):
	# Set visibility for all child nodes
	for i in range(container.get_child_count()):
		container.get_child(i).visible = isvisible

func _update_shape_visibility(shape: String):
	# Adjust UI visibility based on selected shape type
	var is_box = shape == "Box"
	width_scale_label.visible = is_box
	depth_scale_label.visible = is_box
	width_scale_spin_box.visible = is_box
	depth_scale_spin_box.visible = is_box
	radius_scale_label.visible = not is_box
	radius_scale_spin_box.visible = not is_box


func _load_consumption_data():
	# Load values from dfurniture.consumption
	pool_spin_box.value = dfurniture.consumption.pool
	drain_rate_spin_box.value = dfurniture.consumption.drain_rate
	transform_into_text_edit.set_text(dfurniture.consumption.transform_into)
	button_text_edit.text = dfurniture.consumption.button_text
	_load_consumption_items()


func _load_consumption_items():
	# Clear existing items from the grid
	Helper.free_all_children(consumption_items_grid_container)

	if not dfurniture.consumption or not dfurniture.consumption.items:
		return

	# Add items back into the grid
	for item_id in dfurniture.consumption.items.keys():
		_handle_consumption_item_drop({"id": item_id})

# Check if the dragged item can be dropped into the consumption_items_grid_container
func _can_consumption_item_drop(_newpos: Vector2, data: Dictionary) -> bool:
	# Validate that data is a dictionary and contains the required "id" key
	if not data or not data.has("id"):
		return false

	# Validate that the item exists in Gamedata
	if not Gamedata.mods.by_id(data["mod_id"]).items.has_id(data["id"]):
		return false
	
	# Check for duplicate items in the grid container
	for child in consumption_items_grid_container.get_children():
		if child is Label and child.text == data["id"]:
			return false  # Item already exists

	return true  # Passed all validation checks

# Handle the drop of an item into the consumption_items_grid_container
func _consumption_item_drop(_newpos: Vector2, data: Dictionary) -> void:
	# Validate if the item can be dropped
	if not _can_consumption_item_drop(_newpos, data):
		return

	# Handle the drop and add the item to the grid
	_handle_consumption_item_drop(data)

# Function to handle adding the dropped item to the consumption grid container
func _handle_consumption_item_drop(dropped_data: Dictionary) -> void:
	# Retrieve item details from Gamedata
	var item_id = dropped_data["id"]
	var item_sprite = Gamedata.mods.get_content_by_id(DMod.ContentType.ITEMS, item_id).sprite

	# Create components for the dropped item row
	var item_icon = TextureRect.new()
	item_icon.texture = item_sprite
	item_icon.custom_minimum_size = Vector2(32, 32)  # Ensure a minimum size for the icon

	var item_label = Label.new()
	item_label.text = item_id

	# Add a SpinBox to allow setting the required amount
	var amount_spinbox = SpinBox.new()
	amount_spinbox.min_value = 1
	amount_spinbox.value = dfurniture.consumption.items.get(item_id, 1)  # Default to 1 if not set
	amount_spinbox.custom_minimum_size = Vector2(50, 32)
	amount_spinbox.tooltip_text = "The 'fuel value' that will be added to the pool when" + \
								  "  the item is consumed. The consumption of items will" + \
								  "  automatically start when the current value of the\n" + \
								  "  pool is below maximum. This requires that the pool" + \
								  "  has space for the amount of fuel this item provides.\n" + \
								  "  For example, if the current pool value is 990 and " + \
								  " the max pool size is 1000, only items with a fuel \n" + \
								  " value of 10 or less will be consumed. When an item is " + \
								  " consumed, it is removed from the furniture's inventory and destroyed."

	var delete_button = Button.new()
	delete_button.text = "X"
	delete_button.tooltip_text = "Remove this item"
	delete_button.button_up.connect(_on_delete_consumption_item_button_pressed.bind(item_id))

	# Add components to the grid container
	consumption_items_grid_container.add_child(item_icon)
	consumption_items_grid_container.add_child(item_label)
	consumption_items_grid_container.add_child(amount_spinbox)
	consumption_items_grid_container.add_child(delete_button)


# Handle the deletion of an item from the consumption_items_grid_container
func _on_delete_consumption_item_button_pressed(item_id: String) -> void:
	# Determine the number of columns in the grid container
	var num_columns = consumption_items_grid_container.columns
	var children_to_remove = []

	# Find and queue the row containing the matching item ID
	for i in range(consumption_items_grid_container.get_child_count()):
		var child = consumption_items_grid_container.get_child(i)
		if child is Label and child.text == item_id:
			var start_index = i - (i % num_columns)
			for j in range(num_columns):
				children_to_remove.append(consumption_items_grid_container.get_child(start_index + j))
			break

	# Remove and free the queued children
	for child in children_to_remove:
		consumption_items_grid_container.remove_child(child)
		child.queue_free()

	# Remove the item ID from dfurniture.consumption.items
	if dfurniture.consumption and dfurniture.consumption.items:
		dfurniture.consumption.items.erase(item_id)

func _save_consumption_items():
	var new_items: Dictionary = {}
	var num_children = consumption_items_grid_container.get_child_count()
	var num_columns = consumption_items_grid_container.columns

	for i in range(0, num_children, num_columns):
		var item_label = consumption_items_grid_container.get_child(i + 1)  # Second child is the label with item ID
		var amount_spinbox = consumption_items_grid_container.get_child(i + 2)  # Third child is the SpinBox
		if item_label is Label and amount_spinbox is SpinBox:
			new_items[item_label.text] = int(amount_spinbox.value)

	dfurniture.consumption.items = new_items  # Update furniture's consumption items

# Called when the user drops a furniture ID onto the TextEdit
func furniture_drop(dropped_data: Dictionary, texteditcontrol: HBoxContainer) -> void:
	# Assuming dropped_data is a Dictionary that includes an 'id'
	if dropped_data and "id" in dropped_data:
		var furniture_id = dropped_data["id"]
		# Validate that the furniture ID exists in the current mod
		if not Gamedata.mods.by_id(dropped_data["mod_id"]).furnitures.has_id(furniture_id):
			print_debug("No furniture data found for ID: " + furniture_id)
			return
		texteditcontrol.set_text(furniture_id)  # Set the furniture ID into the TextEdit
	else:
		print_debug("Dropped data does not contain an 'id' key.")

# Check if the dropped data is valid for assigning a furniture ID
func can_furniture_drop(dropped_data: Dictionary) -> bool:
	# Validate that the data is a dictionary and contains the 'id' property
	if not dropped_data or not dropped_data.has("id"):
		return false

	# Validate that the furniture ID exists in the current mod
	if not Gamedata.mods.by_id(dropped_data["mod_id"]).furnitures.has_id(dropped_data["id"]):
		return false

	return true  # Passed all validation checks



# Returns the tab control with the given name
func get_tab_by_title(tabName: String) -> int:
	# Loop over all children of the types_container
	for i in range(tab_container.get_tab_count()):
		if tab_container.get_tab_title(i) == tabName:
			return i
	return -1
