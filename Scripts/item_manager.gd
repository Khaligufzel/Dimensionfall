extends Node


# This script manages the player inventory
# It has functions to add and remove items, reload items and do other manipulations


# The inventory of the player
var playerInventory: InventoryStacked = null
# This inventory will hold items that are close to the player
var proximityInventory: InventoryStacked = null

var proximityInventories = {}  # Dictionary to hold inventories and their items
var allAccessibleItems: Array[InventoryItem] = []  # List to hold all accessible InventoryItems
# The max volume that the inventory can hold. This is extra functionality on top of the "capacity"
# property of the InventoryStacked. An item's "volume" property counts towards this max inventory
# volume, while an item's "weight" property counts towards the inventory's "capacity" property
var player_max_inventory_volume: int = 1000
var item_protosets: Resource = preload("res://ItemProtosets.tres")
 # Keeps track of player equipment, used for saving
var player_equipment: PlayerEquipment = null


signal allAccessibleItems_changed(items_added: Array, items_removed: Array)
signal craft_successful(item: Dictionary, recipe: Dictionary)
signal craft_failed(item: Dictionary, recipe: Dictionary, reason: String)
# Signal to emit when player_max_inventory_volume changes
signal player_max_inventory_volume_changed(new_volume: int)


class PlayerEquipment:
	var LeftHandItem: InventoryItem = null
	var RightHandItem: InventoryItem = null
	var EquipmentItemList: Dictionary = {}

	# Connect signals to relevant functions
	func _init():
		Helper.signal_broker.item_was_equipped.connect(_on_item_was_equipped)
		Helper.signal_broker.item_was_unequipped.connect(_on_item_was_unequipped)
		Helper.signal_broker.wearable_was_equipped.connect(_on_wearable_was_equipped)
		Helper.signal_broker.wearable_was_unequipped.connect(_on_wearable_was_unequipped)

	# Serialize the equipment data into a dictionary
	func serialize() -> Dictionary:
		var player_equipment: Dictionary = {}
		if LeftHandItem:
			player_equipment["LeftHandItem"] = LeftHandItem.serialize()
		if RightHandItem:
			player_equipment["RightHandItem"] = RightHandItem.serialize()
		
		if not EquipmentItemList.is_empty():
			player_equipment["wearables"] = {}
			for slot in EquipmentItemList.keys():
				var item: InventoryItem = EquipmentItemList[slot]
				player_equipment["wearables"][slot] = item.serialize()
		return player_equipment

	# Deserialize the equipment data from a dictionary
	func deserialize(equipment_dict: Dictionary):
		if equipment_dict.has("LeftHandItem"):
			var item = InventoryItem.new()
			item.deserialize(equipment_dict["LeftHandItem"])
			LeftHandItem = item
		if equipment_dict.has("RightHandItem"):
			var item = InventoryItem.new()
			item.deserialize(equipment_dict["RightHandItem"])
			RightHandItem = item

		if equipment_dict.has("wearables"):
			for slot in equipment_dict["wearables"]:
				var item = InventoryItem.new()
				item.deserialize(equipment_dict["wearables"][slot])
				EquipmentItemList[slot] = item
				
	# We keep track of what slots have equipment
	func _on_item_was_equipped(heldItem: InventoryItem, equipmentSlot: Control):
		if equipmentSlot.is_left_slot:
			LeftHandItem = heldItem
		else:
			RightHandItem = heldItem

	func _on_item_was_unequipped(_heldItem: InventoryItem, equipmentSlot: Control):
		if equipmentSlot.is_left_slot:
			LeftHandItem = null
		else:
			RightHandItem = null

	func _on_wearable_was_equipped(wearableItem: InventoryItem, wearableSlot: Control):
		EquipmentItemList[wearableSlot.slot_id] = wearableItem

	func _on_wearable_was_unequipped(_wearableItem: InventoryItem, wearableSlot: Control):
		EquipmentItemList.erase(wearableSlot.slot_id)

	# Reset the player equipment to default values
	func reset_to_default():
		LeftHandItem = null
		RightHandItem = null
		EquipmentItemList.clear()


