extends Node

# This script is loaded into the helper.gd autoload singleton
# It can be accessed through Helper.quest_helper
# This is a helper script that manages quests in so far that the QuestManager can't

# When a quest updates and there either is or isn't a target location on the overmap
# map_ids: An array of map IDs that are potential targets.
# target_properties: A dictionary containing:
#   - reveal_condition (String): One of "HIDDEN", "REVEALED", "EXPLORED", "VISITED".
#     Determines how the target is selected based on its reveal state.
#   - exact_match (bool, default: false): If true, only exact matches for the reveal_condition are valid.
#   - dynamic (bool, default: false): If true, and the player is currently on the target cell,
#     a new target will be selected.
signal target_map_changed(map_id: String, target_properties)
# Array to track currently equipped items
var equipped_items: Array = []
# Variable to keep track of the currently tracked quest
var tracked_quest: String:
	set(value):
		if tracked_quest == value:
			return  # No change, do nothing
		tracked_quest = value
		if tracked_quest == "":
			print("No quest selected to track.")
			return

		# Get the quest's current step
		var current_step = QuestManager.get_current_step(tracked_quest)
		if current_step == null:
			print("Quest has no active steps or is null.")
			return

		# Check if the current step is completed
		if current_step.get("complete", false):
			print("The current step of the quest is already complete.")
			return

		# Call check_and_emit_target_map to manage the map targeting for the quest
		check_and_emit_target_map(current_step)


func _ready():
	# Connect signals for game start, load, end, mob killed, and quest events
	connect_signals()


# Connect signals for game start, load, end, mob killed, and quest events
func connect_signals() -> void:
	# Connect to the Helper.signal_broker.game_started signal
	Helper.signal_broker.game_started.connect(_on_game_started)
	Helper.signal_broker.game_ended.connect(_on_game_ended)
	
	# Connect to the Helper.signal_broker.game_loaded signal
	Helper.signal_broker.game_loaded.connect(_on_game_loaded)
	
	# Connect to misc game event signals
	Helper.signal_broker.mob_killed.connect(_on_mob_killed)
	Helper.overmap_manager.player_coord_changed.connect(_on_map_entered)
	ItemManager.craft_successful.connect(_on_craft_successful)
	
	
	# Connect to the QuestManager signals
	QuestManager.quest_completed.connect(_on_quest_complete)
	QuestManager.quest_failed.connect(_on_quest_failed)
	QuestManager.step_complete.connect(_on_step_complete)
	QuestManager.next_step.connect(_on_next_step)
	QuestManager.step_updated.connect(_on_step_updated)
	QuestManager.new_quest_added.connect(_on_new_quest_added)
	QuestManager.quest_reset.connect(_on_quest_reset)
	
	# When the user has pressed the "track" button in the quest window
	Helper.signal_broker.track_quest_clicked.connect(_on_quest_window_track_quest_clicked)
	# Connect equipment signals
	Helper.signal_broker.item_was_equipped.connect(_on_item_was_equipped)
	Helper.signal_broker.item_was_unequipped.connect(_on_item_was_unequipped)


func connect_inventory_signals() -> void:
	if not Helper.signal_broker.playerInventory_item_added.is_connected(_on_inventory_changed):
		Helper.signal_broker.playerInventory_item_added.connect(_on_inventory_changed)
	if not Helper.signal_broker.playerInventory_item_removed.is_connected(_on_inventory_changed):
		Helper.signal_broker.playerInventory_item_removed.connect(_on_inventory_changed)
	if not Helper.signal_broker.playerInventory_item_modified.is_connected(_on_inventory_changed):
		Helper.signal_broker.playerInventory_item_modified.connect(_on_inventory_changed)


# Function for handling game started signal
func _on_game_started():
	connect_inventory_signals()
	initialize_quests()


# Function for handling game loaded signal
func _on_game_loaded():
	connect_inventory_signals()
	var current_step = QuestManager.get_current_step(tracked_quest) # Get the quest's current step
	check_and_emit_target_map(current_step) # Puts the quest marker on the overmap

# Function for handling game ended signal
func _on_game_ended():
	equipped_items.clear()
	tracked_quest = ""
	pass


