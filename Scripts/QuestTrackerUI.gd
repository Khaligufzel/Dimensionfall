extends VBoxContainer

@onready var quest_name_label: Label = $QuestNameLabel
@onready var quest_target_label: Label = $QuestTargetLabel


func _ready() -> void:
	Helper.signal_broker.track_quest_clicked.connect(_on_quest_window_track_quest_clicked)

# Function to update quest UI based on the current quest and step
# quest_name: it's actually the id of the quest as known by Gamedata.quests
func update_quest_ui(quest_name: String):
	# Update the quest name label
	var dquest: DQuest = Gamedata.quests.by_id(quest_name)
	quest_name_label.text = dquest.name
	
	# Get the current step
	var current_step = QuestManager.get_current_step(quest_name)
	if current_step == null or current_step.is_empty():
		hide_ui_elements()
		return
	
	# Retrieve step requirement details
	var step_type = current_step.get("step_type", "Unknown")
	var step_requirement = ""
	
	match step_type:
		QuestManager.INCREMENTAL_STEP:
			var item = current_step.get("item_name", "Unknown")
			var target_amount = current_step.get("target_amount", 0)
			var current_amount = current_step.get("current_amount", 0)
			step_requirement = "Collect " + str(current_amount) + "/" + str(target_amount) + " " + item
		QuestManager.ITEMS_STEP:
			var items_required = current_step.get("required_items", {})
			step_requirement = "Items needed: " + str(items_required)
		QuestManager.ACTION_STEP:
			step_requirement = " " + current_step.details
		_:
			step_requirement = "Objective unknown."
	
	# Update the quest step label
	quest_target_label.text = step_requirement

# Example call to update the UI with a specific quest
# This can be triggered by a signal or manual call when the active quest changes
func set_active_quest(quest_name: String):
	update_quest_ui(quest_name)


func _on_quest_window_track_quest_clicked(quest: String) -> void:
	if quest:  # Ensure a valid quest ID is provided
		update_quest_ui(quest)  # Update the UI with the quest details
	else:
		print("No quest selected to track.")  # Debug message if no quest ID is provided


# Connect QuestManager signals
func connect_quest_signals():
	QuestManager.quest_completed.connect(_on_quest_complete)
	QuestManager.quest_failed.connect(_on_quest_failed)
	QuestManager.step_complete.connect(_on_step_complete)
	QuestManager.next_step.connect(_on_next_step)
	QuestManager.step_updated.connect(_on_step_updated)

# Function to handle quest completion
func _on_quest_complete(quest: Dictionary):
	var quest_id = quest.quest_name
	if quest_id == quest_name_label.text:  # Check if it matches the tracked quest
		hide_ui_elements()  # Hide the UI if the quest is completed
	else:
		print("Quest completed but not currently tracked:", quest_id)

# Function to handle quest failure
func _on_quest_failed(quest: Dictionary):
	var quest_id = quest.quest_name
	if quest_id == quest_name_label.text:  # Check if it matches the tracked quest
		hide_ui_elements()  # Hide the UI if the quest has failed
	else:
		print("Quest failed but not currently tracked:", quest_id)

# Function to handle step completion
func _on_step_complete(step: Dictionary):
	var quest_id = step.get("quest_name", "")
	if quest_id == quest_name_label.text:  # Check if it matches the tracked quest
		update_quest_ui(quest_id)  # Update the UI for the tracked quest

# Function to handle moving to the next step
func _on_next_step(step: Dictionary):
	var quest_id = step.get("quest_name", "")
	if quest_id == quest_name_label.text:  # Check if it matches the tracked quest
		update_quest_ui(quest_id)  # Update the UI for the tracked quest

# Function to handle step update
func _on_step_updated(step: Dictionary):
	var quest_id = step.get("quest_name", "")
	if quest_id == quest_name_label.text:  # Check if it matches the tracked quest
		update_quest_ui(quest_id)  # Update the UI for the tracked quest

# Helper function to hide the UI elements
func hide_ui_elements():
	quest_name_label.text = ""
	quest_target_label.text = ""
	print("UI elements hidden for the current tracked quest.")
