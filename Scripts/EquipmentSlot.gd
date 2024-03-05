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


@export var myInventory: InventoryStacked
@export var backgroundColor: ColorRect
@export var myIcon: TextureRect

var myInventoryItem: InventoryItem = null

# Signals
signal item_equipped(item)
signal item_unequipped

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


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
		emit_signal("item_equipped", myInventoryItem)



# Unequip the current item
func unequip() -> void:
	if myInventoryItem:
		myInventory.add_item(myInventoryItem)
		myInventoryItem = null
		update_icon()
		emit_signal("item_unequipped")
		
func get_item() -> InventoryItem:
	return myInventoryItem

# Update the icon of the equipped item
func update_icon() -> void:
	if myInventoryItem:
		myIcon.texture = myInventoryItem.get_texture()
		myIcon.visible = true
	else:
		myIcon.texture = null
		myIcon.visible = false

# Serialize the equipped item
func serialize() -> Dictionary:
	if myInventoryItem:
		return myInventoryItem.serialize()
	return {}

# Deserialize and equip an item
func deserialize(data: Dictionary) -> void:
	if data.size() > 0:
		var item = InventoryItem.new()
		item.deserialize(data)
		equip(item)
