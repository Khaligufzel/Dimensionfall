extends Node

# This script is loaded into the helper.gd autoload singleton
# It can be accessed through Helper.quest_helper
# This is a helper script that manages quests in so far that the QuestManager can't

func _ready():
	# Connect to the Helper.signal_broker.game_started signal
	Helper.signal_broker.game_started.connect(_on_game_started)
	
	# Connect to the Helper.signal_broker.game_loaded signal
	Helper.signal_broker.game_loaded.connect(_on_game_loaded)
	
	# Connect to the QuestManager signals
	QuestManager.quest_completed.connect(_on_quest_complete)
	QuestManager.quest_failed.connect(_on_quest_failed)
	QuestManager.step_complete.connect(_on_step_complete)
	QuestManager.next_step.connect(_on_next_step)
	QuestManager.step_updated.connect(_on_step_updated)
	QuestManager.new_quest_added.connect(_on_new_quest_added)
	QuestManager.quest_reset.connect(_on_quest_reset)


func connect_inventory_signals() -> void:
	ItemManager.playerInventory.item_added.connect(_on_inventory_item_added)
	ItemManager.playerInventory.item_removed.connect(_on_inventory_item_removed)
	ItemManager.playerInventory.item_modified.connect(_on_inventory_item_modified)


# Function for handling game started signal
func _on_game_started():
	connect_inventory_signals()
	initialize_quests()


# Function for handling game loaded signal
func _on_game_loaded():
	# To be developed later
	pass


# Function to handle quest completion
func _on_quest_complete(_quest: Dictionary):
	# To be developed later
	pass


# Function to handle quest failure
func _on_quest_failed(_quest: Dictionary):
	# To be developed later
	pass


# Function to handle step completion
func _on_step_complete(_step: Dictionary):
	# To be developed later
	pass


# Function to handle next step
func _on_next_step(_step: Dictionary):
	# To be developed later
	pass


# Function to handle step update
func _on_step_updated(_step: Dictionary):
	# To be developed later
	pass

# Function to handle new quest addition
func _on_new_quest_added(_quest_name: String):
	# To be developed later
	pass


# Function to handle quest reset
func _on_quest_reset(_quest_name: String):
	# To be developed later
	pass


func initialize_quests():
	QuestManager.wipe_player_data()
	var quest_data = Gamedata.data.quests.data
	for quest in quest_data:
		create_quest_from_data(quest)


func create_quest_from_data(quest_data: Dictionary):
	if quest_data.steps.size() < 1:
		return # The quest has no steps
	var Quest = ScriptQuest.new(quest_data.id, quest_data.description)
	var steps_added: bool = false
	var steps = quest_data.steps
	for step in steps:
		if step.type == "collect":
			# Add an incremental step
			Quest.add_incremental_step("Gather items", step.item, step.amount)
			steps_added = true

	if steps_added:
		Quest.set_quest_meta_data(quest_data) # The json data that defines the quest
		# Finalize
		Quest.finalize_quest()
		# Add quest to player quests
		QuestManager.add_scripted_quest(Quest)


# An item is added to the player inventory. Now we need to update the quests
func _on_inventory_item_added(item: InventoryItem):
	update_quest_by_inventory(item)

# An item is removed to the player inventory. Now we need to update the quests
func _on_inventory_item_removed(item: InventoryItem):
	update_quest_by_inventory(item)

# An item is modified to the player inventory. Now we need to update the quests
func _on_inventory_item_modified(item: InventoryItem):
	update_quest_by_inventory(item)


# Update the quest progress based on the items in the player's inventory.
# For each quest, we ONLY update the step that the quest is currently at
func update_quest_by_inventory(item: InventoryItem):
	# Dictionary to keep track of the total count of each item
	var item_counts = {}

	# Check if the player has the item; if not, set its count to 0
	if not ItemManager.playerInventory.has_item_by_id(item.prototype_id):
		item_counts[item.prototype_id] = 0

	# Loop over all items in the player's inventory
	for inv_item in ItemManager.playerInventory.get_items():
		var item_id = inv_item.prototype_id
		var stack_size = InventoryStacked.get_item_stack_size(inv_item)

		# Sum the stack sizes for each unique item
		if item_id in item_counts:
			item_counts[item_id] += stack_size
		else:
			item_counts[item_id] = stack_size

	# Get the current quests in progress
	var quests_in_progress = QuestManager.get_quests_in_progress()

	# Update each of the current quests with the collected item information
	for quest in quests_in_progress.keys():
		var myquest = quests_in_progress[quest]
		var myquestname = myquest.quest_name
		for item_id in item_counts.keys():
			var step = QuestManager.get_current_step(myquestname)
			match step.step_type:
				QuestManager.INCREMENTAL_STEP:
					if step.item_name == item_id:
						# Update the quest step items with the collected count
						# Since progress_quest adds the amount, we have to set it to 0 first
						QuestManager.set_quest_step_items(myquestname, item_id, 0)
						# see https://github.com/Chevifier/QuestManager/issues/20
						step["complete"] = false 
						QuestManager.progress_quest(myquestname, item_id, item_counts[item_id])
				QuestManager.ITEMS_STEP:
					# Update the quest step items with the collected count
					QuestManager.set_quest_step_items(myquestname, item_id, 0, true)
					QuestManager.progress_quest(myquestname, item_id)
