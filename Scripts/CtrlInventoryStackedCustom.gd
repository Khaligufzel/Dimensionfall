extends Control

# This script is intended to be used with CtrlInventoryStackedCustom
# It will display inventory items with their properties in a ItemList displayed as a grid
# The first row in the grid will be the header
# Below the header will be a list it inventory items
# The first column will have the item's icon
# The second column will have the item's name
# The third column will have the item's weight
# The fourth column will have the item's volume
# The fifth column will show if an item is favorited
# Clicking on a header column will sort the grid's items by that column
# There will be variables and functions to keep track of the inventory's weight and volume capacity
# There will be functions to update the weightbar and volumebar when the weight and volume changes
# There will be signals for when items get added and removed and when the list is sorted and cleared
# There will be functions to update the list and to populate the list
# There will be signals for when the inventory reaches capacity and when it is empty
# When the mouse hovers over an item, it will be highlighted
# The user will be able to select items. Selected items will be highlighted also, but in a different color
# There will be signals for when an item is selected and when multiple items are selected
# The user will be able to drag the cursor over items while pressing the left mouse button, this will allow the user to select multiple items
# Items can be dragged from the list to other controls in the interface
# The user will be able to favorite an item in the list by selecting it and pressing F.


@export var inventoryGrid: GridContainer
@export var WeightBar: ProgressBar
@export var VolumeBar: ProgressBar
@export var myInventory: InventoryStacked
@export var max_weight: int = 1000
@export var max_volume: int = 1000
@export var listItemContainer: PackedScene
@export var listHeaderContainer: PackedScene
# Context menu that will show actions for selected items
@export var context_menu: PopupMenu

var selectedItem: InventoryItem = null
var selectedItems: Array = []
var last_selected_item: Control = null
var group_to_item_mapping: Dictionary = {}
var group_controls: Dictionary = {}
var last_hovered_item: Node = null


# Dictionary to store header controls
var header_controls: Dictionary = {}
var selected_header: String = ""
var header_sort_order: Dictionary = {}

signal item_selected(item)
signal items_selected(items)
signal inventory_sorted(column)
signal inventory_updated
signal inventory_reached_capacity
signal inventory_empty


# Signals for context menu actions
signal equip_left(items)
signal equip_right(items)
signal drop_item(items)
signal wear_item(items)
signal disassemble_item(items)

func _ready():
	_populate_inventory_list()
	_update_bars()
	_connect_inventory_signals()


# Take care of the hovering over items in the grid
func _process(_delta):
	var mouse_pos = get_global_mouse_position()
	var hovered_item = get_hovered_item(mouse_pos)

	if hovered_item != last_hovered_item:
		if last_hovered_item and is_instance_valid(last_hovered_item):
			_remove_highlight(last_hovered_item)
		if hovered_item:
			_apply_highlight(hovered_item)
		last_hovered_item = hovered_item

func get_hovered_item(mouse_pos: Vector2) -> Node:
	for child in inventoryGrid.get_children():
		if child is Control and child.get_global_rect().has_point(mouse_pos):
			return child
	return null

func _apply_highlight(item: Control):
	var group_name = _get_group_name(item)
	if group_controls.has(group_name):
		for control in group_controls[group_name]:
			if is_instance_valid(control):
				control.highlight()

func _remove_highlight(item: Control):
	var group_name = _get_group_name(item)
	if group_controls.has(group_name):
		for control in group_controls[group_name]:
			if is_instance_valid(control):
				control.unhighlight()

# Function to show context menu at specified position
func show_context_menu(myposition: Vector2):
	# Create a small Rect2i around the position
	var popup_rect = Rect2i(int(myposition.x), int(myposition.y), 1, 1)
	context_menu.popup(popup_rect)


# Handle context menu item selection
func _on_context_menu_item_selected(id):
	var selected_inventory_items = get_selected_inventory_items()
	match id:
		0: equip_left.emit(selected_inventory_items)
		1: equip_right.emit(selected_inventory_items)
		2: emit_signal("drop_item", selected_inventory_items)
		3: emit_signal("wear_item", selected_inventory_items)
		4: emit_signal("disassemble_item", selected_inventory_items)

