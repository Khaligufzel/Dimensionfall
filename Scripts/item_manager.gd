extends Node


# This script manages the player inventory
# It has functions to add and remove items, reload items and do other manipulations


# The inventory of the player
var playerInventory: InventoryStacked = null
# This inventory will hold items that are close to the player
var proximityInventory: InventoryStacked = null


func _ready():
	playerInventory = initialize_inventory()
	proximityInventory = initialize_inventory()
	create_starting_items()


func initialize_inventory() -> InventoryStacked:
	var newInventory = InventoryStacked.new()
	newInventory.capacity = 1000
	newInventory.item_protoset = load("res://ItemProtosets.tres")
	return newInventory

func create_starting_items():
	if playerInventory.get_children() == []:
		playerInventory.create_and_add_item("pistol_9mm")
		playerInventory.create_and_add_item("chuganov_mpap")
		playerInventory.create_and_add_item("bullet_9mm")
		playerInventory.create_and_add_item("pistol_magazine")
		playerInventory.create_and_add_item("pistol_magazine")
		playerInventory.create_and_add_item("pistol_magazine")
		playerInventory.create_and_add_item("rifle_m4a1")


# The actual reloading is executed on the item
func execute_reloading(item: InventoryItem, magazine: InventoryItem):
	unload_magazine_from_item(item)  # Unload current magazine, if any.
	insert_magazine(item, magazine)  # Load the new magazine.
	item.set_property("is_reloading", false)  # Update reloading state.


# This will start the reload action. General will keep track of the progress
# We pass reload_weapon as a function that will be executed when the action is done
func start_reload(item: InventoryItem, reload_time: float, specific_magazine: InventoryItem = null):
	var reload_callable = Callable(self, "reload_weapon").bind(item, specific_magazine)
	# Assuming there's a mechanism to track reloading state for each item
	# This could be a property in InventoryItem or managed externally
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
# THe specific_magazine will be loaded into the gun
func insert_magazine(item: InventoryItem, specific_magazine: InventoryItem = null):
	if specific_magazine:
		item.set_property("current_magazine", specific_magazine)
		playerInventory.remove_item(specific_magazine)  # Remove the magazine from the inventory


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
