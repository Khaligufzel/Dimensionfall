extends Control

@export var proximity_inventory: InventoryGridStacked
@export var proximity_inventory_control: CtrlInventoryGridEx

@export var inventory_control : CtrlInventoryGridEx
@export var inventory : InventoryGridStacked


@export var tooltip: Control
var is_showing_tooltip = false
@export var tooltip_item_name : Label
@export var tooltip_item_description : Label




# Called when the node enters the scene tree for the first time.
func _ready():
	inventory.deserialize(General.player_inventory_dict)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if is_showing_tooltip:
		tooltip.visible = true
		tooltip.global_position = tooltip.get_global_mouse_position() + Vector2(0, -5 - tooltip.size.y)
	else:
		tooltip.visible = false

# The parameter items isall the items from the inventory that has entered proximity
func _on_item_detector_add_to_proximity_inventory(items):
	var duplicated_items = items
	for item in duplicated_items:
		var duplicated_item = item.duplicate()
		# Store the original inventory
		duplicated_item.set_meta("original_parent", item.get_inventory())
		duplicated_item.set_meta("original_item", item)
		proximity_inventory.add_child(duplicated_item)

# The parameter items is all the items from the inventory that has left proximity
func _on_item_detector_remove_from_proximity_inventory(items):
	for prox_item in proximity_inventory.get_children():
		for item in items:
			if item.get_property("assigned_id") == prox_item.get_property("assigned_id"):
				prox_item.queue_free()


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
