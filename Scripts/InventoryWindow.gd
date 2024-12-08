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
@export var tool_tip_description_panel: Panel



# Called when the node enters the scene tree for the first time.
func _ready():
	setup_inventory_controls()
	
	LeftHandEquipmentSlot.myInventory = inventory
	RightHandEquipmentSlot.myInventory = inventory
	instantiate_wearable_slots()
	equip_loaded_items()
	# We let the signal broker forward the change in visibility so other nodes can respond
	visibility_changed.connect(Helper.signal_broker.on_inventory_visibility_changed.bind(self))
	Helper.signal_broker.container_entered_proximity.connect(_on_container_entered_proximity)
	Helper.signal_broker.container_exited_proximity.connect(_on_container_exited_proximity)


# Setup player and proximity inventories
func setup_inventory_controls():
	inventory = ItemManager.playerInventory
	proximity_inventory = ItemManager.proximityInventory
	
	initialize_inventory_control(inventory_control, inventory)
	initialize_inventory_control(proximity_inventory_control, proximity_inventory)

func initialize_inventory_control(control: Control, inv: InventoryStacked):
	control.myInventory = inv
	control.initialize_list()
	control.mouse_entered_item.connect(_on_inventory_item_mouse_entered)
	control.mouse_exited_item.connect(_on_inventory_item_mouse_exited)
	control.grid_cell_doubleclicked.connect(_on_grid_cell_double_clicked) 

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
	var slots: Dictionary = Runtimedata.wearableslots.get_all()

	# Clear any dynamically created slots first to avoid duplicates and skip the first two
	while EquipmentSlotList.get_child_count() > 2:
		var last_child = EquipmentSlotList.get_child(EquipmentSlotList.get_child_count() - 1)
		EquipmentSlotList.remove_child(last_child)
		last_child.queue_free()

	# Instantiate and configure a WearableSlotScene for each slot
	for slot in slots.values():
		var slot_instance = WearableSlotScene.instantiate()
		slot_instance.custom_minimum_size.x = 32
		slot_instance.custom_minimum_size.y = 32
		slot_instance.slot_id = slot.id
		slot_instance.myInventory = inventory
		slot_instance.myLabel.text = slot.name
		EquipmentSlotList.add_child(slot_instance)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if is_showing_tooltip:
		tooltip.visible = true
		tooltip.global_position = tooltip.get_global_mouse_position() + Vector2(10, -5 - tooltip.size.y)
	else:
		tooltip.visible = false


func _on_inventory_item_mouse_entered(item: InventoryItem):
	is_showing_tooltip = true
	tooltip_item_name.text = str(item.get_property("name", ""))
	
	var description = item.get_property("description", "")

	description = _append_food_attributes(item, description)
	description = _append_medical_attributes(item, description)
	description = _append_melee_attributes(item, description)
	description = _append_ranged_attributes(item, description)

	tooltip_item_description.text = description
	_set_tooltip_size(description)

# Helper function to set the tooltip size based on the description length
func _set_tooltip_size(description: String):
	var line_count = description.split("\n").size()
	var vertical_size = max(80, line_count * 21)  # Ensure a minimum height of 80
	tool_tip_description_panel.custom_minimum_size = Vector2(240, vertical_size)

# Adds text to the tooltip to display the effects the item has on the attributes
func _append_food_attributes(item: InventoryItem, description: String) -> String:
	var dfood = DItem.Food.new(item.get_property("Food", {}))
	if dfood.attributes:
		description += "\n\nEffects (Food):\n"  # Add a section for food attributes
		for attribute in dfood.attributes:
			var attr_id = attribute.get("id", "Unknown")
			var attr_amount = attribute.get("amount", 0)
			description += "- " + str(attr_id) + ": " + str(attr_amount) + "\n"
	return description


# Adds text to the tooltip to display the effects the item has on the attributes
func _append_medical_attributes(item: InventoryItem, description: String) -> String:
	var dmedical = DItem.Medical.new(item.get_property("Medical", {}))
	if dmedical.attributes or dmedical.amount > 0:
		description += "\n\nEffects (Medical):\n"  # Add a section for medical attributes
		if dmedical.attributes:
			for attribute in dmedical.attributes:
				var attr_id = attribute.get("id", "Unknown")
				var attr_amount = attribute.get("amount", 0)
				var attr_name: String = Runtimedata.playerattributes.by_id(attr_id).name
				
				# Build the line only if there's something to display
				var line = " ►" + attr_name + ":"
				var values = []
				
				if dmedical.amount != 0:
					values.append("(" + str(dmedical.amount) + ")")
				if attr_amount != 0:
					values.append("+" + str(attr_amount))
				
				if values.size() > 0:
					line += " " + "".join(values)
					description += line + "\n"
	return description

