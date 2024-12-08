extends Control

# This script is intended to be used with the WearableSlot scene
# This script is expected to work with Gamedata.mods.by_id("Core").wearableslots
# The wearable will hold one piece of wearable
# The wearable will be represented by en InventoryItem
# The wearable will be visualized by a texture provided by the InventoryItem
# There will be signals for equipping, unequipping and clearing the slot
# The user will be able to drop wearable onto this slot to equip it
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
@export var myLabel: Label

var myInventoryItem: InventoryItem = null
# The node that will actually operate the item
var equippedItem: Sprite3D = null
var slot_id: String

# Called when the node enters the scene tree for the first time.
func _ready():
	pass


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
		
		myInventoryItem = item
		update_icon()
		# Remove the item from its original inventory
		# Not applicable if a game is loaded and we re-equip an item that was alread equipped
		var itemInventory = item.get_inventory()
		if itemInventory and itemInventory.has_item(item):
			item.get_inventory().remove_item(item)	
			
		Helper.signal_broker.wearable_was_equipped.emit(item, self)


# Unequip the current item and keep the magazine in the weapon
func unequip() -> void:
	if myInventoryItem:
		Helper.signal_broker.wearable_was_unequipped.emit(myInventoryItem, self)
		myInventory.add_item(myInventoryItem)
		myInventoryItem = null
		update_icon()


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
# data is supposed to be an Array[InventoryItem]
func _can_drop_data(_newpos, data) -> bool:
	if data is Array and data.size() > 0 and data[0] is InventoryItem:
		var item = data[0]
		var prototype_id = item.get("prototype_id")

		if prototype_id:
			
			var ditem = Gamedata.items.by_id(prototype_id)
			if ditem and ditem.wearable:
				# Only allow the user to drop the item if it matches the slot id
				return ditem.wearable.slot == slot_id
	return false


# This function handles the data being dropped
func _drop_data(newpos, data):
	if _can_drop_data(newpos, data):
		if data is Array and data.size() > 0 and data[0] is InventoryItem:
			var first_item = data[0]
			equip(first_item)