func _ready():
	# Connect signals for game start, load, and end
	Helper.signal_broker.game_started.connect(_on_game_started_loaded.bind(true))
	Helper.signal_broker.game_loaded.connect(_on_game_started_loaded.bind(false))
	Helper.signal_broker.game_ended.connect(_on_game_ended)
	Helper.signal_broker.player_attribute_changed.connect(_on_player_attribute_changed)
	player_equipment = PlayerEquipment.new()


# This emits a signal with two lists bounded to it
# items_added = All items that were added, or had their count increased
# items_removed = all items that were removed, or had their count decreased
func update_accessible_items_list() -> void:
	var old_items = allAccessibleItems.duplicate(true)  # Make a deep copy of the current list
	var new_items: Array[InventoryItem] = []

	new_items += playerInventory.get_items()
	for inventory: InventoryStacked in proximityInventories.values():
		if is_instance_valid(inventory):
			new_items += inventory.get_items()

	# Use dictionaries to count occurrences since item references won't work across different inventories
	var old_count = count_items(old_items)
	var new_count = count_items(new_items)

	var items_added = []
	var items_removed = []

	# Determine what's been added
	for item: InventoryItem in new_items:
		var item_id = item.prototype_id  # uniquely identify items
		if old_count.get(item_id, 0) < new_count[item_id]:
			items_added.append(item)
			old_count[item_id] = old_count.get(item_id, 0) + 1

	# Determine what's been removed
	for item: InventoryItem in old_items:
		var item_id = item.prototype_id  # uniquely identify items
		if new_count.get(item_id, 0) < old_count[item_id]:
			items_removed.append(item)
			new_count[item_id] = new_count.get(item_id, 0) + 1

	allAccessibleItems = new_items  # Update the accessible items list

	# Emit the signal if there's any change
	if items_added.size() > 0 or items_removed.size() > 0:
		allAccessibleItems_changed.emit(items_added, items_removed)


# Returns a dictionary with the amount of occurrences of the item id
func count_items(items: Array) -> Dictionary:
	var count = {}
	for item in items:
		var item_id = item.prototype_id  # uniquely identify items
		count[item_id] = count.get(item_id, 0) + 1
	return count


func initialize_inventory() -> InventoryStacked:
	var newInventory = InventoryStacked.new()
	newInventory.capacity = 1000
	newInventory.item_protoset = load("res://ItemProtosets.tres")
	return newInventory

func create_starting_items():
	# Create starting equipment. The items are not added to the playerInventory, 
	# only to the equipment slots.
	player_equipment.EquipmentItemList["feet"] = playerInventory.create_item("boots")
	player_equipment.EquipmentItemList["hands"] = playerInventory.create_item("gloves_leather")
	player_equipment.EquipmentItemList["head"] = playerInventory.create_item("hat_baseball")
	player_equipment.EquipmentItemList["legs"] = playerInventory.create_item("jeans")
	player_equipment.EquipmentItemList["torso"] = playerInventory.create_item("jacket")
	player_equipment.EquipmentItemList["back"] = playerInventory.create_item("mailbag")

	if playerInventory.get_children() == []:
		playerInventory.create_and_add_item("bottle_plastic_water")
		playerInventory.create_and_add_item("bread")
		playerInventory.create_and_add_item("apple")
		playerInventory.create_and_add_item("can_soda")
		playerInventory.create_and_add_item("bandage_basic")
		playerInventory.create_and_add_item("bottle_antibiotics")



# The actual reloading is executed on the item
func execute_reloading(item: InventoryItem, magazine: InventoryItem):
	unload_magazine_from_item(item)  # Unload current magazine, if any.
	insert_magazine(item, magazine)  # Load the new magazine.
	item.set_property("is_reloading", false)  # Update reloading state.


# This will start the reload action. General will keep track of the progress
# We pass reload_weapon as a function that will be executed when the action is done
func start_reload(item: InventoryItem, reload_time: float, specific_magazine: InventoryItem = null):
	var reload_callable = Callable(self, "reload_weapon").bind(item, specific_magazine)
	# There's a mechanism to track reloading state for each item using
	# a property in InventoryItem
	item.set_property("is_reloading", true)
	General.start_action(reload_time, reload_callable)


