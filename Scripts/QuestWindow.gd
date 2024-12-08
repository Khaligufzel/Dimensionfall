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
@export var quest_rewards: VBoxContainer
@export var step_details_text_edit: TextEdit


var selected_quest: String # Will be the quest ID

func _ready():
	# Connect tab and quest list item selection signals
	connect_ui_signals()
	# Connect QuestManager signals
	connect_quest_signals()
	# Initialize quests if any are already present
	initialize_quests()


# Connect UI signals
func connect_ui_signals():
	quest_overview_tabs.tab_changed.connect(_on_tab_changed)
	current_quests_list.item_selected.connect(_on_quest_selected.bind(current_quests_list))
	completed_quests_list.item_selected.connect(_on_quest_selected.bind(completed_quests_list))
	failed_quests_list.item_selected.connect(_on_quest_selected.bind(failed_quests_list))


# Connect QuestManager signals
func connect_quest_signals():
	QuestManager.quest_completed.connect(_on_quest_complete)
	QuestManager.quest_failed.connect(_on_quest_failed)
	QuestManager.step_complete.connect(_on_step_complete)
	QuestManager.next_step.connect(_on_next_step)
	QuestManager.step_updated.connect(_on_step_updated)
	QuestManager.new_quest_added.connect(_on_new_quest_added)
	QuestManager.quest_reset.connect(_on_quest_reset)


# If any quests are already present, we add them to the quest journal
func initialize_quests():
	var currentquests: Array = QuestManager.get_all_player_quests_names()
	for quest in currentquests:
		var quest_data = QuestManager.get_player_quest(quest)
		
		# Check if the quest is completed or failed and add to respective lists
		if quest_data.completed:
			_on_quest_complete(quest_data)
		elif quest_data.failed:
			_on_quest_failed(quest_data)
		else:
			_on_new_quest_added(quest)
	
	# Select the first quest in the current quests list if any quests exist
	if current_quests_list.get_item_count() > 0:
		current_quests_list.select(0)
		_on_quest_selected(0, current_quests_list) # Automatically trigger selection


# Function to handle quest completion
func _on_quest_complete(quest: Dictionary):
	var quest_id = quest.quest_name
	
	# Move the quest to the completed quests list
	remove_quest_from_list(quest_id, current_quests_list)
	add_quest_to_list(quest_id, completed_quests_list)
	
	_update_quest_details()


func remove_quest_from_list(quest_id: String, list: ItemList):
	# Find and remove the quest from the current quests list
	for i in range(list.get_item_count()):
		if list.get_item_metadata(i) == quest_id:
			list.remove_item(i)
			break


# Function to handle quest failure
func _on_quest_failed(quest: Dictionary):
	var quest_id = quest.quest_name
	
	# Move the quest to the completed quests list
	remove_quest_from_list(quest_id, current_quests_list)
	add_quest_to_list(quest_id, failed_quests_list)
	
	_update_quest_details()


# Function to handle step completion
func _on_step_complete(_step: Dictionary):
	_update_quest_details()


# Function to handle next step
func _on_next_step(_step: Dictionary):
	_update_quest_details()


# Function to handle step update
func _on_step_updated(_step: Dictionary):
	_update_quest_details()


# Function to handle new quest addition
# quest_name: Actually the quest id as defined in json
func _on_new_quest_added(quest_name: String):
	add_quest_to_list(quest_name, current_quests_list)


# Adds a quest to the provided list
# quest_id: The id of the quest as defined by json
# quest_list: An itemlist in the UI to which to add it
func add_quest_to_list(quest_id: String, quest_list: ItemList):
	var rquest: RQuest = Runtimedata.quests.by_id(quest_id)
	var quest_icon: Texture = rquest.sprite
	var questname: String = rquest.name
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
	_update_quest_details()


# The quest details elements are updated after the user has selected a quest
func _update_quest_details():
	if not selected_quest:
		return
	
	var quest: Dictionary = QuestManager.get_player_quest(selected_quest)
	var rquest: RQuest = Runtimedata.quests.by_id(quest.quest_name)
	
	# Update quest title and description
	quest_details_section.get_node("QuestTitle").text = rquest.name
	quest_details_section.get_node("QuestDescription").text = rquest.description
	
	# Update rewards details
	update_rewards_details(quest)
	
	if QuestManager.is_quest_complete(selected_quest):
		step_details_text_edit.text = "Quest completed!"
	else:
		update_step_details(QuestManager.get_current_step(selected_quest))


func update_step_details(current_step: Dictionary):
	if not current_step or current_step.is_empty():
		step_details_text_edit.text = ""
		return

	var step_details_text = "Next objective: \n" + get_step_details(current_step)
	var stepmeta: Dictionary = current_step.get("meta_data", {}).get("stepjson", {})
	if stepmeta.has("tip"):
		step_details_text += "\nTip: " + stepmeta.tip
	step_details_text_edit.text = step_details_text