# Function to handle quest completion
func _on_quest_complete(quest: Dictionary):
	target_map_changed.emit([])  # No more target when quest is complete
	var rewards: Array = quest.get("quest_rewards").get("rewards", [])
	for reward in rewards:
		var item_id: String = reward.get("item_id")
		var amount: int = reward.get("amount")
		ItemManager.add_item_by_id_and_amount(item_id, amount)


# Function to handle quest failure
func _on_quest_failed(_quest: Dictionary):
	target_map_changed.emit([])  # No more target when quest is failed

# When a step is complete.
# step: the step dictionary
func _on_step_complete(step: Dictionary):
	check_and_emit_target_map(step)


# Called after the previous step was completed
# step: the new step in the quest
func _on_next_step(step: Dictionary):
	check_and_emit_target_map(step)
	process_active_quests()  # Centralized quest description update

	# The player might already have the item for the next step, so check it
	match step.get("step_type", ""):	
		QuestManager.INCREMENTAL_STEP, QuestManager.ITEMS_STEP:
			update_quest_by_inventory(null)


# Function to handle step update
func _on_step_updated(step: Dictionary):
	check_and_emit_target_map(step)


# Function to handle new quest addition
func _on_new_quest_added(_quest_name: String):
	# To be developed later
	pass


# Function to handle quest reset
func _on_quest_reset(_quest_name: String):
	# To be developed later
	pass


# Initialize quests by wiping player data and loading quest data
func initialize_quests():
	QuestManager.wipe_player_data()
	for quest: RQuest in Runtimedata.quests.get_all().values():
		create_quest_from_data(quest)


# Takes a quest as defined by json (created in the contenteditor)
# Create an instance of a ScriptQuest and add it to the QuestManager
func create_quest_from_data(quest_data: RQuest):
	if quest_data.steps.size() < 1:
		return # The quest has no steps
	var quest = ScriptQuest.new(quest_data.id, quest_data.description)
	var steps_added: bool = false
	for step in quest_data.steps:
		steps_added = add_quest_step(quest, step) or steps_added

	if steps_added:
		quest.set_rewards({"rewards": quest_data.rewards})
		# Finalize
		quest.finalize_quest()
		# Add quest to player quests
		QuestManager.add_scripted_quest(quest)


# Add a quest step to the quest. In this case, the step is just a dictionary with some data
# Example step dictionary:
#	{
#		"amount": 1,
#		"item": "long_stick",
#		"tip": "You can find one in the forest",
#		"description": "This stick will help figure out the truth!", # updates the quest description
#		"type": "collect"
#	}
func add_quest_step(quest: ScriptQuest, step: Dictionary) -> bool:
	match step.type:
		"collect":
			# Add an incremental step for collecting items
			quest.add_incremental_step("Gather items", step.item, step.amount, {"stepjson": step})
			return true
		"kill":
			# Determine whether the step references a mob or a mobgroup
			if step.has("mob"):
				# Add an incremental step for killing a specific mob
				quest.add_incremental_step("Kill mob", step.mob, step.amount, {"stepjson": step})
			elif step.has("mobgroup"):
				# Add an incremental step for killing mobs in a specific mobgroup
				quest.add_incremental_step("Kill mob group", step.mobgroup, step.amount, {"stepjson": step})
			else:
				print_debug("Kill step is missing 'mob' or 'mobgroup'.")
				return false
			return true
		"craft":
			# Add an action step for crafting an item
			quest.add_action_step("Craft a " + Runtimedata.items.by_id(step.item).name, {"stepjson": step})
			return true
		"enter":
			# Add an action step for entering a specific map
			var map_name: String = Runtimedata.maps.by_id(step.map_id).name
			quest.add_action_step("Travel to " + map_name, {"stepjson": step})
			return true
		"spawn_item":
			# Add an action step for spawning an item on the map
			quest.add_action_step("Spawn " + Runtimedata.items.by_id(step.item).name + " on map", {"stepjson": step})
			return true
		"spawn_mob":
			# Add an action step for spawning a mob when approaching a map
			var mob_name: String = Runtimedata.mobs.by_id(step.mob).name
			var map_name: String = Runtimedata.maps.by_id(step.map_id).name
			quest.add_action_step("Approach " + map_name + " to spawn " + mob_name, {"stepjson": step})
			return true
	return false

