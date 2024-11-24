extends Control

# This script is intended to be used with CtrlInventoryStackedCustom
# It displays inventory items with their properties in a ItemList displayed as a grid
# The first row in the grid is the header
# Below the header is a list it inventory items
# The first column has the item's icon
# The second column has the item's name
# The third column has the item's stack size (amount)
# The fourth column has the item's weight
# The fifth column has the item's volume
# The sixth column shows if an item is favorited
# Clicking on a header column will sort the grid's items by that column
# The user will be able to drag the cursor over items while pressing the left mouse button, this will allow the user to select multiple items
# Items can be dragged from the list to other controls in the interface
# The user will be able to favorite an item in the list by selecting it and pressing F.


# The central grid to visualize the cells and columns
@export var inventoryGrid: GridContainer
# A visual element to show weight capacity
@export var WeightBar: ProgressBar
# A visual element to show volume capacity
@export var VolumeBar: ProgressBar
# The currently attached InventoryStacked that holds the items
@export var myInventory: InventoryStacked
@export var max_weight: int = 1000
@export var max_volume: int = 1000
@export var listItemContainer: PackedScene
@export var listHeaderContainer: PackedScene
# Context menu that will show actions for selected items
@export var context_menu: PopupMenu

var last_selected_item: Control = null
var row_controls: Dictionary = {}
var inventory_rows: Dictionary = {}


# Dictionary to store header controls
var header_controls: Dictionary = {}
var selected_header: String = ""
var header_sort_order: Dictionary = {}

# Variables to help with mouse input on the items
var mouse_press_position: Vector2 = Vector2()
var selection_state_changed: bool = false
var ui_updates_enabled = true


# Signals for context menu actions
signal equip_left(items: Array[InventoryItem])
signal equip_right(items: Array[InventoryItem])
signal reload_item(items: Array[InventoryItem])
signal unload_item(items: Array[InventoryItem])

# UI signals emitted when the cursor hovers over a row in the list
signal mouse_entered_item(item: InventoryItem)
signal mouse_exited_item
signal grid_cell_doubleclicked(item: InventoryItem)


func initialize_list():
	_populate_inventory_list()
	_update_bars(null, "") # Update weight and volume bars
	_connect_inventory_signals()
	set_process_input(true)  # Make sure input processing is enabled for drag drop
	reload_item.connect(_on_context_menu_reload)
	unload_item.connect(_on_context_menu_unload)


# Initialize these in _ready function or similar initialization function
func _ready():
	Helper.signal_broker.inventory_operation_started.connect(_on_inventory_operation_started)
	Helper.signal_broker.inventory_operation_finished.connect(_on_inventory_operation_finished)
	Helper.signal_broker.player_attribute_changed.connect(_on_player_attribute_changed)


# Function to show context menu at specified position
func show_context_menu(myposition: Vector2):
	# Create a small Rect2i around the position
	# We need this because the popup function requires it
	var popup_rect = Rect2i(int(myposition.x), int(myposition.y), 1, 1)
	context_menu.popup(popup_rect)


# Handle context menu item selection
# The actual items are defined in CtrlInventoryStackedCustom.tscn
func _on_context_menu_item_selected(id):
	var selected_inventory_items = get_selected_inventory_items()
	match id:
		0: equip_left.emit(selected_inventory_items)
		1: equip_right.emit(selected_inventory_items)
		2: reload_item.emit(selected_inventory_items)
		3: unload_item.emit(selected_inventory_items)
		4: Helper.signal_broker.items_were_used.emit(selected_inventory_items)


func _disconnect_inventory_signals():
	if myInventory.item_added.is_connected(_on_inventory_item_added):
		myInventory.item_added.disconnect(_on_inventory_item_added)
	if myInventory.item_removed.is_connected(_on_inventory_item_removed):
		myInventory.item_removed.disconnect(_on_inventory_item_removed)
	if myInventory.item_modified.is_connected(_on_inventory_item_modified):
		myInventory.item_modified.disconnect(_on_inventory_item_modified)
	if myInventory.contents_changed.is_connected(_on_inventory_contents_changed):
		myInventory.contents_changed.disconnect(_on_inventory_contents_changed)