func _connect_inventory_signals():
	# Connect signals from InventoryStacked to this control script
	myInventory.connect("item_added", _on_inventory_item_added)
	myInventory.connect("item_removed", _on_inventory_item_removed)
	myInventory.connect("item_modified", _on_inventory_item_modified)
	myInventory.connect("contents_changed", _on_inventory_contents_changed)

func _on_inventory_item_added(item: InventoryItem):
	# Handle item added to inventory
	update_inventory_list(item, "added")

func _on_inventory_item_removed(item: InventoryItem):
	# Handle item removed from inventory
	update_inventory_list(item, "removed")

func _on_inventory_item_modified(item: InventoryItem):
	# Handle item modified in inventory
	update_inventory_list(item, "modified")

func _on_inventory_contents_changed():
	# Handle inventory contents changed
	update_inventory_list(null,"contentschanged")

func update_inventory_list(changedItem: InventoryItem, action: String):
	# Clear and repopulate the inventory list
	_clear_grid_children()
	_add_header_row_to_grid()
	for item in myInventory.get_children():
		var add_item: bool = true
		if item and item == changedItem:
			match action:
				"added":
					print_debug("item was added")
				"removed":
					print_debug("item was removed")
					add_item = false
				"modified":
					print_debug("item was modified")
				_, "contentschanged":
					print_debug("contents was changed")
		if add_item:
			var group_name = "item_group_" + str(item.get_name())
			group_to_item_mapping[group_name] = item
			_add_item_to_grid(item, group_name)
	_update_bars()

# Gets the group name from an item
# An item is a control element in the inventory grid
func _get_group_name(item: Control) -> String:
	for group in item.get_groups():
		if group.begins_with("item_group_"):
			return group
	return ""

# Helper function to create a header
func _create_header(text: String) -> void:
	var header: Control = listHeaderContainer.instantiate()
	header.set_label_text(text)
	header.connect("header_clicked", _on_header_clicked)
	inventoryGrid.add_child(header)
	# Store the header control in the dictionary
	header_controls[text] = header

# Simplified function for adding headers
func _add_header_row_to_grid():
	_create_header("I")	
	_create_header("Name")
	_create_header("W")
	_create_header("V")
	_create_header("F")
	
func _on_item_right_clicked(clickedItem: Control):
	show_context_menu(clickedItem.global_position)

# When an item in the inventory is clicked
# There are 5 items per row in the grid, but they are treated as a group of 5
# So clicking one item will select the whole row
func _on_item_clicked(clickedItem: Control):
	var group_name = _get_group_name(clickedItem)
	
	if Input.is_key_pressed(KEY_CTRL):
		# CTRL is held: check if current group is selected and if there are other groups selected
		if _is_group_selected(group_name) and selectedItems.size() > 1:
			# Deselect the current group
			_toggle_group_selection(group_name, false)
		else:
			_toggle_group_selection(group_name, clickedItem.is_item_selected())
	elif Input.is_key_pressed(KEY_SHIFT) and last_selected_item:
		# SHIFT is held: select a range of items
		_select_range(last_selected_item, clickedItem)
	else:
		# No modifier key: select or deselect the clicked group
		# Check if the clicked item's group is selected
		if not _is_group_selected(group_name):
			if selectedItems.size() == 1 and selectedItems[0] == group_name:
				_toggle_group_selection(group_name, false) # De-select
			else:
				# More then one group is selected
				# Deselect all other items and select the clicked group
				for selected_group in selectedItems.duplicate():
					_toggle_group_selection(selected_group, false)
				_toggle_group_selection(group_name, true)

	# Update last selected item
	last_selected_item = clickedItem

# Select a range of items. This is called when the user
# selects an item and then holds shift and selects another item
func _select_range(start_item: Control, end_item: Control):
	var start_group_name = _get_group_name(start_item)
	var end_group_name = _get_group_name(end_item)

	var start_index = _find_group_start_index(start_group_name)
	var end_index = _find_group_start_index(end_group_name)

	var min_index = min(start_index, end_index)
	var max_index = max(start_index, end_index)

	for i in range(min_index, max_index + 1):
		var item = inventoryGrid.get_child(i)
		if item:
			var group_name = _get_group_name(item)
			if group_controls.has(group_name):
				_toggle_group_selection(group_name, true)

