extends Node

# This script functions as a connection point for signals.
# It is indended to aid in communication between nodes during gameplay
# The most significant use case is communication between game entities and the hud
# This script is loaded by Helper.gd and is accessible as Helper.signal_broker

# Signalled to the hud to start a progressbar
signal hud_start_progressbar(time_left: float)

# Will sent out this signal when the user opens or closes the inventory window
# Nodes can use this signal to interrupt actions
signal inventory_window_visibility_changed(inventoryWindow: Control)

# Will sent out this signal when the user opens or closes the build window
# Nodes can use this signal to interrupt actions
signal build_window_visibility_changed(buildWindow: Control)

# Signalled when an items were used
# It can be one or more items. It's up to the receiver to figure it out
signal items_were_used(usedItems: Array[InventoryItem])

# Signalled when an items were used
# It can be one or more items. It's up to the receiver to figure it out
signal health_item_used(usedItem: InventoryItem)

# Signalled when an item was equiped in an equipmentslot
# The item will know what slot it was
signal item_was_equipped(heldItem: InventoryItem, equipmentSlot: Control)

# When an item slot has cleared out, we forward the signal
signal item_slot_cleared(heldItem: InventoryItem, equipmentSlot: Control)


# We signal to the hud to start a progressbar
func on_start_timer_progressbar(time_left: float):
	hud_start_progressbar.emit(time_left)


# Called when the inventorywindow signals a visibility change
# We will forward the signal to anyone that wants it
func on_inventory_visibility_changed(inventoryWindow: Control):
	inventory_window_visibility_changed.emit(inventoryWindow)


# Called when the build menu signals a visibility change
# We will forward the signal to anyone that wants it
func on_build_menu_visibility_changed(inventoryWindow: Control):
	build_window_visibility_changed.emit(inventoryWindow)


# When an equipmentslot has equipped an item
func on_item_equipped(heldItem: InventoryItem, equipmentSlot: Control):
	item_was_equipped.emit(heldItem, equipmentSlot)


# When an equipmentslot has cleared an item
func on_item_slot_cleared(heldItem: InventoryItem, equipmentSlot: Control):
	item_slot_cleared.emit(heldItem, equipmentSlot)
