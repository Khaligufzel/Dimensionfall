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

var selectedItem: InventoryItem = null
var selectedItems: Array = []
var last_selected_item: Control = null
var group_to_item_mapping: Dictionary = {}


signal item_selected(item)
signal items_selected(items)
signal inventory_sorted(column)
signal inventory_updated
signal inventory_reached_capacity
signal inventory_empty

func _ready():
	populate_inventory_list()
	connect_signals()
	update_bars()

var last_hovered_item: Node = null

func _process(_delta):
	var mouse_pos = get_global_mouse_position()
	var hovered_item: Node = null

	# Check each child in the GridContainer
	for child in inventoryGrid.get_children():
		if child is Control and child.get_global_rect().has_point(mouse_pos):
			hovered_item = child
			break

	# Apply highlight effect
	if hovered_item and hovered_item != last_hovered_item:
		if last_hovered_item and is_instance_valid(last_hovered_item):
			_remove_highlight(last_hovered_item)
		_apply_highlight(hovered_item)
		last_hovered_item = hovered_item
	elif last_hovered_item and not hovered_item and is_instance_valid(last_hovered_item):
		# Remove highlight effect when cursor moves away
		_remove_highlight(last_hovered_item)
		last_hovered_item = null

func _remove_highlight(item: Node):
	if item is Control and is_instance_valid(item):
		var group_name = _get_group_name(item)
		for group_item in get_tree().get_nodes_in_group(group_name):
			if group_item is Control:
				group_item.unhighlight()



func _apply_highlight(item: Node):
	if item is Control and is_instance_valid(item):
		var group_name = _get_group_name(item)
		for group_item in get_tree().get_nodes_in_group(group_name):
			if group_item is Control:
				group_item.highlight()

func _get_group_name(item: Control) -> String:
	for group in item.get_groups():
		if group.begins_with("item_group_"):
			return group
	return ""

func connect_signals():
	# Connect each item for selection
	for item_index in range(inventoryGrid.get_child_count()):
		var child = inventoryGrid.get_child(item_index)
		if child is TextureRect or child is Label:
			child.connect("gui_input", _on_item_gui_input)


# Function to handle GUI input on an item
func _on_item_gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var item = inventoryGrid.get_selected_item()
		# Check if CTRL is held for multiple selections
		if Input.is_key_pressed(KEY_CTRL):
			# Add or remove from the selection
			if item in selectedItems:
				selectedItems.erase(item)
			else:
				selectedItems.append(item)
			emit_signal("items_selected", selectedItems)
		else:
			# Single selection
			selectedItem = item
			selectedItems = [item]
			emit_signal("item_selected", item)

func populate_inventory_list():
	# Clear current grid
	for child in inventoryGrid.get_children():
		child.queue_free()

	# Add header row
	add_header_row_to_grid()

	# Add items to grid
	for item in myInventory.get_children():
		add_item_to_grid(item)


func add_header_row_to_grid():
	# Create header elements and add them to the grid

	# Already given: header for Icon
	var header_icon = listHeaderContainer.instantiate() as Control
	header_icon.set_label_text("I")
	inventoryGrid.add_child(header_icon)
	header_icon.connect("header_clicked", _on_header_clicked)

	# Add header for Name
	var header_name = listHeaderContainer.instantiate() as Control
	header_name.set_label_text("Name")
	inventoryGrid.add_child(header_name)
	header_name.connect("header_clicked", _on_header_clicked)

	# Add header for Weight
	var header_weight = listHeaderContainer.instantiate() as Control
	header_weight.set_label_text("W")
	inventoryGrid.add_child(header_weight)
	header_weight.connect("header_clicked", _on_header_clicked)

	# Add header for Volume
	var header_volume = listHeaderContainer.instantiate() as Control
	header_volume.set_label_text("V")
	inventoryGrid.add_child(header_volume)
	header_volume.connect("header_clicked", _on_header_clicked)

	# Add header for Favorite (If applicable)
	var header_favorite = listHeaderContainer.instantiate() as Control
	header_favorite.set_label_text("F")
	inventoryGrid.add_child(header_favorite)
	header_favorite.connect("header_clicked", _on_header_clicked)



func _on_item_clicked(clickedItem: Control):
	var group_name = _get_group_name(clickedItem)
	if Input.is_key_pressed(KEY_CTRL):
		# Toggle the entire group selection
		_toggle_group_selection(group_name, not _is_group_selected(group_name))
	elif Input.is_key_pressed(KEY_SHIFT) and last_selected_item:
		# Select a range of items (handled as before)
		_select_range(last_selected_item, clickedItem)
	else:
		# Select only the clicked group
		for selected_group in selectedItems.duplicate():
			_toggle_group_selection(selected_group, false)
		_toggle_group_selection(group_name, true)

	# Update last selected item
	last_selected_item = clickedItem

func _toggle_group_selection(group_name: String, select: bool):
	for group_item in get_tree().get_nodes_in_group(group_name):
		if group_item is Control:
			if select:
				group_item.select_item()
			else:
				group_item.unselect_item()
	if select:
		selectedItems.append(group_name)
	else:
		selectedItems.erase(group_name)

func _is_group_selected(group_name: String) -> bool:
	for group_item in get_tree().get_nodes_in_group(group_name):
		if group_item is Control and not group_item.is_item_selected():
			return false
	return true

# This function will return a dictionary with 5 keys
# The 5 keys are icon, name, weight, volume, favorite
func _get_group_data(group_name: String) -> Dictionary:
	var group_item = group_to_item_mapping[group_name]
	if group_item:
		# Now use group_item to get the data
		return {
			"icon": group_item.get_icon(),
			"name": group_item.get_title(),
			"weight": group_item.get_property("weight", 0),
			"volume": group_item.get_property("volume", 0),
			"favorite": group_item.is_favorite()  # Assuming is_favorite() method exists
		}
	else:
		return {"icon": null, "name": "", "weight": 0, "volume": 0, "favorite": false}


