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
var row_controls: Dictionary = {}
var inventory_rows: Dictionary = {}
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
	_update_bars(null, "")
	_connect_inventory_signals()


func process_highlight(item: Control):
	if item != last_hovered_item:
		if last_hovered_item and is_instance_valid(last_hovered_item):
			_remove_highlight(last_hovered_item)
		if item:
			_apply_highlight(item)
		last_hovered_item = item

func _apply_highlight(item: Control):
	var row_name = _get_row_name(item)
	if inventory_rows.has(row_name):
		for control in inventory_rows[row_name]["controls"]:
			if is_instance_valid(control):
				control.highlight()

func _remove_highlight(item: Control):
	var row_name = _get_row_name(item)
	if inventory_rows.has(row_name):
		for control in inventory_rows[row_name]["controls"]:
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
	_deselect_all_items()
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
			var row_name = "item_row_" + str(item.get_name())
			_add_item_to_grid(item, row_name)
	_update_bars(changedItem, action)

# Gets the row name from an item
# An item is a control element in the inventory grid
func _get_row_name(item: Control) -> String:
	for row in item.get_groups():
		if row.begins_with("item_row_"):
			return row
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
	_create_header("I")	# Icon
	_create_header("Name") # Name
	_create_header("S") # Stack size
	_create_header("W") # Weight
	_create_header("V") # Volume
	_create_header("F") # Favorite
	
func _on_item_right_clicked(clickedItem: Control):
	show_context_menu(clickedItem.global_position)

# When an item in the inventory is clicked
# There are 5 items per row in the grid, but they are treated as a row of 5
# So clicking one item will select the whole row
func _on_item_clicked(clickedItem: Control):
	var row_name = _get_row_name(clickedItem)
	
	if Input.is_key_pressed(KEY_CTRL):
		# CTRL is held: check if current row is selected and if there are other rows selected
		if _is_row_selected(row_name) and selectedItems.size() > 1:
			# Deselect the current row
			_toggle_row_selection(row_name, false)
		else:
			_toggle_row_selection(row_name, clickedItem.is_item_selected())
	elif Input.is_key_pressed(KEY_SHIFT) and last_selected_item:
		# SHIFT is held: select a range of items
		_select_range(last_selected_item, clickedItem)
	else:
		# No modifier key: select or deselect the clicked row
		# Check if the clicked item's row is selected
		if not _is_row_selected(row_name):
			if selectedItems.size() == 1 and selectedItems[0] == row_name:
				_toggle_row_selection(row_name, false) # De-select
			else:
				# More then one row is selected
				# Deselect all other items and select the clicked row
				for selected_row in selectedItems.duplicate():
					_toggle_row_selection(selected_row, false)
				_toggle_row_selection(row_name, true)

	# Update last selected item
	last_selected_item = clickedItem

# Select a range of items. This is called when the user
# selects an item and then holds shift and selects another item
func _select_range(start_item: Control, end_item: Control):
	var start_row_name = _get_row_name(start_item)
	var end_row_name = _get_row_name(end_item)

	var start_index = _find_row_start_index(start_row_name)
	var end_index = _find_row_start_index(end_row_name)

	var min_index = min(start_index, end_index)
	var max_index = max(start_index, end_index)

	for row_name in inventory_rows.keys():
		var row_index = _find_row_start_index(row_name)
		if row_index >= min_index and row_index <= max_index:
			_toggle_row_selection(row_name, true)

# Find the index of the first item in a row
func _find_row_start_index(row_name: String) -> int:
	var index = 0
	for control in inventoryGrid.get_children():
		if control is Control and control in inventory_rows[row_name]["controls"]:
			return index
		index += 1
	return -1

# Generic function to create an item in the grid
func _create_ui_element(property: String, item: InventoryItem, row_name: String) -> Control:
	var element = listItemContainer.instantiate() as Control
	match property:
		"icon":
			element.set_icon(item.get_texture())
			element.custom_minimum_size = Vector2(32, 32)
		"name":
			element.set_label_text(item.get_title())
			element.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		"stack_size":
			# Assuming stack size is a property of the item
			element.set_label_text(str(InventoryStacked.get_item_stack_size(item)))
		_, "weight", "volume", "favorite":
			# Fill in the value for the rest of the properties
			element.set_label_text(str(item.get_property(property, 0)))
	# The name will be something like weight_Node_211748 or icon_Node_211748
	# Now we can use the name to get information about the property
	element.name = property + "_" + str(item.get_name())
	element.connect("item_clicked", _on_item_clicked)
	element.connect("item_right_clicked", _on_item_right_clicked)
	# We use rows to keep track of the items
	element.add_to_group(row_name)
	return element

# Function to add an item to the grid
func _add_item_to_grid(item: InventoryItem, row_name: String):
	# Initialize the row if it's not already present
	if not inventory_rows.has(row_name):
		inventory_rows[row_name] = {"item": item, "controls": []}

	# Each item has these 6 columns to fill, so we loop over each of the properties
	for property in ["icon", "name", "stack_size", "weight", "volume", "favorite"]:
		var element = _create_ui_element(property, item, row_name)
		inventoryGrid.add_child(element)
		element.mouse_entered.connect(process_highlight.bind(element))
		element.mouse_exited.connect(process_highlight.bind(element))

		# Add the control to the row's control list
		inventory_rows[row_name]["controls"].append(element)

