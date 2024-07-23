extends Control

# This node holds the data of the items in the container that is selected in the containerList
@export var proximity_inventory: InventoryStacked
# This node visualizes the items in the container that is selected in the containerList
@export var proximity_inventory_control: Control

# The node that visualizes the player inventory
@export var inventory_control : Control
# The player inventory
@export var inventory : InventoryStacked
# Holds a list of containers represented by their sprite
@export var containerList : VBoxContainer
@export var containerListItem : PackedScene

# Equipment
@export var EquipmentSlotList : VBoxContainer
@export var WearableSlotScene : PackedScene
@export var LeftHandEquipmentSlot : Control
@export var RightHandEquipmentSlot : Control

# The tooltip will show when the player hovers over an item
@export var tooltip: Control
var is_showing_tooltip = false
@export var tooltip_item_name : Label
@export var tooltip_item_description : Label


# Called when the node enters the scene tree for the first time.
func _ready():
	inventory = ItemManager.playerInventory
	inventory_control.myInventory = inventory
	inventory_control.initialize_list()
	proximity_inventory = ItemManager.proximityInventory
	proximity_inventory_control.myInventory = proximity_inventory
	proximity_inventory_control.initialize_list()
	
	LeftHandEquipmentSlot.myInventory = inventory
	RightHandEquipmentSlot.myInventory = inventory
	instantiate_wearable_slots()
	equip_loaded_items()
	# We let the signal broker forward the change in visibility so other nodes can respond
	visibility_changed.connect(Helper.signal_broker.on_inventory_visibility_changed.bind(self))
	Helper.signal_broker.container_entered_proximity.connect(_on_container_entered_proximity)
	Helper.signal_broker.container_exited_proximity.connect(_on_container_exited_proximity)


# If any items are present in the player equipment, load them
func equip_loaded_items():
	if ItemManager.player_equipment.LeftHandItem:
		LeftHandEquipmentSlot.equip(ItemManager.player_equipment.LeftHandItem)
	if ItemManager.player_equipment.RightHandItem:
		RightHandEquipmentSlot.equip(ItemManager.player_equipment.RightHandItem)

	var wearablelist: Dictionary = ItemManager.player_equipment.EquipmentItemList
	var counter = 0
	for slot in EquipmentSlotList.get_children():
		if counter < 2:
			counter += 1
			continue
		if wearablelist.has(slot.slot_id):
			slot.equip(wearablelist[slot.slot_id])


# Gets the slots that are defined in json and instatiates WearableSlotScene
# for each of the slots. It will add the instances to EquipmentSlotList
# The first to children of EquipmentSlotList are static slots and we should ignore them
# It will get the "name" property from the slot data and set it to the instance's "myLabel" property
func instantiate_wearable_slots():
	var slots = Gamedata.data.wearableslots.data

	# Clear any dynamically created slots first to avoid duplicates and skip the first two
	while EquipmentSlotList.get_child_count() > 2:
		var last_child = EquipmentSlotList.get_child(EquipmentSlotList.get_child_count() - 1)
		EquipmentSlotList.remove_child(last_child)
		last_child.queue_free()

	# Instantiate and configure a WearableSlotScene for each slot
	for slot in slots:
		var slot_instance = WearableSlotScene.instantiate()
		slot_instance.custom_minimum_size.x = 32
		slot_instance.custom_minimum_size.y = 32
		slot_instance.slot_id = slot.get("id")
		slot_instance.myInventory = inventory
		if slot.has("name"):
			slot_instance.myLabel.text = slot["name"]  # Assuming the instance has a Label node named 'myLabel'
		EquipmentSlotList.add_child(slot_instance)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if is_showing_tooltip:
		tooltip.visible = true
		tooltip.global_position = tooltip.get_global_mouse_position() + Vector2(0, -5 - tooltip.size.y)
	else:
		tooltip.visible = false


func _on_inventory_item_mouse_entered(item):
	is_showing_tooltip = true
	tooltip_item_name.text = str(item.get_property("name", ""))
	tooltip_item_description.text = item.get_property("description", "")


func _on_inventory_item_mouse_exited(_item):
	is_showing_tooltip = false


func check_if_resources_are_available(item_id, amount_to_spend: int):
	var inventory_node = inventory
	print("checking if we have the item id in inv")
	if inventory_node.get_item_by_id(item_id):
		print("we have the item id")
		var item_total_amount : int = 0
		var current_amount_to_spend = amount_to_spend
		var items = inventory_node.get_items_by_id(item_id)
		for item in items:
			item_total_amount += InventoryStacked.get_item_stack_size(item)
		if item_total_amount >= current_amount_to_spend:
			return true
	return false


# When an item is added to the player inventory
# We check where it came from and delete it from that inventory
# This happens when the player moves an item from $CtrlInventoryGridExProx
func _on_inventory_grid_stacked_item_added(item):
	if item.has_meta("original_parent"):
		var original_parent = item.get_meta("original_parent")
		var original_item = item.get_meta("original_item")
		if original_parent and original_parent.has_method("remove_item"):
			original_parent.remove_item(original_item)  # Remove from original parent 


func get_inventory() -> InventoryStacked:
	return inventory


# Signal handler for adding a container to the proximity
func _on_container_entered_proximity(container: Node3D):
	add_container_to_list(container)


# Signal handler for removing a container from the proximity
func _on_container_exited_proximity(container: Node3D):
	remove_container_from_list(container)