func _connect_inventory_signals():
	# Connect signals from InventoryStacked to this control script
	myInventory.item_added.connect(_on_inventory_item_added)
	myInventory.item_removed.connect(_on_inventory_item_removed)
	myInventory.item_modified.connect(_on_inventory_item_modified)
	myInventory.contents_changed.connect(_on_inventory_contents_changed)


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
	if not ui_updates_enabled:
		return
	_deselect_all_items()
	# Clear and repopulate the inventory list
	_deselect_and_clear_current_inventory()
	_add_header_row_to_grid()
	for item in myInventory.get_children():
		var add_item: bool = true
		if item and item == changedItem:
			match action:
				"added":
					add_item = true
				"removed":
					add_item = false
				"modified":
					add_item = true
				_, "contentschanged":
					add_item = true
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
	var header = listHeaderContainer.instantiate() as Control
	header.set_label_text(text)
	
	# If this is the "favorite" header, set a smaller size
	if text == "F":  # Assuming "F" is the text for the favorite column header
		header.custom_minimum_size = Vector2(16, 32)  # Match the size set for favorite column elements
	
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


# When the user right-clicks on one of the inventory items
func _on_item_right_clicked(clickedItem: Control):
	var row_name = _get_row_name(clickedItem)
	
	# Check if any item is selected
	if get_selected_inventory_items().size() == 0:
		# If no item is selected, select the clicked item
		_deselect_all_items()
		_toggle_row_selection(row_name, true)

	# Show context menu at the global position of the clicked item
	show_context_menu(clickedItem.global_position)


# When an item in the inventory is clicked
# There are 5 items per row in the grid, but they are treated as a row of 5
# So clicking one item will select the whole row
# When an item in the inventory is clicked
# There are 5 items per row in the grid, but they are treated as a row of 5
# So clicking one item will select the whole row
func _on_item_clicked(clickedItem: Control):
	var row_name = _get_row_name(clickedItem)
	var was_selected = _is_row_selected(row_name)

	# Check if the favorite column was clicked
	if clickedItem.name.begins_with("favorite_"):
		_toggle_favorite(clickedItem, inventory_rows[row_name]["item"])
		return  # Skip selection logic if it's a favorite toggle

	if Input.is_key_pressed(KEY_CTRL):
		# CTRL is held: check if current row is selected and if there are other rows selected
		if _is_row_selected(row_name):
			# Toggle the current row's selection state
			_toggle_row_selection(row_name, !inventory_rows[row_name]["is_selected"])
		else:
			_toggle_row_selection(row_name, true)
	elif Input.is_key_pressed(KEY_SHIFT) and last_selected_item:
		# SHIFT is held: select a range of items
		_select_range(last_selected_item, clickedItem)
	else:
		# No modifier key: select or deselect the clicked row
		if not _is_row_selected(row_name) or len(get_selected_inventory_items()) > 1:
			# Deselect all other items and select the clicked row
			_deselect_all_items()
			_toggle_row_selection(row_name, true)
		else:
			# Toggle the selection of the clicked row
			_toggle_row_selection(row_name, !inventory_rows[row_name]["is_selected"])

	# Update last selected item
	last_selected_item = clickedItem
	# Update the variable based on whether the selection state changed
	selection_state_changed = was_selected != _is_row_selected(row_name)


# Function to toggle the favorite status of an item
func _toggle_favorite(ui_element: Control, item: InventoryItem):
	var current_favorite = item.get_property("favorite", false)
	item.set_property("favorite", not current_favorite)
	# Update UI element to reflect the change
	ui_element.set_label_text("*" if not current_favorite else "")
	# Optionally update the inventory list or the specific row
	#update_inventory_list(item, "modified")


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
			element.set_label_text(get_display_name(item))
			element.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		"stack_size":
			# Assuming stack size is a property of the item
			element.set_label_text(str(InventoryStacked.get_item_stack_size(item)))
		"weight", "volume":
			element.set_label_text(str(item.get_property(property, 0)))
		"favorite":
			var favorite = item.get_property("favorite", false)
			element.custom_minimum_size = Vector2(12, 32)
			element.set_label_text("*" if favorite else "")
	# The name will be something like weight_Node_211748 or icon_Node_211748
	# Now we can use the name to get information about the property
	element.name = property + "_" + str(item.get_name())
	# Connect the gui_input signal to the _on_grid_cell_gui_input function
	element.gui_input.connect(_on_grid_cell_gui_input.bind(element))
	
	# We use rows to keep track of the items
	element.add_to_group(row_name)
	return element


