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
		playerInventory.create_and_add_item("pistol_9mm")
		playerInventory.create_and_add_item("bullet_9mm")
		playerInventory.create_and_add_item("pistol_magazine")
		playerInventory.create_and_add_item("pistol_magazine")
		playerInventory.create_and_add_item("pistol_magazine")
		playerInventory.create_and_add_item("rifle_m4a1")




# This function will loop over the items in the inventory
# It will select items that have the "magazine" property
# It will return the first result if a magazine is found
# It will return null of no magazine is found
func find_compatible_magazine(oldMagazine: InventoryItem) -> InventoryItem:
	var bestMagazine: InventoryItem = null
	var bestAmmo: int = 0  # Variable to track the maximum ammo found

	var inventoryItems: Array = playerInventory.get_items()  # Retrieve all items in the inventory
	for item in inventoryItems:
		if item.get_property("Magazine") and item != oldMagazine:
			var magazine = item.get_property("Magazine")
			if magazine and magazine.has("current_ammo"):
				var currentAmmo: int = int(magazine["current_ammo"])
				if currentAmmo > bestAmmo:
					bestAmmo = currentAmmo
					bestMagazine = item

	return bestMagazine  # Return the magazine with the most current ammo