# Populate the inventory list
func _populate_inventory_list():
	_clear_grid_children()
	_add_header_row_to_grid()
	# Loop over inventory items and add them to the grid
	for item in myInventory.get_children():
		var row_name = "item_row_" + str(item.get_name())
		_add_item_to_grid(item, row_name)

func _update_bars(changedItem: InventoryItem, action: String):
	var total_weight = 0
	var total_volume = 0
	for item in myInventory.get_children():
		if action == "removed":
			# Something was removed. If it was the current item, do not count it
			if changedItem != item:
				total_weight += item.get_property("weight", 0) 
				total_volume += item.get_property("volume", 0)
		else:
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
	var header_mapping = {"I": "icon", "Name": "name", "S": "stack_size", "W": "weight", "V": "volume", "F": "favorite"}
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

func _sort_rows(a, b):
	var value_a = a["sort_value"]
	var value_b = b["sort_value"]
	print("Comparing: ", value_a, " with ", value_b)  # Debugging line
	if typeof(value_a) == TYPE_STRING:
		return value_a.nocasecmp_to(value_b) < 0
	else:
		return value_a < value_b

# Returns the value of the provided property for the provided row
# Essentially, the row_name is a row and the property_name is a column in the grid
func _get_representative_value_for_row(row_name: String, property_name: String):
	if inventory_rows.has(row_name):
		var row_item = inventory_rows[row_name]["item"]
		if row_item:
			var property_value = row_item.get_property(property_name, null)
			if property_value != null:
				return property_value
	# Return default value
	return "" if property_name in ["name", "favorite"] else 0

# Will sort the order of the items baased on the selected column (property_name)
func _sort_inventory_by_property(property_name: String, reverse_order: bool = false):
	var sorted_rows = _get_sorted_rows(property_name)
	if reverse_order:
		sorted_rows.reverse()  # Reverse the order of the sorted rows
	for row_name in sorted_rows:
		_move_row_to_end(row_name)
	emit_signal("inventory_sorted", property_name)

func _move_row_to_end(row_name: String):
	if inventory_rows.has(row_name):
		for control in inventory_rows[row_name]["controls"]:
			if is_instance_valid(control):
				inventoryGrid.move_child(control, inventoryGrid.get_child_count() - 1)

# Constructs an array of the row name and the provided property
# The row_data is essentially all the rows in the grid
# The property_name is the column of the grid
# With this new array of row_name and property_name, the items can be sorted
func _get_sorted_rows(property_name: String) -> Array:
	var row_data = []
	for row_name in inventory_rows.keys():
		var representative_value = _get_representative_value_for_row(row_name, property_name)
		row_data.append({"row_name": row_name, "sort_value": representative_value})
	
	row_data.sort_custom(_sort_rows)
	
	var sorted_row_names = []
	for gd in row_data:
		sorted_row_names.append(gd["row_name"])
	
	return sorted_row_names

# A row is made up of 5 items (a row).
# This will select or deselect a row
func _toggle_row_selection(row_name: String, select: bool):
	# Avoid processing the same row if it's already in the desired state
	if select and row_name in selectedItems or not select and not row_name in selectedItems:
		return

	print_debug("Toggle Group: ", row_name, ", Select: ", select)
	if inventory_rows.has(row_name):
		var row_info = inventory_rows[row_name]
		for control in row_info["controls"]:
			if is_instance_valid(control):
				if select:
					control.select_item()
				else:
					control.unselect_item()
		if select:
			selectedItems.append(row_name)
		else:
			selectedItems.erase(row_name)

# If any of the controls is un-selected, the row is not selected
# Otherwise the row is selected
func _is_row_selected(row_name: String) -> bool:
	if inventory_rows.has(row_name):
		for control in inventory_rows[row_name]["controls"]:
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
	for row_name in selectedItems:
		if inventory_rows.has(row_name):
			items.append(inventory_rows[row_name]["item"])
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
	_update_bars(null, "")
	_connect_inventory_signals()

func _deselect_and_clear_current_inventory():
	# Deselect all items
	for row_name in selectedItems:
		_toggle_row_selection(row_name, false)
	selectedItems.clear()

	# Clear the rows
	inventory_rows.clear()

	# Clear the grid children
	_clear_grid_children()

	# Add header row to grid (if necessary)
	_add_header_row_to_grid()

	# Reset other variables if needed
	selectedItem = null
	last_selected_item = null
	last_hovered_item = null


# Helper function to deselect all items
func _deselect_all_items():
	for row_name in selectedItems:
		if inventory_rows.has(row_name):
			for control in inventory_rows[row_name]["controls"]:
				if is_instance_valid(control):
					control.unselect_item()
	selectedItems.clear()