# In a separate InventoryItemHandler class or module:
func get_display_name(item: InventoryItem) -> String:
	var item_name = item.get_title()
	
	# A gun might have the current_magazine property
	if not item.get_property("current_magazine") == null:
		var magazine = item.get_property("current_magazine")
		item_name += get_magazine_current_max_ammo(magazine)
	
	# Check if the item is a magazine and append ammo info
	if not item.get_property("Magazine") == null:
		item_name += get_magazine_current_max_ammo(item)
		
	return item_name


func get_magazine_current_max_ammo(magazineItem: InventoryItem) -> String:
	var magazine_info = magazineItem.get_property("Magazine")
	if magazine_info and magazine_info is Dictionary:
		var current_ammo = int(magazine_info.get("current_ammo", 0))
		var max_ammo = int(magazine_info.get("max_ammo", 0))
		return " ["+str(current_ammo)+"/"+str(max_ammo)+"]"
	return ""


# Function to add an item to the grid
func _add_item_to_grid(item: InventoryItem, row_name: String):
	# Initialize the row if it's not already present
	if not inventory_rows.has(row_name):
		inventory_rows[row_name] = {"item": item, "controls": [], "is_selected": false}

	# Each item has these 6 columns to fill, so we loop over each of the properties
	for property in ["icon", "name", "stack_size", "weight", "volume", "favorite"]:
		var element = _create_ui_element(property, item, row_name)
		inventoryGrid.add_child(element)
		# Add the control to the row's control list
		inventory_rows[row_name]["controls"].append(element)
	# Connect signals for all elements in the row to each other for highlighting
	_connect_row_signals(row_name)


# Connect the mouse_entered and mouse_exited signals of all controls in a row
func _connect_row_signals(row_name: String):
	for control in inventory_rows[row_name]["controls"]:
		control.mouse_entered.connect(_on_row_mouse_entered.bind(row_name))
		control.mouse_exited.connect(_on_row_mouse_exited.bind(row_name))


# This function is called when the mouse enters any control within a row.
# 'row_name' is passed as a parameter when the signal is connected.
func _on_row_mouse_entered(row_name: String):
	if inventory_rows.has(row_name):
		for control in inventory_rows[row_name]["controls"]:
			control.highlight()
		var item = inventory_rows[row_name]["item"] as InventoryItem
		if item:
			mouse_entered_item.emit(item)


# Unhighlight all controls in the row when the mouse exits any control
func _on_row_mouse_exited(row_name: String):
	if inventory_rows.has(row_name):
		mouse_exited_item.emit()  # Emit the signal with no parameters
		for control in inventory_rows[row_name]["controls"]:
			control.unhighlight()


# Populate the inventory list
func _populate_inventory_list():
	_deselect_and_clear_current_inventory()
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

	WeightBar.max_value = max_weight
	WeightBar.value = total_weight
	if myInventory == ItemManager.playerInventory:
		VolumeBar.max_value = ItemManager.player_max_inventory_volume
	else:
		VolumeBar.max_value = max_volume
	VolumeBar.value = total_volume


# Handles the update of the attribute when the player attribute changes
func _on_player_attribute_changed(_player_node: CharacterBody3D, attr: PlayerAttribute = null):
	if attr and attr.fixed_mode:  # If a specific attribute has changed
		if attr.id == "inventory_space":
			_update_bars(null,"")


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
			# Handle boolean for favorite specially to allow sorting
			if property_name == "favorite":
				# Convert boolean to integer (true -> 1, false -> 0)
				# Use `false` as the default if the property value is null
				return int(property_value if property_value != null else false)
			if property_value != null:
				return property_value
	# Return a default value based on property type
	return 0 if property_name in ["weight", "volume", "stack_size"] else ""


