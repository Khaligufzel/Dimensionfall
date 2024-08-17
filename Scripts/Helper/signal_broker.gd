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
@warning_ignore("unused_signal")
signal items_were_used(usedItems: Array[InventoryItem])

# Signalled when an items were used
# It can be one or more items. It's up to the receiver to figure it out
@warning_ignore("unused_signal")
signal health_item_used(usedItem: InventoryItem)

# Signalled when an item was equiped in an equipmentslot
# The item will know what slot it was
@warning_ignore("unused_signal")
signal item_was_equipped(heldItem: InventoryItem, equipmentSlot: Control)

# When an item slot has cleared out, we forward the signal
@warning_ignore("unused_signal")
signal item_was_unequipped(heldItem: InventoryItem, equipmentSlot: Control)

# Signalled when an item was equiped in an wearableslot
# The item will know what slot it was
@warning_ignore("unused_signal")
signal wearable_was_equipped(wearableItem: InventoryItem, wearableSlot: Control)

# When an item slot has cleared out, we forward the signal
@warning_ignore("unused_signal")
signal wearable_was_unequipped(wearableItem: InventoryItem, wearableSlot: Control)


# When the player moves and the ItemDetector signals that a container
# has entered or left the player's proximity
@warning_ignore("unused_signal")
signal container_entered_proximity(container: Node3D)
@warning_ignore("unused_signal")
signal container_exited_proximity(container: Node3D)

# When a body entered the player's item detector area3d. This is used to see
# if a container is in proximity of the player. The body_rid is the collider
# of a StaticFurnitureSrv. The item detector only checks layer 7 for objects
@warning_ignore("unused_signal")
signal body_entered_item_detector(body_rid: RID)
@warning_ignore("unused_signal")
signal body_exited_item_detector(body_rid: RID)


# Use these signals to control UI updates. UI only needs an update after the operation is complete
@warning_ignore("unused_signal")
signal inventory_operation_started()
@warning_ignore("unused_signal")
signal inventory_operation_finished()


# Inventory signals
# item: The InventoryItem that was added, removed or modified
# inventory: the InventoryStacked that emitted the original signal of the item being added/removed
@warning_ignore("unused_signal")
signal playerInventory_item_added(item: InventoryItem, inventory: InventoryStacked)
@warning_ignore("unused_signal")
signal playerInventory_item_removed(item: InventoryItem, inventory: InventoryStacked)
@warning_ignore("unused_signal")
signal playerInventory_item_modified(item: InventoryItem, inventory: InventoryStacked)

# When the player's stats and skill changes
@warning_ignore("unused_signal")
signal player_stat_changed(player: CharacterBody3D)
@warning_ignore("unused_signal")
signal player_skill_changed(player: CharacterBody3D)

# Save load start end events
@warning_ignore("unused_signal")
signal game_started() # When the user presses 'play demo' on the main menu
@warning_ignore("unused_signal")
signal game_loaded() # When the user presses 'load game' on the main menu
@warning_ignore("unused_signal")
signal game_ended() # When the game is completely exited and everything is unloaded
@warning_ignore("unused_signal")
signal game_terminated() # When the user presses 'main menu' button on the escape menu
@warning_ignore("unused_signal")
signal player_spawned(player: CharacterBody3D) # When the player has spawned in-game
# When the playerhas moved up or down a level
@warning_ignore("unused_signal")
signal player_y_level_updated(new_y:float) 

# When sprites have been added or removed from gamedata
@warning_ignore("unused_signal")
signal data_sprites_changed(contentData: Dictionary, spriteid: String)

# When a mob was killed
@warning_ignore("unused_signal")
signal mob_killed(mobinstance: Mob)
# The player has interacted with some furniture. We pass the position of the 
# interaction (which is where the interact ray-cast hit the object) and the 
# collider RID of the object that was interacted with.
@warning_ignore("unused_signal")
signal player_interacted(pos: Vector3, collider: RID)

@warning_ignore("unused_signal")
signal initial_chunks_generated() # When the chunks around the player's spawn position are generated


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