func _select_row_items(item: Control):
	var group_name = _get_group_name(item)
	for group_item in get_tree().get_nodes_in_group(group_name):
		if group_item is Control and not group_item.is_item_selected():
			group_item.select_item()


func _select_range(start_item: Control, end_item: Control):
	var start_group_name = _get_group_name(start_item)
	var end_group_name = _get_group_name(end_item)

	var start_index = _find_group_start_index(start_group_name)
	var end_index = _find_group_start_index(end_group_name)

	var min_index = min(start_index, end_index)
	var max_index = max(start_index, end_index)

	# Iterate through the grid and select groups within the range
	for i in range(min_index, max_index + 1):
		var item = inventoryGrid.get_child(i)
		if item:
			var group_name = _get_group_name(item)
			_toggle_group_selection(group_name, true)

# Find the index of the first item in a group
func _find_group_start_index(group_name: String) -> int:
	for i in range(inventoryGrid.get_child_count()):
		var item = inventoryGrid.get_child(i)
		if item and _get_group_name(item) == group_name:
			return i
	return -1




func _find_child_index(item: Control) -> int:
	for i in range(inventoryGrid.get_child_count()):
		if inventoryGrid.get_child(i) == item:
			return i
	return -1



func _deselect_all_except(except_item: Control):
	for item in selectedItems:
		if item != except_item:
			item.unselect_item()
	selectedItems.clear()
	selectedItems = [except_item]




func add_item_to_grid(item: InventoryItem):
	# Define a unique group name for this set of items
	var group_name = "item_group_" + str(item.get_name())
	group_to_item_mapping[group_name] = item
	
	# Add the item icon
	var item_icon = listItemContainer.instantiate() as Control
	item_icon.set_icon(item.get_texture())
	inventoryGrid.add_child(item_icon)
	item_icon.connect("item_clicked", _on_item_clicked)
	item_icon.add_to_group(group_name)

	# Add the item name
	var item_name = listItemContainer.instantiate() as Control
	item_name.set_label_text(item.get_title())
	inventoryGrid.add_child(item_name)
	item_name.connect("item_clicked", _on_item_clicked)
	item_name.add_to_group(group_name)

	# Add the item weight
	var item_weight = listItemContainer.instantiate() as Control
	item_weight.set_label_text(str(item.get_property("weight", 0)))
	inventoryGrid.add_child(item_weight)
	item_weight.connect("item_clicked", _on_item_clicked)
	item_weight.add_to_group(group_name)

	# Add the item volume
	var item_volume = listItemContainer.instantiate() as Control
	item_volume.set_label_text(str(item.get_property("volume", 0)))
	inventoryGrid.add_child(item_volume)
	item_volume.connect("item_clicked", _on_item_clicked)
	item_volume.add_to_group(group_name)

	# Add the item favorite
	var item_favorite = listItemContainer.instantiate() as Control
	item_favorite.set_label_text(str(item.get_property("favorite", 0)))
	inventoryGrid.add_child(item_favorite)
	item_favorite.connect("item_clicked", _on_item_clicked)
	item_favorite.add_to_group(group_name)

	# Assign a unique name to each UI element
	item_icon.name = "icon_" + str(item.get_name())
	item_name.name = "name_" + str(item.get_name())
	item_weight.name = "weight_" + str(item.get_name())
	item_volume.name = "volume_" + str(item.get_name())
	item_favorite.name = "favorite_" + str(item.get_name())
	item_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_icon.custom_minimum_size = Vector2(32,32)


func update_bars():
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

# When the header is clicked
func _on_header_clicked(headerItem: Control) -> void:
	var header_label = headerItem.get_label_text()
	if header_label == "I":
		sort_inventory_by_property("icon")
	elif header_label == "Name":
		sort_inventory_by_property("name")
	elif header_label == "W":
		sort_inventory_by_property("weight")
	elif header_label == "V":
		sort_inventory_by_property("volume")
	elif header_label == "F":
		sort_inventory_by_property("favorite")


func sort_inventory_by_property(property_name: String):
	var group_data = []
	var group_names = []

	# Aggregate data by group
	for item in inventoryGrid.get_children():
		var group_name = _get_group_name(item)
		if not group_names.has(group_name):
			group_names.append(group_name)
			var representative_value = _get_representative_value_for_group(group_name, property_name)
			group_data.append({
				"group_name": group_name,
				"sort_value": representative_value
			})

	# Sort the array based on the property value
	group_data.sort_custom(_sort_groups)

	# Clear and repopulate the grid with sorted groups
	_clear_grid_children()
	add_header_row_to_grid()
	for group in group_data:
		_add_group_to_grid(group["group_name"])
	emit_signal("inventory_sorted", property_name)

func _clear_grid_children():
	while inventoryGrid.get_child_count() > 0:
		var child = inventoryGrid.get_child(0)
		inventoryGrid.remove_child(child)
		child.queue_free()

func _sort_groups(a, b):
	var value_a = a["sort_value"]
	var value_b = b["sort_value"]
	if typeof(value_a) == TYPE_STRING:
		return value_a.nocasecmp_to(value_b) < 0
	else:
		return value_a < value_b

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


func _add_group_to_grid(group_name: String):
	# Logic to add all items of the group to the grid in their sorted order
	var group_items = get_tree().get_nodes_in_group(group_name)
	for item in group_items:
		add_item_to_grid(item)