# Find the index of the first item in a group
func _find_group_start_index(group_name: String) -> int:
	for i in range(inventoryGrid.get_child_count()):
		var item = inventoryGrid.get_child(i)
		if item and _get_group_name(item) == group_name:
			return i
	return -1

# Generic function to create an item in the grid
func _create_ui_element(property: String, item: InventoryItem, group_name: String) -> Control:
	var element = listItemContainer.instantiate() as Control
	match property:
		"icon":
			element.set_icon(item.get_texture())
			element.custom_minimum_size = Vector2(32, 32)
		"name":
			element.set_label_text(item.get_title())
			# We give the most space to the name, expand it horizontally
			element.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_, "weight", "volume", "favorite":
			# Fill in the value for the rest of the properties
			element.set_label_text(str(item.get_property(property, 0)))
	# The name will be something like weight_Node_211748 or icon_Node_211748
	# Now we can use the name to get information about the property
	element.name = property + "_" + str(item.get_name())
	element.connect("item_clicked", _on_item_clicked)
	element.connect("item_right_clicked", _on_item_right_clicked)
	# We use groups to keep track of the items
	element.add_to_group(group_name)
	return element

# Refactored function to add an item to the grid
func _add_item_to_grid(item: InventoryItem, group_name: String):
	# Each item has these 5 columns to fill, so we loop over each of the properties
	for property in ["icon", "name", "weight", "volume", "favorite"]:
		var element = _create_ui_element(property, item, group_name)
		inventoryGrid.add_child(element)
		# Keep track of the list items by group name
		if not group_controls.has(group_name):
			group_controls[group_name] = []
		group_controls[group_name].append(element)

# Populate the inventory list
func _populate_inventory_list():
	_clear_grid_children()
	# Add header
	_add_header_row_to_grid()
	# Loop over inventory items and add them to the grid
	for item in myInventory.get_children():
		var group_name = "item_group_" + str(item.get_name())
		group_to_item_mapping[group_name] = item
		_add_item_to_grid(item, group_name)

func _update_bars():
	var total_weight = 0
	var total_volume = 0
	for item in myInventory.get_children():
		total_weight += item.get_property("weight", 0) 
		total_volume += item.get_property("volume", 0)

	WeightBar.value = total_weight
	WeightBar.max_value = max_weight
	VolumeBar.value = total_volume
	VolumeBar.max_value = max_volume

	_check_inventory_capacity()

func _check_inventory_capacity():
	var is_full = WeightBar.value >= WeightBar.max_value or VolumeBar.value >= VolumeBar.max_value
	var is_empty = myInventory.get_child_count() == 0
	emit_signal("inventory_updated")
	if is_full:
		emit_signal("inventory_reached_capacity")
	if is_empty:
		emit_signal("inventory_empty")

func _sort_items(a, b):
	var value_a = a["sort_value"]
	var value_b = b["sort_value"]
	if typeof(value_a) == TYPE_STRING:
		return value_a.nocasecmp_to(value_b) < 0
	else:
		return value_a < value_b

# When a header is clicked, we will apply sorting to that column
func _on_header_clicked(headerItem: Control) -> void:
	var header_mapping = {"I": "icon", "Name": "name", "W": "weight", "V": "volume", "F": "favorite"}
	var header_label = headerItem.get_label_text()

	var reverse_order = false
	if selected_header == header_label and header_label in header_sort_order:
		# Reverse the sort order if the same header is clicked again
		reverse_order = !header_sort_order[header_label]

	if selected_header != header_label:
		# Update the visual state of the previously selected header
		if selected_header in header_controls:
			header_controls[selected_header].unselect_item()
		selected_header = header_label
		headerItem.select_item()

	if header_label in header_mapping:
		_sort_inventory_by_property(header_mapping[header_label], reverse_order)
		header_sort_order[header_label] = reverse_order

func _clear_grid_children():
	while inventoryGrid.get_child_count() > 0:
		var child = inventoryGrid.get_child(0)
		inventoryGrid.remove_child(child)
		child.queue_free()

func _sort_groups(a, b):
	var value_a = a["sort_value"]
	var value_b = b["sort_value"]
	print("Comparing: ", value_a, " with ", value_b)  # Debugging line
	if typeof(value_a) == TYPE_STRING:
		return value_a.nocasecmp_to(value_b) < 0
	else:
		return value_a < value_b