func _on_inventory_changed(item: InventoryItem, _inventory: InventoryStacked) -> void:
	update_quest_by_inventory(item)

# Update the quest progress based on the items in the player's inventory and equipped items.
# For each quest, we ONLY update the step that the quest is currently at
func update_quest_by_inventory(item: InventoryItem):
	# Dictionary to keep track of the total count of each item
	var item_counts = ItemManager.count_player_inventory_items_by_id()

	# Include counts for equipped items
	for equipped_item in equipped_items:
		if equipped_item.prototype_id in item_counts:
			item_counts[equipped_item.prototype_id] += 1
		else:
			item_counts[equipped_item.prototype_id] = 1

	# Check if the player has the item; if not, set its count to 0
	if item and not ItemManager.playerInventory.has_item_by_id(item.prototype_id) and item not in equipped_items:
		item_counts[item.prototype_id] = 0

	# Get the current quests in progress
	var quests_in_progress = QuestManager.get_quests_in_progress()

	# Update each of the current quests with the collected item information
	for quest in quests_in_progress.values():
		for item_id in item_counts.keys():
			# Call the extracted function to update the quest step
			update_quest_step(quest.quest_name, item_id, item_counts[item_id])


# This function updates a specific quest step based on the item counts
# Parameters:
# - myquestname: The name of the quest being updated
# - step: The current step of the quest
# - item_id: The ID of the item being processed
# - item_count: The count of the item in the player's inventory
func update_quest_step(myquestname: String, item_id: String, item_count: int, add: bool = false) -> void:
	var step = QuestManager.get_current_step(myquestname)
	match step.get("step_type", ""):	
		QuestManager.INCREMENTAL_STEP:
			if step.item_name == item_id:
				# Update the quest step items with the collected count
				# Since progress_quest adds the amount, we have to set it to 0 first
				if not add:
					QuestManager.set_quest_step_items(myquestname, item_id, 0)
				# Mark the step as incomplete
				step["complete"] = false
				# Progress the quest with the collected item count
				QuestManager.progress_quest(myquestname, item_id, item_count)
		QuestManager.ITEMS_STEP:
			# Update the quest step items with the collected count
			QuestManager.set_quest_step_items(myquestname, item_id, 0, true)
			# Progress the quest
			QuestManager.progress_quest(myquestname, item_id)


# A mob has been killed. TODO: Add who or what killed it so we know if it was the player
func _on_mob_killed(mobinstance: Mob):
	var mob_id: String = mobinstance.mobJSON.id
	var quests_in_progress = QuestManager.get_quests_in_progress()

	# Update each of the current quests with the collected item information
	# Check quests for direct mob or mobgroup associations
	for quest in quests_in_progress.values():
		var step = QuestManager.get_current_step(quest.quest_name)
		var stepmeta: Dictionary = step.get("meta_data", {}).get("stepjson", {})
		if stepmeta.get("type", "") == "kill":
			if stepmeta.has("mob") and stepmeta["mob"] == mob_id:
				update_quest_step(quest.quest_name, mob_id, 1, true)
			elif stepmeta.has("mobgroup"):
				var group_id = stepmeta["mobgroup"]
				if Runtimedata.mobgroups.by_id(group_id).has_mob(mob_id):
					update_quest_step(quest.quest_name, group_id, 1, true)


# The player has succesfully crafted an item.
func _on_craft_successful(item: RItem, _recipe: RItem.CraftRecipe):
	# Get the current quests in progress
	var quests_in_progress = QuestManager.get_quests_in_progress()
	# Update each of the current quests with the collected item information
	for quest in quests_in_progress.values():
		var step = QuestManager.get_current_step(quest.quest_name)
		if step.step_type == QuestManager.ACTION_STEP:
			var stepmeta: Dictionary = step.meta_data.get("stepjson", {})
			if stepmeta.type == "craft":
				# This quest's current step is a craft step
				if stepmeta.item == item.id:
					# The item that was crafted has the same id as the item in this step
					QuestManager.progress_quest(quest.quest_name)


