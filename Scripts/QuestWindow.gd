extends Control

# This script is supposed to work with QuestWindow.tscn.
# It helps the player to manage quests
# It has controls to select, assign and abandon quests
# It has controls to view the quest details
# It has tabs for current, completed and failed quests


# Main Quest Journal Window
@export var quest_overview_tabs: TabContainer
@export var available_quests_list: ItemList
@export var current_quests_list: ItemList
@export var completed_quests_list: ItemList
@export var failed_quests_list: ItemList
@export var quest_details_section: VBoxContainer

func _ready():
	quest_overview_tabs.tab_changed.connect(_on_tab_changed)
	current_quests_list.item_selected.connect(_on_quest_selected)
	completed_quests_list.item_selected.connect(_on_quest_selected)
	failed_quests_list.item_selected.connect(_on_quest_selected)
	
	# Connect to the QuestManager signals
	QuestManager.quest_complete.connect(_on_quest_complete)
	QuestManager.quest_failed.connect(_on_quest_failed)
	QuestManager.step_complete.connect(_on_step_complete)
	QuestManager.next_step.connect(_on_next_step)
	QuestManager.step_updated.connect(_on_step_updated)
	QuestManager.new_quest_added.connect(_on_new_quest_added)
	QuestManager.quest_reset.connect(_on_quest_reset)


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


func _on_tab_changed(_tab):
	# Handle tab change logic
	pass


func _on_quest_selected(index):
	# Update the quest details section based on selected quest
	var selected_quest = current_quests_list.get_item_text(index) # Example for current quests
	_update_quest_details(selected_quest)


func _update_quest_details(quest_title):
	quest_details_section.get_node("QuestTitle").text = quest_title
	quest_details_section.get_node("QuestDescription").text = "Detailed description for " + quest_title
	# Update other details like status and rewards
