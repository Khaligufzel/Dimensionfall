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
	QuestManager.quest_complete.connect(_on_quest_complete)
	QuestManager.quest_failed.connect(_on_quest_failed)
	QuestManager.step_complete.connect(_on_step_complete)
	QuestManager.next_step.connect(_on_next_step)
	QuestManager.step_updated.connect(_on_step_updated)
	QuestManager.new_quest_added.connect(_on_new_quest_added)
	QuestManager.quest_reset.connect(_on_quest_reset)

# Function for handling game started signal
func _on_game_started():
	initialize_quests()
	pass

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
	QuestManager.wipe_all_quest_data()
	var quest_data = Gamedata.data.quests.data
	for quest in quest_data:
		create_quest_from_data(quest)


func create_quest_from_data(quest_data: Dictionary):
	if quest_data.steps.len < 1:
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