# Will sort the order of the items baased on the selected column (property_name)
func _sort_inventory_by_property(property_name: String, reverse_order: bool = false):
	var sorted_rows = _get_sorted_rows(property_name)
	if reverse_order:
		sorted_rows.reverse()  # Reverse the order of the sorted rows
	for row_name in sorted_rows:
		_move_row_to_end(row_name)


func _move_row_to_end(row_name: String):
	if inventory_rows.has(row_name):
		for control in inventory_rows[row_name]["controls"]:
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


# A row is made up of 6 items (a row).
# This will select or deselect a row, depending on the value of the select parameter
func _toggle_row_selection(row_name: String, select: bool):
	if inventory_rows.has(row_name):
		var row_info = inventory_rows[row_name]
		row_info["is_selected"] = select  # Update the is_selected property
		for control in row_info["controls"]:
			if select:
				control.select_item()
			else:
				control.unselect_item()


# Returns if the row is selected
func _is_row_selected(row_name: String) -> bool:
	return inventory_rows.has(row_name) and inventory_rows[row_name]["is_selected"]


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
	for row_name in inventory_rows.keys():
		if inventory_rows[row_name]["is_selected"]:
			items.append(inventory_rows[row_name]["item"])
	return items


# Function to get selected inventory items
func get_inventory() -> InventoryStacked:
	return myInventory


# Called when this inventory list is connected to a new inventory
# For example, when the user selects a container from a list in the UI
func set_inventory(new_inventory: InventoryStacked):
	# Step 1: Deselect and clear the current inventory display
	_deselect_and_clear_current_inventory()
	_disconnect_inventory_signals()
	# Step 2: Set the myInventory property to the new inventory
	myInventory = new_inventory

	# Step 3: Rebuild the inventory list with the new inventory
	_populate_inventory_list()
	_update_bars(null, "")
	_connect_inventory_signals()


func _deselect_and_clear_current_inventory():
	# Deselect all items
	for row_name in inventory_rows.keys():
		if inventory_rows.has(row_name):
			_toggle_row_selection(row_name, false)

	# Clear the rows
	inventory_rows.clear()

	# Clear the grid children
	_clear_grid_children()

	# Reset other variables if needed
	last_selected_item = null


# All rows are desleected
func _deselect_all_items():
	for row_name in inventory_rows.keys():
		if inventory_rows.has(row_name):
			_toggle_row_selection(row_name, false)


# When the user clicks on one of the cells in the grid
func _on_grid_cell_gui_input(event, gridCell: Control):
	if event is InputEventMouseButton:
		if event.pressed:  # Check if the mouse button was pressed down
			mouse_press_position = event.position  # Store the position of mouse press
			match event.button_index:
				MOUSE_BUTTON_LEFT:
					# Detect double-click
					if event.double_click:
						_on_grid_cell_double_clicked(gridCell)
						return
					# Do not handle click here if items are selected, wait for release
					if get_selected_inventory_items().size() == 0:
						# One item selected, handle the click immediately
						_on_item_clicked(gridCell)
					elif get_selected_inventory_items().size() == 1:
						# Only one item is selected. Is it the currently clicked one?
						if !_is_row_selected(_get_row_name(gridCell)):
							# The currently clicked item is not the one that was selected
							_on_item_clicked(gridCell)
				MOUSE_BUTTON_RIGHT:
					# Handle right mouse button click
					_on_item_right_clicked(gridCell)
		else:  # Mouse button released
			var mouse_release_position = event.position
			# Check if the mouse was released within a 10 pixel area
			if mouse_press_position.distance_to(mouse_release_position) <= 10:
				match event.button_index:
					MOUSE_BUTTON_LEFT:
						# Only handle the click if the selection state did not change
						if not selection_state_changed:
							_on_item_clicked(gridCell)
						# Reset the flag
						selection_state_changed = false


# Function to initiate drag data for selected items
func _get_drag_data(_newpos):
	var selected_items: Array[InventoryItem] = get_selected_inventory_items()
	if selected_items.size() == 0:
		return null
	
	var preview = _create_drag_preview(selected_items[0])
	set_drag_preview(preview)
	return selected_items


# This function should return true if the dragged data can be dropped here
func _can_drop_data(_newpos, data) -> bool:
	return data is Array[InventoryItem]


