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
func _on_inventory_item_added(_item: InventoryItem):
	update_quest_by_inventory()

# An item is removed to the player inventory. Now we need to update the quests
func _on_inventory_item_removed(item: InventoryItem):
	update_quest_by_inventory()


# Loop over ItemManager.playerInventory.get_items()
# Get the stacksize of each item from InventoryStacked.get_item_stack_size(item)
# For each unique item, sum the stack sizes to get the accurate count
# Get the quest names from QuestManager.get_quests_in_progress() -> Dictionary
# Update each of the current quests with QuestManager.set_quest_step_items which is defined as:
#func set_quest_step_items(quest_name:String,quest_item:String,amount:int=0,collected:bool=false) -> void:
#Set a specific value for Incremental and Item Steps. For example the player could have some of an item already use this to match the players inventory
# An item is added to the player inventory. Now we need to update the quests
func update_quest_by_inventory():
	# Dictionary to keep track of the total count of each item
	var item_counts = {}

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
		for item_id in item_counts.keys():
			# Update the quest step items with the collected count
			QuestManager.set_quest_step_items(myquest.quest_name, item_id, item_counts[item_id], true)
	