# We remove the magazine from the given item and add it to the inventory
func unload_magazine_from_item(item: InventoryItem) -> void:
	# Check if the item has a magazine loaded
	var myMagazine: InventoryItem = get_magazine(item)
	if myMagazine:
		playerInventory.add_item(myMagazine)
		item.clear_property("current_magazine")


# Get the magazine from the provided item
func get_magazine(item: InventoryItem) -> InventoryItem:
	if not item or not item.get_property("Ranged"):
		return null
	if item.get_property("current_magazine"):
		var myMagazine: InventoryItem = item.get_property("current_magazine")
		return myMagazine
	return null


# We insert the magazine into the provided item from the inventory
# The item is an InventoryItem which should have the ranged property
# The specific_magazine will be loaded into the gun
func insert_magazine(item: InventoryItem, specific_magazine: InventoryItem = null):
	if specific_magazine:
		item.set_property("current_magazine", specific_magazine)
		specific_magazine.get_inventory().remove_item(specific_magazine)  # Remove the magazine from the inventory


# After the reloading timer runs out, the item will be reloaded
func reload_weapon(item: InventoryItem, specific_magazine: InventoryItem = null):
	# Ensure the item is a ranged weapon before proceeding.
	if not item or item.get_property("Ranged") == null:
		print("Item is not a ranged weapon.")
		return

	# Select the appropriate magazine for reloading.
	var magazine_to_load = specific_magazine if specific_magazine else find_compatible_magazine(item)
	if not magazine_to_load:
		print("No compatible magazine found for reloading.")
		return

	# Execute the reloading process.
	execute_reloading(item, magazine_to_load)


# This function will loop over the items in the inventory
# It will select items that are compatible with the gun based on the "used_magazine" property
# It will return the first result if a compatible magazine is found
# It will return null if no compatible magazine is found
func find_compatible_magazine(gun: InventoryItem) -> InventoryItem:
	var bestMagazine: InventoryItem = null
	var bestAmmo: int = 0  # Variable to track the maximum ammo found

	# Get the used_magazine property from the gun's Ranged property
	var ranged_property: String = get_nested_property(gun, "Ranged.used_magazine")
	if ranged_property == null:
		return null  # The gun does not specify which magazines it can use
	var compatible_magazines: PackedStringArray = ranged_property.split(",")

	var inventoryItems: Array = playerInventory.get_items()  # Retrieve all items in the inventory
	for item in inventoryItems:
		if item.get_property("Magazine") and compatible_magazines.has(item.get("prototype_id")):
			var magazine = item.get_property("Magazine")
			if magazine and magazine.has("current_ammo"):
				var currentAmmo: int = int(magazine["current_ammo"])
				if currentAmmo > bestAmmo:
					bestAmmo = currentAmmo
					bestMagazine = item

	return bestMagazine  # Return the compatible magazine with the most current ammo


# This function starts by retrieving the first property using InventoryItem.get_property()
# and then proceeds to fetch nested properties if the first property is a dictionary.
# Example usage: var magazine = get_nested_property(gunitem, "Ranged.used_magazine")
# If magazine: ... rest of the code
func get_nested_property(item: InventoryItem, property_path: String) -> Variant:
	var keys = property_path.split(".")
	if keys.is_empty():
		return null

	# Fetch the first property using the item's get_property method.
	var first_property_value = item.get_property(keys[0])

	# If there are no more keys to process or the first property is not a dictionary,
	# return the value of the first property directly.
	if keys.size() == 1 or not first_property_value is Dictionary:
		return first_property_value

	# Remove the first key as we have already processed it.
	keys.remove_at(0)
	
	# Continue with the nested properties.
	return _get_nested_property_recursive(first_property_value, keys, 0)


