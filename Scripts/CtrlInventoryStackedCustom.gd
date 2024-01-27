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

var selectedItem: InventoryItem = null
var selectedItems: Array = []

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
		if last_hovered_item:
			_remove_highlight(last_hovered_item)
		_apply_highlight(hovered_item)
		last_hovered_item = hovered_item
	elif last_hovered_item and not hovered_item:
		# Remove highlight effect when cursor moves away
		_remove_highlight(last_hovered_item)
		last_hovered_item = null

func _apply_highlight(item: Node):
	if item is Control:
		var group_name = _get_group_name(item)
		for group_item in get_tree().get_nodes_in_group(group_name):
			if group_item is Control:
				group_item.highlight()

func _remove_highlight(item: Node):
	if item is Control:
		var group_name = _get_group_name(item)
		for group_item in get_tree().get_nodes_in_group(group_name):
			if group_item is Control:
				group_item.unhighlight()

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
	var header_icon = Label.new()
	header_icon.text = "I"
	inventoryGrid.add_child(header_icon)

	# Add header for Name
	var header_name = Label.new()
	header_name.text = "Name"
	inventoryGrid.add_child(header_name)

	# Add header for Weight
	var header_weight = Label.new()
	header_weight.text = "W"
	inventoryGrid.add_child(header_weight)

	# Add header for Volume
	var header_volume = Label.new()
	header_volume.text = "V"
	inventoryGrid.add_child(header_volume)

	# Add header for Favorite (If applicable)
	var header_favorite = Label.new()
	header_favorite.text = "F"
	inventoryGrid.add_child(header_favorite)

#
#
## Function to handle item click
#func _on_item_clicked(clickedItem: Control, ctrl_pressed: bool):
	## Logic to handle item click, e.g., marking as selected
	#if clickedItem.is_item_selected():
		## The item was just selected
		#if ctrl_pressed:
			## Control was pressed, so add it to the selected items list
			#selectedItems.append(clickedItem)
		#else:
			## Control was not pressed, so this should be the only selected item
			#clickedItem.select_item()
	#else:
		## The item was just de-selected
		## If the control key was held, the other selected items should remain selected
		## If the control key was not held, de-select all items and re-select the cliked item
		#clickedItem.select_item()
#
	## Emit signals based on selection
	#if selectedItems.size() == 1:
		#emit_signal("item_selected", selectedItems[0])
	#elif selectedItems.size() > 1:
		#emit_signal("items_selected", selectedItems)
#

func _on_item_clicked(clickedItem: Control, ctrl_pressed: bool):
	# Check if the item is already selected
	if clickedItem.is_item_selected():
		# The item was just selected
		if ctrl_pressed:
			# Control was pressed, so add it to the selected items list
			selectedItems.append(clickedItem)
		else:
			selectedItems.append(clickedItem)
			# If control is not pressed, deselect other items
			_deselect_all_except(clickedItem)
	else:
		# Item was de-selected
		if ctrl_pressed:
			# the control key was held, the other selected items should remain selected
			selectedItems.erase(clickedItem)
		else:
			if clickedItem in selectedItems:
				selectedItems.erase(clickedItem)
			else:
				# If control is not pressed, clear other selections and select this one
				_deselect_all_except(clickedItem)
				clickedItem.select_item()

	# Emit signals based on selection
	if selectedItems.size() == 1:
		emit_signal("item_selected", selectedItems[0])
	elif selectedItems.size() > 1:
		emit_signal("items_selected", selectedItems)

func _deselect_all_except(except_item: Control):
	for item in selectedItems:
		if item != except_item:
			item.unselect_item()
	selectedItems.clear()
	selectedItems = [except_item]




func add_item_to_grid(item: InventoryItem):
	# Define a unique group name for this set of items
	var group_name = "item_group_" + str(item.get_name())
	
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


func sort_inventory_by_property(property_name: String):
	# Create an array of items with additional data for sorting
	var items_with_data = []
	for item in myInventory.get_children():
		var prop_value = item.get_property(property_name, null)
		items_with_data.append({
			"item": item,
			"sort_value": prop_value
		})

	# Sort the array based on the property value
	items_with_data.sort_custom(_sort_items)

	# Clear and repopulate the grid with sorted items
	inventoryGrid.queue_free_children()
	add_header_row_to_grid()
	for item_data in items_with_data:
		add_item_to_grid(item_data["item"])

	emit_signal("inventory_sorted", property_name)

func _sort_items(a, b):
	var value_a = a["sort_value"]
	var value_b = b["sort_value"]
	if typeof(value_a) == TYPE_STRING:
		return value_a.nocasecmp_to(value_b) < 0
	else:
		return value_a < value_b