# Function to add a container to the containerList
func add_container_to_list(container: Node3D):
	# Create a new instance of the containerlistitem node
	var containerListItemInstance = containerListItem.instantiate()
	# Assign the texture to the TextureRect
	containerListItemInstance.set_item_texture(container.get_sprite())
	# We save a reference to the container
	containerListItemInstance.containerInstance = container
	containerListItemInstance.containerlistitem_clicked.connect(_on_container_clicked)
	containerList.add_child(containerListItemInstance)

	# Check if this is the only container in the list
	if containerList.get_child_count() == 1:
		# Set the inventory of the proximity inventory control to this container's inventory
		var container_inventory = containerListItemInstance.containerInstance.get_inventory()
		if container_inventory:
			proximity_inventory_control.set_inventory(container_inventory)
			# Make the proximity inventory control visible
			proximity_inventory_control.visible = true


# Function to update the proximity inventory control when a container is selected
func _on_container_clicked(containerListItemInstance: Control):
	if containerListItemInstance and containerListItemInstance.containerInstance:
		var container_inventory = containerListItemInstance.containerInstance.get_inventory()
		if container_inventory:
			proximity_inventory_control.set_inventory(container_inventory)


# Function to remove a container from the containerList
func remove_container_from_list(container: Node3D):
	var was_selected = false
	var first_container = null

	# Check if the container being removed is the currently selected one
	if proximity_inventory_control.get_inventory() == container.get_inventory():
		was_selected = true

	# Remove the container from the list and count remaining containers
	var remaining_containers = 0
	for child in containerList.get_children():
		if child.containerInstance == container:
			child.queue_free()
		elif not child.is_queued_for_deletion():  # Only count children not queued for deletion
			remaining_containers += 1
			if first_container == null:
				first_container = child.containerInstance

	# If the removed container was selected, update the inventory to the first remaining container's inventory
	if was_selected and remaining_containers > 0:
		var first_container_inventory = first_container.get_inventory()
		if first_container_inventory:
			proximity_inventory_control.set_inventory(first_container_inventory)
	elif was_selected or remaining_containers == 0:
		# Reset the inventory to proximity_inventory and hide the control
		proximity_inventory_control.set_inventory(proximity_inventory)
		proximity_inventory_control.visible = false


# Called when the user has pressed a button that will equip the selected item
func _on_ctrl_inventory_stacked_custom_equip_left(items: Array[InventoryItem]):
	equip_item(items, LeftHandEquipmentSlot)


# Called when the user has pressed a button that will equip the selected item
func _on_ctrl_inventory_stacked_custom_equip_right(items: Array[InventoryItem]):
	equip_item(items, RightHandEquipmentSlot)


# Handles equipping of items into the hand slots
func equip_item(items: Array[InventoryItem], itemSlot: Control) -> void:
	var num_selected_items = items.size()

	if num_selected_items == 0:
		print_debug("No items selected.")
		# Handle the case when no items are selected (optional)
	elif num_selected_items == 1:
		itemSlot.equip(items[0])
	else:
		print_debug("Multiple items selected. Please select only one item to equip.")


func _on_transfer_all_left_button_button_up():
	# Check if the current proximity inventory is the default set in the ItemManager
	if proximity_inventory_control.get_inventory() == ItemManager.proximityInventory:
		print_debug("Attempt to transfer to default proximity inventory aborted.")
		return  # Exit the function early if the condition is met

	var items_to_transfer = inventory.get_items()
	var favorite_items = []
	var non_favorite_items = []

	# Separate items into favorite and non-favorite lists
	for item in items_to_transfer:
		if item.get_property("favorite", false):
			favorite_items.append(item)
		else:
			non_favorite_items.append(item)

	# Decide on the transfer strategy based on the content of the lists
	if non_favorite_items.size() > 0:
		transfer_autosplitmerge_list(non_favorite_items, inventory_control, proximity_inventory_control)
	elif favorite_items.size() > 0:
		transfer_autosplitmerge_list(favorite_items, inventory_control, proximity_inventory_control)


# The player is going to move items from some container into his inventory
func _on_transfer_all_right_button_button_up():
	# Attempt to transfer each item from the proximity inventory to the inventory until no items are left
	var items_to_transfer = proximity_inventory_control.get_items()
	transfer_autosplitmerge_list(items_to_transfer, proximity_inventory_control, inventory_control)


# Items are transferred from the right list to the left list
func _on_transfer_left_button_button_up():
	# Check if the current proximity inventory is the default set in the ItemManager
	if proximity_inventory_control.get_inventory() == ItemManager.proximityInventory:
		print_debug("Attempt to transfer to default proximity inventory aborted.")
		return  # Exit the function early if the condition is met
	var selected_items: Array[InventoryItem] = inventory_control.get_selected_inventory_items()
	transfer_autosplitmerge_list(selected_items, inventory_control, proximity_inventory_control)


# Items are transferred from the left list to the right list
func _on_transfer_right_button_button_up():
	var items: Array[InventoryItem] = proximity_inventory_control.get_selected_inventory_items()
	transfer_autosplitmerge_list(items, proximity_inventory_control, inventory_control)


# Transfers a list of items from src to dest
# items = an array of InventoryItems
# src = a CtrlInventoryStackedCustom control from which to move the items
# dest = a CtrlInventoryStackedCustom control to which to move the items
func transfer_autosplitmerge_list(items: Array, src: Control, dest: Control) -> bool:
	Helper.signal_broker.inventory_operation_started.emit()
	var success: bool = true
	# Get the items that fit inside the remaining volume
	var items_to_transfer = dest.get_items_that_fit_by_volume(items)
	for item in items_to_transfer:
		if src.transfer_autosplitmerge(item, dest.get_inventory()):
			print_debug("Transferred item: " + str(item))
		else:
			print_debug("Failed to transfer item: " + str(item))
			success = false
	Helper.signal_broker.inventory_operation_finished.emit()
	return success