# Recursive helper function to navigate through the nested properties.
func _get_nested_property_recursive(current_value: Variant, keys: PackedStringArray, index: int) -> Variant:
	if index >= keys.size() or not current_value:
		return current_value
	var key = keys[index]
	if current_value is Dictionary and current_value.has(key):
		return _get_nested_property_recursive(current_value[key], keys, index + 1)
	else:
		return null  # Key not found


# Function to reload a magazine with bullets
func reload_magazine(magazine: InventoryItem) -> void:
	if magazine and magazine.get_property("Magazine"):
		var magazineProperties = magazine.get_property("Magazine")
		# Get the ammo type required by the magazine
		var ammo_type: String = magazineProperties["used_ammo"]
		
		var current_ammo: int = int(magazineProperties["current_ammo"])
		# Total amount of ammo required to fully load the magazine
		var needed_ammo: int = int(magazineProperties["max_ammo"]) - current_ammo
		
		if needed_ammo <= 0:
			return  # Magazine is already full or has invalid properties
		
		# Initialize a variable to track the total amount of ammo loaded
		var total_ammo_loaded: int = 0
		
		# Find and consume ammo from the inventory
		while needed_ammo > 0:
			var ammo_item: InventoryItem = playerInventory.get_item_by_id(ammo_type)
			if not ammo_item:
				break  # No more ammo of the required type is available
			
			# Calculate how much ammo can be loaded from this stack
			var stack_size: int = InventoryStacked.get_item_stack_size(ammo_item)
			var ammo_to_load: int = min(needed_ammo, stack_size)
			
			# Update totals based on the ammo loaded
			total_ammo_loaded += ammo_to_load
			needed_ammo -= ammo_to_load
			
			# Decrease the stack size of the ammo item in the inventory
			var new_stack_size: int = stack_size - ammo_to_load
			InventoryStacked.set_item_stack_size(ammo_item, new_stack_size)
		
		# Update the current_ammo property of the magazine
		if total_ammo_loaded > 0:
			magazineProperties["current_ammo"] = current_ammo + total_ammo_loaded
			magazine.set_property("Magazine", magazineProperties)


# Function to remove an item from the inventory
func remove_inventory_item(item: InventoryItem) -> bool:
	var iteminventory: InventoryStacked = item.get_inventory()
	if iteminventory.has_item(item):
		if iteminventory.remove_item(item):
			return true
		else:
			print_debug("Failed to remove item from inventory.")
	else:
		print_debug("Item not found in inventory.")
	return false


# The player has selected one or more items in the inventory and selected
# 'use' from the context menu.
func _on_items_used(usedItems: Array[InventoryItem]) -> void:
	for item in usedItems:
		if item.get_property("Food"):  # Check if the item dictionary has the key "food"
			Helper.signal_broker.food_item_used.emit(item)
		if item.get_property("Medical"):
			Helper.signal_broker.medical_item_used.emit(item)


# The user has pressed a button to start crafting
# recipe: The currently selected recipe in the crafting menu
# item: The currently selected item in the itemlist in the crafting menu
func on_crafting_menu_start_craft(item: DItem, recipe: DItem.CraftRecipe):
	if recipe and item:
		# If the player doesn't have the resources, return
		if not CraftingRecipesManager.can_craft_recipe(recipe):
			craft_failed.emit(item, recipe, "Not enough resources!")
			return
		var item_id: String = item.get("id")
		var remaining_volume = get_remaining_volume()
		var item_volume = item.get("volume")
		if item_volume > remaining_volume:
			craft_failed.emit(item, recipe, "Not enough space in inventory!")
			return # The item is too big to fit in the player inventory
		if not remove_required_resources_for_recipe(recipe):
			craft_failed.emit(item, recipe, "Failed to remove resources!")
			return
		var newitem = playerInventory.create_and_add_item(item_id)
		InventoryStacked.set_item_stack_size(newitem, recipe["craft_amount"])
		craft_successful.emit(item, recipe)


# Get the used volume of the player inventory
func get_used_volume() -> float:
	var total_current_volume = 0.0
	# Calculate the total current volume in the inventory
	for item in playerInventory.get_children():
		total_current_volume += item.get_property("volume", 0)
	return total_current_volume


