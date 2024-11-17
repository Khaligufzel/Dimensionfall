extends Node

# This script is loaded into the helper.gd autoload singleton
# It can be accessed through Helper.quest_helper
# This is a helper script that manages quests in so far that the QuestManager can't

# When a quest updates and there either is or isn't a target location on the overmap
signal target_map_changed(map_id: String)


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


func connect_inventory_signals() -> void:
	if not Helper.signal_broker.playerInventory_item_added.is_connected(_on_inventory_item_added):
		Helper.signal_broker.playerInventory_item_added.connect(_on_inventory_item_added)
	if not Helper.signal_broker.playerInventory_item_removed.is_connected(_on_inventory_item_removed):
		Helper.signal_broker.playerInventory_item_removed.connect(_on_inventory_item_removed)
	if not Helper.signal_broker.playerInventory_item_modified.is_connected(_on_inventory_item_modified):
		Helper.signal_broker.playerInventory_item_modified.connect(_on_inventory_item_modified)


# Function for handling game started signal
func _on_game_started():
	connect_inventory_signals()
	initialize_quests()


# Function for handling game loaded signal
func _on_game_loaded():
	connect_inventory_signals()
	pass

# Function for handling game ended signal
func _on_game_ended():
	pass


# Function to handle quest completion
func _on_quest_complete(quest: Dictionary):
	target_map_changed.emit("")  # No more target when quest is complete
	var rewards: Array = quest.get("quest_rewards").get("rewards", [])
	for reward in rewards:
		var item_id: String = reward.get("item_id")
		var amount: int = reward.get("amount")
		ItemManager.add_item_by_id_and_amount(item_id, amount)


# Function to handle quest failure
func _on_quest_failed(_quest: Dictionary):
	target_map_changed.emit("")  # No more target when quest is complete

# When a step is complete.
# step: the step dictionary
func _on_step_complete(step: Dictionary):
	check_and_emit_target_map(step)


# Called after the previous step was completed
# step: the new step in the quest
func _on_next_step(step: Dictionary):
	check_and_emit_target_map(step)
	# The player might already have the item for the next step so check it
	match step.get("step_type", ""):	
		QuestManager.INCREMENTAL_STEP:
			update_quest_by_inventory(null)
		QuestManager.ITEMS_STEP:
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
	for quest: DQuest in Gamedata.quests.get_all().values():
		create_quest_from_data(quest)


# Takes a quest as defined by json (created in the contenteditor)
# Create an instance of a ScriptQuest and add it to the QuestManager
func create_quest_from_data(quest_data: DQuest):
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
func add_quest_step(quest: ScriptQuest, step: Dictionary) -> bool:
	match step.type:
		"collect":
			# Add an incremental step
			quest.add_incremental_step("Gather items", step.item, step.amount, {"stepjson": step})
			return true
		"kill":
			# Add an incremental step
			quest.add_incremental_step("Kill mob", step.mob, step.amount, {"stepjson": step})
			return true
		"craft":
			# Add an incremental step
			quest.add_action_step("Craft a " + Gamedata.items.by_id(step.item).name, {"stepjson": step})
			return true
		"enter":
			# Add an action step to inform the player to travel to the specified map
			var map_name: String = Gamedata.maps.by_id(step.map_id).name
			quest.add_action_step("Travel to " + map_name, {"stepjson": step})
			return true
	return false


# An item is added to the player inventory. Now we need to update the quests
func _on_inventory_item_added(item: InventoryItem, _inventory: InventoryStacked):
	update_quest_by_inventory(item)

# An item is removed to the player inventory. Now we need to update the quests
func _on_inventory_item_removed(item: InventoryItem, _inventory: InventoryStacked):
	update_quest_by_inventory(item)

# An item is modified to the player inventory. Now we need to update the quests
func _on_inventory_item_modified(item: InventoryItem, _inventory: InventoryStacked):
	update_quest_by_inventory(item)


# Update the quest progress based on the items in the player's inventory.
# For each quest, we ONLY update the step that the quest is currently at
func update_quest_by_inventory(item: InventoryItem):
	# Dictionary to keep track of the total count of each item
	var item_counts = ItemManager.count_player_inventory_items_by_id()

	# Check if the player has the item; if not, set its count to 0
	if item and not ItemManager.playerInventory.has_item_by_id(item.prototype_id):
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
	# Get the current quests in progress
	var quests_in_progress = QuestManager.get_quests_in_progress()
	# Update each of the current quests with the collected item information
	for quest in quests_in_progress.values():
		update_quest_step(quest.quest_name, mob_id, 1, true)


# The player has succesfully crafted an item.
func _on_craft_successful(item: DItem, _recipe: DItem.CraftRecipe):
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
func _on_map_entered(_player: CharacterBody3D, _old_pos: Vector2, new_pos: Vector2):
	# Get the current quests in progress
	var quests_in_progress = QuestManager.get_quests_in_progress()
	# Update each of the current quests with the entered map information
	for quest in quests_in_progress.values():
		var step = QuestManager.get_current_step(quest.quest_name)
		
		# Check for the step_type for this step according to the QuestManager
		if step.step_type == "action_step":
			var stepmeta: Dictionary = step.get("meta_data", {}).get("stepjson", {})
			# Check the type of the stepjson, which is set in the quest editor
			if stepmeta.get("type", "") == "enter":
				# Retrieve the map_cell based on the new player's position
				var map_cell = Helper.overmap_manager.get_map_cell_by_local_coordinate(new_pos)
				var map_id: String = stepmeta.get("map_id", "")
				if map_id == map_cell.map_id:
					# The player has entered the correct map for the quest step
					QuestManager.progress_quest(quest.quest_name)


# Get the current state of all quests to save.
func get_state() -> Dictionary:
	var state: Dictionary = {}
	state.player_quests = QuestManager.get_save_quest_data()
	return state


# Set the quest state from a loaded dictionary.
func set_state(state: Dictionary) -> void:
	QuestManager.wipe_player_data()
	var player_quests = state.get("player_quests", {})
	QuestManager.load_saved_quest_data(player_quests)


# Helper function to check if the step has the "enter" type within "action_step" and emit the target_map_changed signal
func check_and_emit_target_map(step: Dictionary):
	var step_type = step.get("step_type", "")

	# Check for the step_type for this step according to the QuestManager
	if step_type == "action_step" and not step.complete:
		var stepmeta: Dictionary = step.get("meta_data", {}).get("stepjson", {})
		# Check the type of the stepjson, which is set in the quest editor
		if stepmeta.get("type", "") == "enter":
			var map_id: String = stepmeta.get("map_id", "")
			target_map_changed.emit(map_id)  # Emit the map_id if the stepmeta.type is "enter"
		else:
			target_map_changed.emit("")  # No target if the type is not "enter"
	else:
		target_map_changed.emit("")  # No target if step_type is not "action_step"

# Function to handle tracking a quest when the "track quest" button is clicked
func _on_quest_window_track_quest_clicked(quest_name: String) -> void:
	if quest_name == "":
		print("No quest selected to track.")
		return

	# Get the quest's current step
	var current_step = QuestManager.get_current_step(quest_name)
	if current_step == null:
		print("Quest has no active steps or is null.")
		return

	# Check if the current step is completed
	if current_step.get("complete", false):
		print("The current step of the quest is already complete.")
		return

	# Call check_and_emit_target_map to manage the map targeting for the quest
	check_and_emit_target_map(current_step)