func get_step_details(current_step: Dictionary) -> String:
	match current_step.step_type:
		QuestManager.ACTION_STEP:
			return "Action: " + current_step.details
		QuestManager.INCREMENTAL_STEP:
			return create_incremental_step_UI_text(current_step)
		QuestManager.ITEMS_STEP:
			return create_items_step_UI_text(current_step)
		QuestManager.TIMER_STEP:
			return "Timer: " + str(current_step.time) + " seconds remaining"
		QuestManager.BRANCH_STEP:
			return "Branch: " + current_step.details
		_:
			return "Unknown step type."


# Modular handling of item step details
func create_items_step_UI_text(step: Dictionary) -> String:
	var text = "Items to collect/complete: \n"
	for item in step.item_list:
		text += "- " + item.name
		text += " (Complete)" if item.complete else " (Incomplete)"
		text += "\n"
	return text


# Updates the rewards details for the selected quest
func update_rewards_details(quest: Dictionary):
	for child in quest_rewards.get_children():
		child.queue_free() # Clear existing children
	
	var rewards = quest.get("quest_rewards").get("rewards", [])
	if rewards.size() > 0:
		for reward in rewards:
			# Extract the item name from the item data
			var item_name = Gamedata.items.by_id(reward.item_id).name
			var amount = reward.amount

			# Create a container for the reward item
			var reward_container = HBoxContainer.new()
			quest_rewards.add_child(reward_container)

			# Add item icon to the container
			var item_icon_texture: Texture = Gamedata.items.sprite_by_id(reward.item_id)
			if item_icon_texture:
				var icon = TextureRect.new()
				icon.texture = item_icon_texture
				icon.custom_minimum_size = Vector2(32, 32)  # Set a fixed size for icons
				reward_container.add_child(icon)

			# Add item label to the container
			var label = Label.new()
			label.text = " %s: %d" % [item_name, amount]
			reward_container.add_child(label)
	else:
		# Show a label indicating no rewards available
		var no_rewards_label = Label.new()
		no_rewards_label.text = "No rewards available."
		quest_rewards.add_child(no_rewards_label)


# Main function to update the UI text based on the properties of the step
func create_incremental_step_UI_text(step: Dictionary) -> String:
	var step_details_text = ""
	
	# Get the step type from the metadata, defaulting to "missing type" if not found
	var step_meta = step.meta_data.get("stepjson", {})
	
	# Call the appropriate function based on the step type
	match step_meta.type:
		"collect":
			step_details_text = _handle_collect_step(step)
		"kill":
			step_details_text = _handle_kill_step(step)
		_:
			step_details_text = _handle_unsupported_step(step_meta.type)
	
	# Return the constructed step details text
	return step_details_text


# Function to handle the "collect" step type
func _handle_collect_step(step: Dictionary) -> String:
	var step_details_text = ""
	# Extract the item name from the item data.
	var item_name = Gamedata.items.by_id(step.item_name).name
	# Construct the step details text with the required and collected item counts
	step_details_text += "Collect " + str(step.required) + " "
	step_details_text += item_name + " (Collected: " 
	step_details_text += str(step.collected) + ")"
	return step_details_text


# Function to handle the "kill" step type
func _handle_kill_step(step: Dictionary) -> String:
	var step_details_text = ""
	var step_meta = step.meta_data.get("stepjson", {})
	
	if step_meta.has("mob"):
		# Handle single mob case
		var rmob: RMob = Runtimedata.mobs.by_id(step_meta["mob"])
		step_details_text += "Kill " + str(step.required) + " "
		step_details_text += rmob.name + " (Killed: "
	elif step_meta.has("mobgroup"):
		# Handle mob group case
		var dmobgroup: DMobgroup = Gamedata.mobgroups.by_id(step_meta["mobgroup"])
		step_details_text += "Kill " + str(step.required) + " "
		step_details_text += dmobgroup.name + " (Killed: "
	else:
		# Handle missing data
		step_details_text += "Kill target not specified (Killed: "

	# Append the collected count and close the text
	step_details_text += str(step.collected) + ")"
	return step_details_text


# Function to handle unsupported step types
func _handle_unsupported_step(step_type: String) -> String:
	return "Unsupported step type: " + step_type


# The player abandons the quest, so we move it to the failed list
func _on_abandon_quest_button_button_up():
	_on_quest_failed(QuestManager.get_player_quest(selected_quest))


func _on_track_quest_button_button_up() -> void:
	if selected_quest:  # Ensure a quest is selected
		Helper.signal_broker.track_quest_clicked.emit(selected_quest)  # Emit the signal with the selected quest ID
	else:
		print("No quest selected to track.")  # Debug message if no quest is selected