# Add text to the tooltip to display the Melee attributes
func _append_melee_attributes(item: InventoryItem, description: String) -> String:
	var dmelee = DItem.Melee.new(item.get_property("Melee", {}))
	if dmelee.damage > 0 or dmelee.reach > 0 or dmelee.used_skill:
		description += "\n\nAttributes (Melee):\n"  # Add a section for melee attributes
		if dmelee.damage > 0:
			description += "- Damage: " + str(dmelee.damage) + "\n"
		if dmelee.reach > 0:
			description += "- Reach: " + str(dmelee.reach) + "\n"
		if dmelee.used_skill:
			description += "- Skill: " + str(dmelee.used_skill.get("skill_id", "Unknown")) + " (XP: " + str(dmelee.used_skill.get("xp", 0)) + ")\n"
	return description

# Add text to the tooltip to display the Ranged attributes
func _append_ranged_attributes(item: InventoryItem, description: String) -> String:
	var dranged = DItem.Ranged.new(item.get_property("Ranged", {}))
	if dranged.firing_speed > 0 or dranged.firing_range > 0 or dranged.recoil > 0 or dranged.reload_speed > 0 or dranged.used_ammo != "" or dranged.used_skill:
		description += "\n\nAttributes (Ranged):\n"  # Add a section for ranged attributes
		if dranged.firing_speed > 0:
			description += "- Firing Speed: " + str(dranged.firing_speed) + "\n"
		if dranged.firing_range > 0:
			description += "- Firing Range: " + str(dranged.firing_range) + "\n"
		if dranged.recoil > 0:
			description += "- Recoil: " + str(dranged.recoil) + "\n"
		if dranged.reload_speed > 0:
			description += "- Reload Speed: " + str(dranged.reload_speed) + "\n"
		if dranged.spread > 0:
			description += "- Spread: " + str(dranged.spread) + "\n"
		if dranged.sway > 0:
			description += "- Sway: " + str(dranged.sway) + "\n"
		if dranged.used_ammo != "":
			description += "- Ammo Type: " + dranged.used_ammo + "\n"
		if dranged.used_magazine != "":
			description += "- Magazine Type: " + dranged.used_magazine + "\n"
		if dranged.used_skill:
			description += "- Skill: " + str(dranged.used_skill.get("skill_id", "Unknown")) + " (XP: " + str(dranged.used_skill.get("xp", 0)) + ")\n"
	return description




func _on_inventory_item_mouse_exited():
	is_showing_tooltip = false


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


# Function to remove a container from the containerLista
func remove_container_from_list(container: Node3D):
	var was_selected = false
	var first_container = null

	# Check if the container being removed is the currently selected one
	if proximity_inventory_control.get_inventory() == container.get_inventory():
		was_selected = true

	# Remove the container from the list
	for child in containerList.get_children():
		if child.containerInstance == container:
			child.queue_free()
			break

	# Find the first non-queued container if it exists
	for child in containerList.get_children():
		if not child.is_queued_for_deletion():
			first_container = child.containerInstance
			break

	# Update the proximity inventory control based on the remaining containers
	if was_selected:
		if first_container and is_instance_valid(first_container):
			var first_container_inventory = first_container.get_inventory()
			if first_container_inventory:
				proximity_inventory_control.set_inventory(first_container_inventory)
		else:
			# Reset the inventory to proximity_inventory and hide the control
			proximity_inventory_control.set_inventory(proximity_inventory)
			proximity_inventory_control.visible = false

	# Ensure visibility of the proximity inventory control based on whether there are remaining containers
	proximity_inventory_control.visible = first_container != null



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
	var success = true

	for item in dest.get_items_that_fit_by_volume(items):
		if not src.transfer_autosplitmerge(item, dest.get_inventory()):
			print_debug("Failed to transfer item: " + str(item))
			success = false

	Helper.signal_broker.inventory_operation_finished.emit()
	return success


# Function to handle double-clicking a grid cell in the inventory grid
func _on_grid_cell_double_clicked(item: InventoryItem):
	var source_inventory = item.get_inventory()
	var destination_inventory: InventoryStacked

	# Determine the destination inventory based on the source inventory
	if source_inventory == inventory:
		# Check if the current proximity inventory is the default set in the ItemManager
		var proximityinventory: InventoryStacked = proximity_inventory_control.get_inventory()
		if proximityinventory == ItemManager.proximityInventory:
			print_debug("Attempt to transfer to default proximity inventory aborted.")
			return  # Exit the function early if the condition is met
		destination_inventory = proximityinventory
		is_showing_tooltip = false
	else:
		destination_inventory = inventory
		is_showing_tooltip = false

	# Attempt to transfer the item
	if not destination_inventory or not source_inventory.transfer_autosplitmerge(item, destination_inventory):
		print("Failed to transfer item!")