# This function handles the data being dropped
func _drop_data(newpos, data) -> void:
	if _can_drop_data(newpos, data):
		_handle_item_drop(data, newpos)


# Helper function to create a preview Control for dragging
func _create_drag_preview(item: InventoryItem) -> Control:
	var preview = TextureRect.new()
	preview.texture = item.get_texture()
	preview.custom_minimum_size = Vector2(32, 32)  # Set the desired size for your preview
	return preview


# When the player drops items into this list
func _handle_item_drop(dropped_data, _newpos) -> void:
	# Check if the dropped data is valid and contains inventory items
	if dropped_data is Array and dropped_data.size() > 0 and dropped_data[0] is InventoryItem:
		var first_item = dropped_data[0]

		# Get the inventory of the first item
		var item_inventory = first_item.get_inventory()

		# If the item's inventory is different from the current inventory, transfer the items
		if item_inventory != myInventory:
			# Get the items that fit inside the remaining volume
			var items_to_transfer = get_items_that_fit_by_volume(dropped_data)

			Helper.signal_broker.inventory_operation_started.emit()
			for item in items_to_transfer:
				# Transfer the item to the current inventory
				item_inventory.transfer_automerge(item, myInventory)
			Helper.signal_broker.inventory_operation_finished.emit()


# When the user requests a reload trough the inventory context menu
func _on_context_menu_reload(items: Array[InventoryItem]) -> void:
	for item in items:
		if item.get_property("Ranged") != null:
			if ItemManager.find_compatible_magazine(item):
				var reload_speed: float = float(ItemManager.get_nested_property(item, "Ranged.reload_speed"))
				# Retrieve reload speed from the "Ranged" property dictionary or use the default
				ItemManager.start_reload(item, reload_speed)
				break  # Only reload the first ranged item found
		if item.get_property("Magazine"):
			# Retrieve reload speed from the "Ranged" property dictionary or use the default
			ItemManager.reload_magazine(item)
			update_inventory_list(item, "")
			break  # Only reload the first ranged item found


# When the user requests an unload of the selected item(s) trough the inventory context menu
func _on_context_menu_unload(items: Array[InventoryItem]) -> void:
	for item in items:
		if item.get_property("Ranged") != null:
			ItemManager.unload_magazine_from_item(item)
			break  # Exit after unloading the first ranged item


func _on_inventory_operation_started():
	ui_updates_enabled = false

func _on_inventory_operation_finished():
	ui_updates_enabled = true
	# Optionally, refresh UI components that might have pending updates
	update_ui_post_operation()

func update_ui_post_operation():
	if not ui_updates_enabled:
		return
	# Refresh UI elements that depend on the inventory state
	_populate_inventory_list()
	_update_bars(null, "")


# Returns a list of items that will fit when considering volume
func get_items_that_fit_by_volume(items: Array) -> Array:
	var fitting_items: Array = []
	var remaining_volume = get_remaining_volume()

	# Iterate over the items to check if they can fit
	for item in items:
		var item_volume = item.get_property("volume", 0)
		if item_volume <= remaining_volume:
			fitting_items.append(item)
			remaining_volume -= item_volume

	return fitting_items


func get_used_volume() -> float:
	var total_current_volume = 0.0
	# Calculate the total current volume in the inventory
	for item in myInventory.get_children():
		total_current_volume += item.get_property("volume", 0)
	return total_current_volume


func get_remaining_volume() -> float:
	if myInventory == ItemManager.playerInventory:
		return ItemManager.player_max_inventory_volume - get_used_volume()
	else:
		return max_volume - get_used_volume()

func get_items() -> Array:
	return myInventory.get_children()


# Transfers an item from this inventory to the destination inventory
func transfer_autosplitmerge(item: InventoryItem, destination: InventoryStacked) -> bool:
	return myInventory.transfer_autosplitmerge(item, destination)


# Function to handle item transfer on double-click
func _on_grid_cell_double_clicked(gridCell: Control) -> void:
	# Get the row name of the double-clicked grid cell
	var row_name = _get_row_name(gridCell)
	
	# Ensure the row corresponds to an inventory item
	if inventory_rows.has(row_name):
		var item = inventory_rows[row_name]["item"] as InventoryItem
		if item:
			grid_cell_doubleclicked.emit(item)
