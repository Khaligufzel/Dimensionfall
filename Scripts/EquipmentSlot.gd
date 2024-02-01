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
# A timer that will prevent the user from reloading while a reload is happening now
@export var otherHandSlot: Control
@export var is_left_slot: bool = true

var myInventoryItem: InventoryItem = null
var myMagazine: InventoryItem = null
# The node that will actually operate the item
var equippedItem: Sprite3D = null
var default_reload_speed: float = 1.0

# Signals
signal item_was_equipped(equippedItem: InventoryItem, equipmentSlot: Control)
signal item_was_cleared(equippedItem: InventoryItem, equipmentSlot: Control)

# Called when the node enters the scene tree for the first time.
func _ready():
	item_was_equipped.connect(Helper.signal_broker.on_item_equipped)
	item_was_cleared.connect(Helper.signal_broker.on_item_slot_cleared)


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
		var is_two_handed: bool = item.get_property("two_handed", false)
		var other_slot_item: InventoryItem = otherHandSlot.get_item()
		# Check if the other slot has a two-handed item equipped
		if other_slot_item and other_slot_item.get_property("two_handed", false):
			print_debug("Cannot equip item. The other slot has a two-handed weapon equipped.")
			return
		
		myInventoryItem = item
		update_icon()
		# Remove the item from its original inventory
		# Not applicable if a game is loaded and we re-equip an item that was alread equipped
		var itemInventory = item.get_inventory()
		if itemInventory and itemInventory.has_item(item):
			item.get_inventory().remove_item(item)	
		
		# If the item is two-handed, clear the other hand slot before equipping
		if is_two_handed:
			otherHandSlot.unequip()
		item_was_equipped.emit(item, self)


# Unequip the current item
func unequip() -> void:
	if myInventoryItem:
		item_was_cleared.emit(myInventoryItem, self)
		myInventoryItem.clear_property("equipped_laft")
		myInventory.add_item(myInventoryItem)
		myInventoryItem = null
		if myMagazine:
			myInventory.add_item(myMagazine)
			myMagazine = null
		update_icon()


# Update the icon of the equipped item
func update_icon() -> void:
	if myInventoryItem:
		myIcon.texture = myInventoryItem.get_texture()
		#myIcon.visible = true
	else:
		myIcon.texture = null
		#myIcon.visible = false


# Serialize the equipped item and the magazine into one dictionary
func serialize() -> Dictionary:
	var data: Dictionary = {}
	if myInventoryItem:
		data["item"] = myInventoryItem.serialize()  # Serialize equipped item
	if myMagazine:
		data["magazine"] = myMagazine.serialize()  # Serialize magazine
	return data


# Deserialize and equip an item and a magazine from the provided data
func deserialize(data: Dictionary) -> void:
	# Deserialize and equip an item
	if data.has("item"):
		var itemData: Dictionary = data["item"]
		var item = InventoryItem.new()
		item.deserialize(itemData)
		equip(item)  # Equip the deserialized item

	if data.has("magazine"):
		var magazineData: Dictionary = data["magazine"]
		var magazine = InventoryItem.new()
		magazine.deserialize(magazineData)
		myMagazine = magazine  # Directly assign the deserialized magazine
		equippedItem.on_magazine_inserted()


# The reload has completed. We now need to remove the current magazine and put in a new one
func reload_weapon(item: InventoryItem, specific_magazine: InventoryItem = null):
	if myInventoryItem and not myInventoryItem.get_property("Ranged") == null and item == myInventoryItem:
		var oldMagazine = myMagazine
		remove_magazine()
		insert_magazine(specific_magazine, oldMagazine)
		equippedItem.is_reloading = false


# This will start the reload action. General will keep track of the progress
# We pass reload_weapon as a function that will be executed when the action is done
func start_reload(item: InventoryItem, reload_time: float, specific_magazine: InventoryItem = null):
	var reload_callable = Callable(self, "reload_weapon").bind(item, specific_magazine)
	equippedItem.is_reloading = true
	General.start_action(reload_time, reload_callable)


func insert_magazine(specific_magazine: InventoryItem = null, oldMagazine: InventoryItem = null):
	if not myInventoryItem or myInventoryItem.get_property("Ranged") == null:
		return  # Ensure the item is a ranged weapon

	var magazine = specific_magazine if specific_magazine else find_compatible_magazine(oldMagazine)
	if magazine:
		myMagazine = magazine
		myInventory.remove_item(magazine)  # Remove the magazine from the inventory
		equippedItem.on_magazine_inserted()


func remove_magazine():
	if not myInventoryItem or not myInventoryItem.get_property("Ranged") or not myMagazine:
		return  # Ensure the item is a ranged weapon

	myInventory.add_item(myMagazine)
	equippedItem.on_magazine_removed()
	myMagazine = null


func get_magazine() -> InventoryItem:
	return myMagazine


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