# Returns the value of the provided property for the provided group
# Essentially, the group_name is a row and the property_name is a column in the grid
func _get_representative_value_for_group(group_name: String, property_name: String):
	if group_to_item_mapping.has(group_name):
		var group_item = group_to_item_mapping[group_name]
		if group_item:
			var property_value = group_item.get_property(property_name, null)
			if property_value != null:
				return property_value
	# Return a default value based on the property type
	if property_name == "name" or property_name == "favorite":
		return ""  # Default value for string properties
	else:
		return 0  # Default value for numeric properties

# Will sort the order of the items baased on the selected column (property_name)
func _sort_inventory_by_property(property_name: String, reverse_order: bool = false):
	var sorted_groups = _get_sorted_groups(property_name)
	if reverse_order:
		sorted_groups.reverse()  # Reverse the order of the sorted groups
	for group_name in sorted_groups:
		_move_group_to_end(group_name)
	emit_signal("inventory_sorted", property_name)

func _move_group_to_end(group_name: String):
	for control in group_controls[group_name]:
		inventoryGrid.move_child(control, inventoryGrid.get_child_count() - 1)

# Constructs an array of the group name and the provided property
# The group_data is essentially all the rows in the grid
# The property_name is the column of the grid
# With this new array of group_name and property_name, the items can be sorted
func _get_sorted_groups(property_name: String) -> Array:
	var group_data = []
	for group_name in group_controls.keys():
		var representative_value = _get_representative_value_for_group(group_name, property_name)
		group_data.append({"group_name": group_name, "sort_value": representative_value})
	
	group_data.sort_custom(_sort_groups)
	
	var sorted_group_names = []
	for gd in group_data:
		sorted_group_names.append(gd["group_name"])
	
	return sorted_group_names

# A group is made up of 5 items (a row).
# This will select or deselect a group
func _toggle_group_selection(group_name: String, select: bool):
	if group_controls.has(group_name):
		for control in group_controls[group_name]:
			if is_instance_valid(control):
				if select:
					control.select_item()
				else:
					control.unselect_item()
		if select:
			selectedItems.append(group_name)
		else:
			selectedItems.erase(group_name)

# If any of the controls is un-selected, the group is not selected
# Otherwise the group is selected
func _is_group_selected(group_name: String) -> bool:
	if group_controls.has(group_name):
		for control in group_controls[group_name]:
			if is_instance_valid(control) and not control.is_item_selected():
				return false
		return true
	return false

# Transfer an item to another inventory associated with a Control node
func transfer(item: InventoryItem, destinationControl: Control) -> bool:
	var destinationInventory = _get_inventory_from_control(destinationControl)
	if destinationInventory and myInventory.has_method("transfer_automerge"):
		return myInventory.transfer_automerge(item, destinationInventory)
	return false

# Helper function to get the inventory from a Control node
# This assumes that the Control node has a property or a method to access its inventory
func _get_inventory_from_control(control: Control) -> InventoryStacked:
	if control.has_method("get_inventory"):
		return control.get_inventory()
	elif control.has("inventory"):
		return control.inventory
	return null


# Function to get selected inventory items
func get_selected_inventory_items() -> Array[InventoryItem]:
	var items: Array[InventoryItem] = []
	for group_name in selectedItems:
		if group_to_item_mapping.has(group_name):
			items.append(group_to_item_mapping[group_name])
	return items
	
# Function to get selected inventory items
func get_inventory() -> InventoryStacked:
	return myInventory


func set_inventory(new_inventory: InventoryStacked):
	# Step 1: Deselect and clear the current inventory display
	_deselect_and_clear_current_inventory()

	# Step 2: Set the myInventory property to the new inventory
	myInventory = new_inventory

	# Step 3: Rebuild the inventory list with the new inventory
	_populate_inventory_list()
	_update_bars()
	_connect_inventory_signals()

func _deselect_and_clear_current_inventory():
	# Deselect all items
	for group_name in selectedItems:
		_toggle_group_selection(group_name, false)
	selectedItems.clear()

	# Clear the mapping and controls
	group_to_item_mapping.clear()
	group_controls.clear()

	# Clear the grid children
	_clear_grid_children()

	# Add header row to grid (if necessary)
	_add_header_row_to_grid()

	# Reset other variables if needed
	selectedItem = null
	last_selected_item = null
	last_hovered_item = null