# Function to handle player entering a map
# map_id: The ID of the map that the player has entered
func _on_map_entered(_player: Player, _old_pos: Vector2, new_pos: Vector2):
	# Get the current quests in progress
	var quests_in_progress = QuestManager.get_quests_in_progress()

	# Update each of the current quests with the entered map information
	for quest in quests_in_progress.values():
		var step = QuestManager.get_current_step(quest.quest_name)
		if not step:
			continue

		var stepmeta: Dictionary = step.get("meta_data", {}).get("stepjson", {})

		# Handle action_step type "enter"
		if step.step_type == "action_step" and stepmeta.get("type", "") == "enter":
			var map_cell = Helper.overmap_manager.get_map_cell_by_local_coordinate(new_pos)
			var map_id: String = stepmeta.get("map_id", "")
			if map_cell and map_id == map_cell.map_id:
				# The player has entered the correct map for the quest step
				QuestManager.progress_quest(quest.quest_name)

		# Handle action_step type "spawn_mob"
		elif step.step_type == "action_step" and stepmeta.get("type", "") == "spawn_mob":
			# Make sure the coordinate is set
			if stepmeta.has("coordinate"):
				var target_coordinate: Vector2 = General.string_to_vector2(stepmeta["coordinate"])
				var chunk = Helper.map_manager.get_chunk_from_overmap_coordinate(target_coordinate)

				# When the map at the coordinate is instantiated, spawn the mob
				if chunk != null:
					var mob_id = stepmeta.get("mob", "")
					Helper.map_manager.spawn_mob_at_nearby_map(mob_id, target_coordinate)

					# Complete the step
					QuestManager.progress_quest(quest.quest_name)

		# Handle incremental_step type "kill"
		elif step.step_type == QuestManager.INCREMENTAL_STEP and stepmeta.get("type", "") == "kill":
			check_and_emit_target_map(step)


# Get the current state of all quests to save.
func get_state() -> Dictionary:
	var state: Dictionary = {}
	state.player_quests = QuestManager.get_save_quest_data()
	state.tracked_quest = tracked_quest  # Save the tracked quest
	return state

# Set the quest state from a loaded dictionary.
func set_state(state: Dictionary) -> void:
	QuestManager.wipe_player_data()
	var player_quests = state.get("player_quests", {})
	QuestManager.load_saved_quest_data(player_quests)

	# Restore the tracked quest
	tracked_quest = state.get("tracked_quest", "")


# Helper function to check if the step has the "enter" type within "action_step" and emit the target_map_changed signal
func check_and_emit_target_map(step: Dictionary):
	var step_type = step.get("step_type", "")

	if step_type == QuestManager.INCREMENTAL_STEP and not step.get("complete", false):  # Handle "kill" step
	#if step_type == "kill":  # Handle "kill" steps with map guidance
		var stepmeta: Dictionary = step.get("meta_data", {}).get("stepjson", {})
		if stepmeta.get("type", "") == "kill":
			if stepmeta.has("map_guide") and stepmeta["map_guide"] != "none":
				_emit_target_map_for_kill_step(stepmeta)

	elif step_type == "action_step" and not step.complete:
		var stepmeta: Dictionary = step.get("meta_data", {}).get("stepjson", {})
		if stepmeta.get("type", "") == "enter": # We set a target for the player to enter
			var map_id: String = stepmeta.get("map_id", "")
			target_map_changed.emit([map_id], stepmeta)  # Emit for "enter" steps
		elif stepmeta.get("type", "") == "spawn_mob": # We set a target for the player to approach
			# If the coordinate is not yet set, pick a target coordinate based on the map_id
			if not stepmeta.has("coordinate"):
				var map_id: String = stepmeta.get("map_id", "")
				var closest_cell = Helper.overmap_manager.find_closest_map_cell_with_ids(
					[map_id], {"reveal_condition": "REVEALED"}
				)

				if closest_cell:
					var coordinate = Vector2(closest_cell.coordinate_x, closest_cell.coordinate_y)
					stepmeta["coordinate"] = coordinate
					# Persist the updated stepmeta back into the step's meta_data
					step["meta_data"]["stepjson"] = stepmeta

			# Emit the map target for visualization purposes (arrow on overmap)
			if stepmeta.has("coordinate"):
				target_map_changed.emit([stepmeta["map_id"]], {"reveal_condition": "REVEALED"})
			else:
				target_map_changed.emit([])  # Fallback if no cell was found
		else:
			target_map_changed.emit([])  # No target if type is not "enter" or "spawn_mob"
	else:
		target_map_changed.emit([])  # No target if type is not "action_step"


