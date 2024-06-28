extends Control

# This script is supposed to work with QuestWindow.tscn.
# It helps the player to manage quests
# It has controls to select, assign and abandon quests
# It has controls to view the quest details
# It has tabs for current, completed and failed quests

# Main Quest Journal Window
@export var quest_overview_tabs: TabContainer
@export var current_quests_list: ItemList
@export var completed_quests_list: ItemList
@export var failed_quests_list: ItemList
@export var quest_details_section: VBoxContainer
@export var step_details_text_edit: TextEdit

var selected_quest: String # Will be the quest ID

func _ready():
	quest_overview_tabs.tab_changed.connect(_on_tab_changed)
	current_quests_list.item_selected.connect(_on_quest_selected.bind(current_quests_list))
	completed_quests_list.item_selected.connect(_on_quest_selected.bind(completed_quests_list))
	failed_quests_list.item_selected.connect(_on_quest_selected.bind(failed_quests_list))
	
	# Connect to the QuestManager signals
	QuestManager.quest_completed.connect(_on_quest_complete)
	QuestManager.quest_failed.connect(_on_quest_failed)
	QuestManager.step_complete.connect(_on_step_complete)
	QuestManager.next_step.connect(_on_next_step)
	QuestManager.step_updated.connect(_on_step_updated)
	QuestManager.new_quest_added.connect(_on_new_quest_added)
	QuestManager.quest_reset.connect(_on_quest_reset)
	
	initialize_quests()

# If any quests are already present, we add them to the quest journal
func initialize_quests():
	var currentquests: Array = QuestManager.get_all_player_quests_names()
	for quest in currentquests:
		_on_new_quest_added(quest)


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
	_update_quest_details(selected_quest)


# Function to handle new quest addition
# quest_name: Actually the quest id as defined in json
func _on_new_quest_added(quest_name: String):
	add_quest_to_list(quest_name, current_quests_list)


# Adds a quest to the provided list
# quest_id: The id of the quest as defined by json
# quest_list: An itemlist in the UI to which to add it
func add_quest_to_list(quest_id: String, quest_list: ItemList):
	var quest_icon: Texture = Gamedata.get_sprite_by_id(Gamedata.data.quests, quest_id)
	var quest_meta_data: Dictionary = QuestManager.get_meta_data(quest_id)
	var questname: String = quest_meta_data.get("name", "")
	if questname != "":
		var item_index: int = quest_list.add_item(questname, quest_icon)
		quest_list.set_item_metadata(item_index, quest_id) # Add the quest id as metadata


# Function to handle quest reset
func _on_quest_reset(_quest_name: String):
	# To be developed later
	pass


func _on_tab_changed(_tab):
	# Handle tab change logic
	pass


func _on_quest_selected(index, list: ItemList):
	# Update the quest details section based on selected quest
	selected_quest = list.get_item_metadata(index) # Will be the quest ID
	_update_quest_details(selected_quest)


# The quest details elements are updated after the user has selected a quest
func _update_quest_details(selected_quest: String):
	if not selected_quest:
		return
	var quest_meta_data: Dictionary = QuestManager.get_meta_data(selected_quest)
	var current_step: Dictionary = QuestManager.get_current_step(selected_quest)
	
	# Update quest title and description
	quest_details_section.get_node("QuestTitle").text = quest_meta_data.name
	quest_details_section.get_node("QuestDescription").text = quest_meta_data.description
	
	# Update current step details
	var step_details_text = "Step Details: \n"
	
	match current_step.step_type:
		"action_step":
			step_details_text += "Action: " + current_step.details
		"incremental_step":
			step_details_text += "Collect " + str(current_step.required) + " " + current_step.item_name + \
			" (Collected: " + str(current_step.collected) + ")"
		"items_step":
			step_details_text += "Items to collect/complete: \n"
			for item in current_step.item_list:
				step_details_text += "- " + item.name
				step_details_text += " (Complete)" if item.complete else " (Incomplete)"
				step_details_text += "\n"
		"timer_step":
			step_details_text += "Timer: " + str(current_step.time) + " seconds remaining"
		"branch_step":
			step_details_text += "Branch: " + current_step.details
	
	# Set step details in the QuestDescription node or another UI element if preferred
	step_details_text_edit.text = step_details_text
