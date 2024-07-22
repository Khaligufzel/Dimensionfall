extends Control

# This script is intended to be used with the EquipmentSlot scene
# The equipmentslot will hold one piece of equipment (a weapon)
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
		Helper.signal_broker.item_was_equipped.emit(item, self)
		# We load a magazine if the item contains one
		if item.get_property("current_magazine"):
			equippedItem.on_magazine_inserted()


# Unequip the current item and keep the magazine in the weapon
func unequip() -> void:
	if myInventoryItem:
		Helper.signal_broker.item_was_unequipped.emit(myInventoryItem, self)
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


# Get the currently equipped item
func get_item() -> InventoryItem:
	return myInventoryItem


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
		ItemManager.start_reload(myInventoryItem, equippedItem.reload_speed, magazine)
	else:
		# Equip the item if no weapon is wielded
		equip(magazine)