# Get the remaining volume in the player inventory
func get_remaining_volume() -> float:
	return player_max_inventory_volume - get_used_volume()


# Check if there is a sufficient amount of a given item ID across all accessible items
func has_sufficient_item_amount(item_id: String, required_amount: int) -> bool:
	var total_amount = 0

	# Loop through the allAccessibleItems list to count the occurrences of the specified item_id
	for item in allAccessibleItems:
		if item.prototype_id == item_id:
			total_amount += InventoryStacked.get_item_stack_size(item)

	# Check if the total amount meets or exceeds the required amount
	return total_amount >= required_amount


# Function to remove the required resources for a given recipe from the inventory.
func remove_required_resources_for_recipe(recipe: DItem.CraftRecipe) -> bool:
	if "required_resources" not in recipe:
		print("Recipe does not contain required resources.")
		return false

	# Loop through each resource and amount required by the recipe.
	for resource in recipe.required_resources:
		# Check if the inventory has a sufficient amount of each required resource.
		if not remove_resource(resource.get("id"), resource.get("amount")):
			print_debug("Failed to remove required resource:", resource.get("id"), \
			"needed amount:", resource.get("amount"))
			return false  # Return false if we fail to remove the required amount for any resource.

	return true  # If all resources are successfully removed, return true.


# Helper function to remove a specific amount of a resource by ID.
func remove_resource(item_id: String, amount: int) -> bool:
	var items_to_modify = []
	var amount_to_remove = amount

	# Collect all items that match the item_id
	for item in allAccessibleItems:
		if item.prototype_id == item_id:
			items_to_modify.append(item)

	# Try to remove the required amount from the collected items
	for item in items_to_modify:
		if amount_to_remove <= 0:
			break  # Stop if we have removed enough of the item.

		var current_stack_size = InventoryStacked.get_item_stack_size(item)
		if current_stack_size <= amount_to_remove:
			# If the current item stack size is less than or equal to the amount we need to remove,
			# remove this item completely.
			amount_to_remove -= current_stack_size
			if not item.get_inventory().remove_item(item):
				return false  # Return false if we fail to remove the item.
			else:
				allAccessibleItems.erase(item)  # Ensure to update the accessible items list
		else:
			# If the current item stack has more than we need, reduce its stack size.
			var new_stack_size = current_stack_size - amount_to_remove
			if not InventoryStacked.set_item_stack_size(item, new_stack_size):
				return false  # Return false if we fail to set the new stack size.
			amount_to_remove = 0  # Set to 0 as we have removed enough.

	# Check if we have removed the required amount.
	return amount_to_remove == 0


func _on_container_entered_proximity(container: Node3D):
	var containerInventory = container.get_inventory()
	proximityInventories[container] = containerInventory
	connect_inventory_signals(containerInventory)
	update_accessible_items_list()


func _on_container_exited_proximity(container: Node3D):
	if container in proximityInventories:
		disconnect_inventory_signals(proximityInventories[container])
		proximityInventories.erase(container)
	update_accessible_items_list()


func connect_inventory_signals(inventory: Inventory):
	inventory.item_added.connect(_on_inventory_item_added.bind(inventory))
	inventory.item_removed.connect(_on_inventory_item_removed.bind(inventory))
	inventory.item_modified.connect(_on_inventory_item_modified.bind(inventory))


func disconnect_inventory_signals(inventory: Inventory):
	inventory.item_added.disconnect(_on_inventory_item_added)
	inventory.item_removed.disconnect(_on_inventory_item_removed)
	inventory.item_modified.disconnect(_on_inventory_item_modified)


func _on_inventory_item_added(item, inventory):
	Helper.signal_broker.playerInventory_item_added.emit(item, inventory)
	update_accessible_items_list()


func _on_inventory_item_removed(item, inventory):
	Helper.signal_broker.playerInventory_item_removed.emit(item, inventory)
	update_accessible_items_list()


func _on_inventory_item_modified(item, inventory):
	Helper.signal_broker.playerInventory_item_modified.emit(item, inventory)
	update_accessible_items_list()