# Function to handle tracking a quest when the "track quest" button is clicked
func _on_quest_window_track_quest_clicked(quest_name: String) -> void:
	tracked_quest = quest_name


# Emits the target map signal for "kill" steps
func _emit_target_map_for_kill_step(stepmeta: Dictionary):
	# Get the map guide type
	var map_guide: String = stepmeta.get("map_guide", "none")
	if map_guide == "none":
		return

	# Determine if we're working with a mob or mobgroup
	var maps_list: Array = []
	if stepmeta.has("mob"):
		maps_list = get_maps_from_entity(Runtimedata.mobs, stepmeta["mob"])
	elif stepmeta.has("mobgroup"):
		maps_list = get_maps_from_entity(Runtimedata.mobgroups, stepmeta["mobgroup"])

	# Ensure the maps list is not empty
	if maps_list.is_empty():
		print_debug("No maps associated with the specified mob or mobgroup.")
		return

	# Emit the target map signal with the gathered maps and properties
	var target_properties: Dictionary = {
		"reveal_condition": map_guide,
		"exact_match": true,
		"dynamic": true
	}
	target_map_changed.emit(maps_list, target_properties)

func get_maps_from_entity(data_source: RefCounted, entity_id: String) -> Array:
	if entity_id == "":
		print_debug("Invalid entity ID.")
		return []

	var entity = data_source.by_id(entity_id)
	if entity == null:
		print_debug("No data found for entity ID: " + entity_id)
		return []

	return entity.get_maps()

# Function to handle item equipped in an equipment slot
func _on_item_was_equipped(heldItem: InventoryItem, _equipmentSlot: Control) -> void:
	if heldItem:
		# Add the item to the equipped_items array if not already there
		if heldItem not in equipped_items:
			equipped_items.append(heldItem)
		
		# Update the quest progression based on the equipped item
		update_quest_by_inventory(heldItem)

# Function to handle item unequipped from an equipment slot
func _on_item_was_unequipped(heldItem: InventoryItem, _equipmentSlot: Control) -> void:
	if heldItem:
		# Remove the item from the equipped_items array
		equipped_items.erase(heldItem)
		
		# Reevaluate quests based on the updated inventory
		update_quest_by_inventory(null)


# Performs actions that are independent of player actions
# Updates the quest description if needed
# spawns item and moves onto the next step if needed.
func process_active_quests():
	var quests_in_progress: Dictionary = QuestManager.get_quests_in_progress()

	for quest in quests_in_progress.values():
		var step = QuestManager.get_current_step(quest.quest_name)
		if not step:
			continue  # Skip if there is no active step

		var stepmeta: Dictionary = step.get("meta_data", {}).get("stepjson", {})

		# Update quest description if needed
		if stepmeta.has("description"):
			quest["quest_details"] = stepmeta["description"]

		# Handle spawn_item step (ACTION_STEP)
		if step.step_type == QuestManager.ACTION_STEP and stepmeta.get("type", "") == "spawn_item" and not step.get("complete", false):
			var item_id: String = stepmeta.get("item", "")
			var amount: int = stepmeta.get("amount", 1)

			# Attempt to spawn the item
			if Helper.map_manager.spawn_item_at_current_player_map(item_id, amount):
				# Automatically complete the step upon successful item spawn
				QuestManager.progress_quest(quest.quest_name)
			else:
				print_debug("Failed to spawn item on map for quest step in quest: " + quest.quest_name)

# Retrieves the current step of the tracked quest and updates the target map.
func update_tracked_quest_target() -> void:
	if tracked_quest.is_empty():
		return  # No quest is being tracked, so nothing to update.

	var current_step = QuestManager.get_current_step(tracked_quest)  # Get the quest's current step
	if current_step:
		check_and_emit_target_map(current_step)  # Puts the quest marker on the overmap
