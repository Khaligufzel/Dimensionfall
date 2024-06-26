extends Control

# Main Quest Journal Window
@export var quest_overview_tabs: TabContainer
@export var current_quests_list: ItemList
@export var completed_quests_list: ItemList
@export var failed_quests_list: ItemList
@export var quest_details_section: VBoxContainer

func _ready():
	quest_overview_tabs.tab_changed.connect(_on_tab_changed)
	current_quests_list.item_selected.connect(_on_quest_selected)
	completed_quests_list.item_selected.connect(_on_quest_selected)
	failed_quests_list.item_selected.connect(_on_quest_selected)

func _on_tab_changed(tab):
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
