extends Control

# This script is intended to be used with the EquipmentSlot scene
# The equipmentslot will hold one piece of equipment
# The equipment will be represented by en InventoryItem
# The equipment will be visualized by a texture provided by the InventoryItem
# There will be signals for equipping, unequipping and clearing the slot
# The user will be able to drop equipment onto this slot to equip it
# When the item is equipped, it will be removed from the inventory that is 
# currently assigned to the InventoryItem
# If the inventory that is assigned to the InventoryItem is different then the player inventory
# when the item is equipped, we will update the inventory of the InventoryItem to be 
# the player inventory
# There will be functions to serialize and deserialize the inventoryitem


# The inventory to pull ammo from and to drop items into
@export var myInventory: InventoryStacked
@export var myInventoryCtrl: Control
@export var backgroundColor: ColorRect
@export var myIcon: TextureRect
# A timer that will prevent the user from reloading while a reload is happening now
@export var otherHandSlot: Control
@export var is_left_slot: bool = true

var myInventoryItem: InventoryItem = null
# The node that will actually operate the item
var equippedItem: Sprite3D = null
var default_reload_speed: float = 1.0

# Signals to commmunicate with the equippedItem node inside the Player node
signal item_was_equipped(equippedItem: InventoryItem, equipmentSlot: Control)
signal item_was_cleared(equippedItem: InventoryItem, equipmentSlot: Control)

# Called when the node enters the scene tree for the first time.
func _ready():
	item_was_equipped.connect(Helper.signal_broker.on_item_equipped)
	item_was_cleared.connect(Helper.signal_broker.on_item_slot_cleared)
	myInventoryCtrl.reload_item.connect(_on_context_menu_reload)
	myInventoryCtrl.unload_item.connect(_on_context_menu_unload)


# Handle GUI input events
func _gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# Check if there's an item equipped and the click is inside the slot
		if myInventoryItem:
			unequip()


# Equip an item
func equip(item: InventoryItem) -> void:
	# First unequip any currently equipped item
	if myInventoryItem:
		unequip()

	if item:
		# Enforce two-handed weapons disallowing dual wielding
		if not handle_two_handed_constraint(item):
			return
		
		myInventoryItem = item
		update_icon()
		# Remove the item from its original inventory
		# Not applicable if a game is loaded and we re-equip an item that was alread equipped
		var itemInventory = item.get_inventory()
		if itemInventory and itemInventory.has_item(item):
			item.get_inventory().remove_item(item)	

		# Tells the equippedItem node in the player node to update the weapon properties
		item_was_equipped.emit(item, self)
		# We load a magazine if the item contains one
		if item.get_property("current_magazine"):
			equippedItem.on_magazine_inserted()


# Unequip the current item and keep the magazine in the weapon
func unequip() -> void:
	if myInventoryItem:
		item_was_cleared.emit(myInventoryItem, self)
		myInventory.add_item(myInventoryItem)
		myInventoryItem = null
		update_icon()


# We make sure a two-handed weapon occupies both slots
# We do this by disallowing the equipping of one slot and the clearing of the other slot
func handle_two_handed_constraint(item: InventoryItem) -> bool:
	var can_equip: bool = true
	var is_two_handed: bool = item.get_property("two_handed", false)
	var other_slot_item: InventoryItem = otherHandSlot.get_item()
	# Check if the other slot has a two-handed item equipped
	if other_slot_item and other_slot_item.get_property("two_handed", false):
		print_debug("Cannot equip item. The other slot has a two-handed weapon equipped.")
		can_equip = false
	else:
		# If the item is two-handed, clear the other hand slot before equipping
		if is_two_handed:
			otherHandSlot.unequip()
	return can_equip


# Update the icon of the equipped item
func update_icon() -> void:
	if myInventoryItem:
		myIcon.texture = myInventoryItem.get_texture()
	else:
		myIcon.texture = null


# Serialize the equipped item and the magazine into one dictionary
# This will happen when the player pressed the travel button on the overmap
func serialize() -> Dictionary:
	var data: Dictionary = {}
	if myInventoryItem:
		# We will separate the magazine from the weapon during serialization
		if myInventoryItem.get_property("current_magazine"):
			var myMagazine: InventoryItem = myInventoryItem.get_property("current_magazine")
			data["magazine"] = myMagazine.serialize()  # Serialize magazine
			myInventoryItem.clear_property("current_magazine")
		data["item"] = myInventoryItem.serialize()  # Serialize equipped item
	return data


# Deserialize and equip an item and a magazine from the provided data
# This will happen when a game is loaded or the player has travelled to a different map
func deserialize(data: Dictionary) -> void:
	# Deserialize and equip an item
	if data.has("item"):
		var itemData: Dictionary = data["item"]
		var item = InventoryItem.new()
		item.deserialize(itemData)
		equip(item)  # Equip the deserialized item

		# If there is a magazine, we create an InventoryItem instance
		# We assign a reference to it in the curretn_magazine of the weapon
		if data.has("magazine"):
			var magazineData: Dictionary = data["magazine"]
			var myMagazine = InventoryItem.new()
			myMagazine.deserialize(magazineData)
			item.set_property("current_magazine", myMagazine)
			equippedItem.on_magazine_inserted()


