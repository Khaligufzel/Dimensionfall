extends Node

# This script is loaded into the helper.gd autoload singleton
# It can be accessed through Helper.quest_helper
# This is a helper script that manages quests in so far that the QuestManager can't

func _ready():
	# Connect to the Helper.signal_broker.game_started signal
	Helper.signal_broker.game_started.connect(_on_game_started)
	
	# Connect to the Helper.signal_broker.game_loaded signal
	Helper.signal_broker.game_loaded.connect(_on_game_loaded)

# Function for handling game started signal
func _on_game_started():
	initialize_quests()
	pass

# Function for handling game loaded signal
func _on_game_loaded():
	# To be developed later
	pass


func initialize_quests():
	var quest_data = Gamedata.data.quests.data
	for quest in quest_data:
		create_quest_from_data(quest)


func create_quest_from_data(quest_data):
	if quest_data.steps.len < 1:
		return # The quest has no steps
	var Quest = ScriptQuest.new(quest_data.name,quest_data.description)
	var steps_added: bool = false
	var steps = quest_data.steps
	for step in steps:
		if step.type == "collect":
			#add an incremental step
			Quest.add_incremental_step("Gather items", step.item, step.amount)
			steps_added = true
	
	if steps_added:
		#finalize
		Quest.finalize_quest()
		#Add quest to player quests
		QuestManager.add_scripted_quest(Quest)