func add_item_by_id_and_amount(itemid: String, amount: int):
	var newitem = playerInventory.create_and_add_item(itemid)
	InventoryStacked.set_item_stack_size(newitem, amount)


# When the player starts a new game or loads a saved game
# isnew: true when it's a new game. False if it's a loaded game
func _on_game_started_loaded(isnew: bool):
	# Initialize inventories and connect signals
	playerInventory = initialize_inventory()
	proximityInventory = initialize_inventory()
	connect_inventory_signals(playerInventory)
	connect_inventory_signals(proximityInventory)
	if isnew:
		create_starting_items()
	Helper.save_helper.load_player_inventory()
	update_accessible_items_list()  # Initial update for player inventory
	# Connect other signals related to inventory management
	Helper.signal_broker.items_were_used.connect(_on_items_used)
	Helper.signal_broker.container_entered_proximity.connect(_on_container_entered_proximity)
	Helper.signal_broker.container_exited_proximity.connect(_on_container_exited_proximity)


# When the user exits the game and returns to the main menu
func _on_game_ended():
	# Clear and discard the inventories
	playerInventory.queue_free()
	proximityInventory.queue_free()
	player_max_inventory_volume = 1000
	# Disconnect signals related to inventory management
	Helper.signal_broker.items_were_used.disconnect(_on_items_used)
	Helper.signal_broker.container_entered_proximity.disconnect(_on_container_entered_proximity)
	Helper.signal_broker.container_exited_proximity.disconnect(_on_container_exited_proximity)
	disconnect_inventory_signals(playerInventory)
	disconnect_inventory_signals(proximityInventory)
	playerInventory = null
	proximityInventory = null
	allAccessibleItems.clear()
	proximityInventories.clear()


# Handles the update of the attribute when the player attribute changes
func _on_player_attribute_changed(_player_node: CharacterBody3D, attr: PlayerAttribute = null):
	if attr and attr.fixed_mode:  # If a specific attribute has changed
		if attr.id == "inventory_space":
			var newamount: int = int(attr.fixed_mode.get_total_amount())
			set_max_inventory_volume(newamount)


# Loop over all items in the player's inventory
# Sum the stack sizes for each unique item
func count_player_inventory_items_by_id() -> Dictionary:
	var item_counts = {}

	for inv_item: InventoryItem in playerInventory.get_items():
		var item_id = inv_item.prototype_id
		var stack_size = InventoryStacked.get_item_stack_size(inv_item)

		item_counts[item_id] = item_counts.get(item_id, 0) + stack_size

	return item_counts


# Gets the total item amount of the provided id
func get_item_amount(item_id: String) -> int:
	var total_amount = 0
	for inv_item: InventoryItem in playerInventory.get_items():
		if inv_item.prototype_id == item_id:
			var stack_size = InventoryStacked.get_item_stack_size(inv_item)
			total_amount += stack_size

	return total_amount

# Gets the total item amount of the provided id using allAccessibleItems
func get_accessibleitem_amount(item_id: String) -> int:
	var total_amount = 0
	for inv_item: InventoryItem in allAccessibleItems:
		if inv_item.prototype_id == item_id:
			var stack_size = InventoryStacked.get_item_stack_size(inv_item)
			total_amount += stack_size

	return total_amount


# Function to add to the player's maximum inventory volume
func add_to_max_inventory_volume(amount: int) -> void:
	player_max_inventory_volume += amount
	player_max_inventory_volume_changed.emit()

# Function to subtract from the player's maximum inventory volume
func subtract_from_max_inventory_volume(amount: int) -> void:
	player_max_inventory_volume = max(0, player_max_inventory_volume - amount)  # Ensure it doesn't go below 0
	player_max_inventory_volume_changed.emit()

# Function to directly set the player's maximum inventory volume
func set_max_inventory_volume(new_volume: int) -> void:
	player_max_inventory_volume = max(0, new_volume)  # Ensure it doesn't go below 0
	player_max_inventory_volume_changed.emit()
