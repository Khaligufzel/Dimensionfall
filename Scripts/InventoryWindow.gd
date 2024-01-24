extends Control

# This node holds the data of the items in the container that is selected in the containerList
@export var proximity_inventory: InventoryGridStacked
# This node visualizes the items in the container that is selected in the containerList
@export var proximity_inventory_control: CtrlInventoryGridEx

# The node that visualizes the player inventory
@export var inventory_control : CtrlInventoryGridEx
# The player inventory
@export var inventory : InventoryGridStacked
# Holds a list of containers represented by their sprite
@export var containerList : VBoxContainer
@export var containerListItem : PackedScene

# Equipment
@export var LeftHandEquipmentSlot : ItemSlot
@export var RightHandEquipmentSlot : ItemSlot

# The tooltip will show when the player hovers over an item
@export var tooltip: Control
var is_showing_tooltip = false
@export var tooltip_item_name : Label
@export var tooltip_item_description : Label

signal item_was_equipped(equippedItem: InventoryItem, slotName: String)

# Called when the node enters the scene tree for the first time.
func _ready():
	# The items that were in the player inventory when they exited
	# the previous level are loaded back into the inventory
	inventory.deserialize(General.player_inventory_dict)

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
			item_total_amount += InventoryGridStacked.get_item_stack_size(item)
		if item_total_amount >= current_amount_to_spend:
			return true
	return false

func try_to_spend_item(item_id, amount_to_spend : int):
	var inventory_node = inventory
	if inventory_node.get_item_by_id(item_id):
		var item_total_amount : int = 0
		var current_amount_to_spend = amount_to_spend
		var items = inventory_node.get_items_by_id(item_id)
		
		for item in items:
			item_total_amount += InventoryGridStacked.get_item_stack_size(item)
		
		if item_total_amount >= amount_to_spend:
			merge_items_to_total_amount(items, inventory_node, item_total_amount - current_amount_to_spend)
			return true
		else:
			return false
	else:
		return false

func merge_items_to_total_amount(items, inventory_node, total_amount : int):
	var current_total_amount = total_amount
	for item in items:
		if inventory_node.get_item_stack_size(item) < current_total_amount:
			if inventory_node.get_item_stack_size(item) == item.get_property("max_stack_size"):
				current_total_amount -= inventory_node.get_item_stack_size(item)
			elif inventory_node.get_item_stack_size(item) < item.get_property("max_stack_size"):
				current_total_amount -= item.get_property("max_stack_size") - inventory_node.get_item_stack_size(item)
				inventory_node.set_item_stack_size(item, item.get_property("max_stack_size"))

		elif inventory_node.get_item_stack_size(item) == current_total_amount:
			current_total_amount = 0

		elif inventory_node.get_item_stack_size(item) > current_total_amount:
			inventory_node.set_item_stack_size(item, current_total_amount)
			current_total_amount = 0

			if inventory_node.get_item_stack_size(item) == 0:
				inventory_node.remove_item(item)

func _on_crafting_menu_start_craft(recipe):
	if recipe:
		#first we need to use required resources for the recipe
		for required_item in recipe["required_resource"]:
			try_to_spend_item(required_item, recipe["required_resource"][required_item])
		#adding a new item(s) to the inventory based on the recipe
		var item
		item = inventory.create_and_add_item(recipe["crafts"])
		InventoryGridStacked.set_item_stack_size(item, recipe["craft_amount"])


# When an item is added to the player inventory
# We check where it came from and delete it from that inventory
# This happens when the player moves an item from $CtrlInventoryGridExProx
func _on_inventory_grid_stacked_item_added(item):
	if item.has_meta("original_parent"):
		var original_parent = item.get_meta("original_parent")
		var original_item = item.get_meta("original_item")
		if original_parent and original_parent.has_method("remove_item"):
			original_parent.remove_item(original_item)  # Remove from original parent 
			
func get_inventory() -> InventoryGridStacked:
	return inventory

# Signal handler for adding a container to the proximity
func _on_item_detector_add_to_proximity_inventory(container: Node3D):
	add_container_to_list(container)

# Signal handler for removing a container from the proximity
func _on_item_detector_remove_from_proximity_inventory(container: Node3D):
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
			proximity_inventory_control.inventory = container_inventory
			# Make the proximity inventory control visible
			proximity_inventory_control.visible = true


# Function to update the proximity inventory control when a container is selected
func _on_container_clicked(containerListItemInstance: Control):
	if containerListItemInstance and containerListItemInstance.containerInstance:
		var container_inventory = containerListItemInstance.containerInstance.get_inventory()
		if container_inventory:
			proximity_inventory_control.inventory = container_inventory

# Function to remove a container from the containerList
func remove_container_from_list(container: Node3D):
	var was_selected = false
	var first_container = null

	# Check if the container being removed is the currently selected one
	if proximity_inventory_control.inventory == container.get_inventory():
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
			proximity_inventory_control.inventory = first_container_inventory
	elif was_selected or remaining_containers == 0:
		# Reset the inventory to proximity_inventory and hide the control
		proximity_inventory_control.inventory = proximity_inventory
		proximity_inventory_control.visible = false


func _on_left_hand_equipment_slot_item_equipped():
	item_was_equipped.emit(LeftHandEquipmentSlot.get_item(), "LeftHand")


func _on_right_hand_equipment_slot_item_equipped():
	item_was_equipped.emit(RightHandEquipmentSlot.get_item(), "RightHand")