# The reload has completed. We now need to remove the current magazine and put in a new one
func reload_weapon(item: InventoryItem, specific_magazine: InventoryItem = null):
	if item and not item.get_property("Ranged") == null:
		var oldMagazine: InventoryItem = item.get_property("current_magazine")
		remove_magazine(item)
		insert_magazine(item, specific_magazine, oldMagazine)
		item.set_property("is_reloading", false)  # Mark reloading as complete


# This will start the reload action. General will keep track of the progress
# We pass reload_weapon as a function that will be executed when the action is done
func start_reload(item: InventoryItem, reload_time: float, specific_magazine: InventoryItem = null):
	var reload_callable = Callable(self, "reload_weapon").bind(item, specific_magazine)
	# Assuming there's a mechanism to track reloading state for each item
	# This could be a property in InventoryItem or managed externally
	item.set_property("is_reloading", true)
	General.start_action(reload_time, reload_callable)


# When a reload is completed and we insert the magazine from the inventory
func insert_magazine(item: InventoryItem, specific_magazine: InventoryItem = null, oldMagazine: InventoryItem = null):
	if not item or item.get_property("Ranged") == null:
		return  # Ensure the item is a ranged weapon

	var magazine: InventoryItem = specific_magazine if specific_magazine else find_compatible_magazine(oldMagazine)
	if magazine:
		item.set_property("current_magazine", magazine)
		myInventory.remove_item(magazine)  # Remove the magazine from the inventory


# When a reload is completed and we remove the magazine from the gun into the inventory
func remove_magazine(item: InventoryItem):
	if not item or not item.get_property("Ranged"):
		return  # Ensure the item is a ranged weapon

	var myMagazine: InventoryItem = get_magazine(item)
	if myMagazine:
		myInventory.add_item(myMagazine)
		item.clear_property("current_magazine")


# Get the magazine from the currently equipped item
func get_magazine(item: InventoryItem) -> InventoryItem:
	if not item or not item.get_property("Ranged"):
		return null
	if item.get_property("current_magazine"):
		var myMagazine: InventoryItem = item.get_property("current_magazine")
		return myMagazine
	return null


# Get the currently equipped item
func get_item() -> InventoryItem:
	return myInventoryItem


# This function will loop over the items in the inventory
# It will select items that have the "magazine" property
# It will return the first result if a magazine is found
# It will return null of no magazine is found
func find_compatible_magazine(oldMagazine: InventoryItem) -> InventoryItem:
	var bestMagazine: InventoryItem = null
	var bestAmmo: int = 0  # Variable to track the maximum ammo found

	var inventoryItems: Array = myInventory.get_items()  # Retrieve all items in the inventory
	for item in inventoryItems:
		if item.get_property("Magazine") and item != oldMagazine:
			var magazine = item.get_property("Magazine")
			if magazine and magazine.has("current_ammo"):
				var currentAmmo: int = int(magazine["current_ammo"])
				if currentAmmo > bestAmmo:
					bestAmmo = currentAmmo
					bestMagazine = item

	return bestMagazine  # Return the magazine with the most current ammo



# This function should return true if the dragged data can be dropped here
func _can_drop_data(_newpos, data) -> bool:
	return data is Array[InventoryItem]


# This function handles the data being dropped
func _drop_data(newpos, data):
	if _can_drop_data(newpos, data):
		if data is Array and data.size() > 0 and data[0] is InventoryItem:
			var first_item = data[0]
			# Check if the dropped item is a magazine
			if first_item.get_property("Magazine"):
				_handle_magazine_drop(first_item)
			else:
				# Equip the item if it's not a magazine
				equip(first_item)


# When the user has dropped a magaziene from the inventory
func _handle_magazine_drop(magazine: InventoryItem):
	if myInventoryItem and myInventoryItem.get_property("Ranged"):
		start_reload(myInventoryItem, equippedItem.reload_speed, magazine)
	else:
		# Equip the item if no weapon is wielded
		equip(magazine)


# When the user requests a reload trough the inventory context menu
func _on_context_menu_reload(items: Array[InventoryItem]) -> void:
	for item in items:
		if item.get_property("Ranged") != null:
			# Retrieve reload speed from the "Ranged" property dictionary or use the default
			var ranged_properties = item.get_property("Ranged", {})
			var reload_speed = float(ranged_properties.get("reload_speed", default_reload_speed))
			start_reload(item, reload_speed)
			break  # Only reload the first ranged item found


# When the user requests an unload of the selected item(s) trough the inventory context menu
func _on_context_menu_unload(items: Array[InventoryItem]) -> void:
	for item in items:
		if item.get_property("Ranged") != null:
			unload_magazine_from_item(item)
			break  # Exit after unloading the first ranged item


# We remove the magazine from the given item and add it to the inventory
func unload_magazine_from_item(item: InventoryItem) -> void:
	# Check if the item has a magazine loaded
	if item.get_property("current_magazine"):
		var myMagazine: InventoryItem = item.get_property("current_magazine")
		item.clear_property("current_magazine")  # Remove the magazine from the weapon
		myInventory.add_item(myMagazine)  # Add the magazine back to the inventory
