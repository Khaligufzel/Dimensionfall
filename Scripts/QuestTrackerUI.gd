extends VBoxContainer

@onready var quest_name_label: Label = $QuestNameLabel
@onready var quest_target_label: Label = $QuestTargetLabel
# Variable to track the currently selected quest ID
var tracked_quest_id: String = ""


func _ready() -> void:
	connect_quest_signals()

# Function to update quest UI based on the current quest and step
# quest_name: it's actually the id of the quest as known by Runtimedata.quests
func update_quest_ui(quest_name: String):
	# Update the quest name label
	var rquest: RQuest = Runtimedata.quests.by_id(quest_name)
	quest_name_label.text = rquest.name

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
			var stepmeta: Dictionary = current_step.get("meta_data", {}).get("stepjson", {})
			var target_amount = current_step.get("required", 0)
			var current_amount = current_step.get("collected", 0)

			if stepmeta.get("type", "") == "collect":
				var item_id = stepmeta.get("item", "")
				var item_name = Gamedata.items.by_id(item_id).name if item_id != "" else "Unknown Item"
				step_requirement = "Collect " + str(current_amount) + "/" + str(target_amount) + " " + item_name
			elif stepmeta.get("type", "") == "kill":
				if stepmeta.has("mob"):
					var mob_id = stepmeta["mob"]
					var mob_name = Runtimedata.mobs.by_id(mob_id).name if mob_id != "" else "Unknown Mob"
					step_requirement = "Kill " + str(current_amount) + "/" + str(target_amount) + " " + mob_name
				elif stepmeta.has("mobgroup"):
					var mobgroup_id = stepmeta["mobgroup"]
					var mobgroup_name = Gamedata.mobgroups.by_id(mobgroup_id).name if mobgroup_id != "" else "Unknown Mob Group"
					step_requirement = "Kill " + str(current_amount) + "/" + str(target_amount) + " from " + mobgroup_name
				else:
					step_requirement = "Kill target not specified."
			else:
				step_requirement = "Progress: " + str(current_amount) + "/" + str(target_amount)

		QuestManager.ITEMS_STEP:
			var items_required = current_step.get("required_items", {})
			step_requirement = "Items needed: " + str(items_required)
		QuestManager.ACTION_STEP:
			step_requirement = current_step.details
		_:
			step_requirement = "Objective unknown."

	# Update the quest step label
	quest_target_label.text = step_requirement



# Example call to update the UI with a specific quest
# This can be triggered by a signal or manual call when the active quest changes
func set_active_quest(quest_name: String):
	update_quest_ui(quest_name)


func _on_quest_window_track_quest_clicked(quest: String) -> void:
	if quest:
		tracked_quest_id = quest  # Update the tracked quest ID
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
	Helper.signal_broker.track_quest_clicked.connect(_on_quest_window_track_quest_clicked)


# Function to handle quest completion
func _on_quest_complete(_quest: Dictionary):
	if tracked_quest_id != "" and Runtimedata.quests.by_id(tracked_quest_id).name == quest_name_label.text:  # Check if it matches the tracked quest
		hide_ui_elements()  # Hide the UI if the quest has failed
	else:
		print("Quest failed but not currently tracked:", tracked_quest_id)


# Function to handle quest failure
func _on_quest_failed(_quest: Dictionary):
	if tracked_quest_id != "" and Runtimedata.quests.by_id(tracked_quest_id).name == quest_name_label.text:  # Check if it matches the tracked quest
		hide_ui_elements()  # Hide the UI if the quest has failed
	else:
		print("Quest failed but not currently tracked:", tracked_quest_id)


# Function to handle step completion
func _on_step_complete(_step: Dictionary):
	if tracked_quest_id != "" and Runtimedata.quests.by_id(tracked_quest_id).name == quest_name_label.text:  # Check if it matches the tracked quest
		update_quest_ui(tracked_quest_id)  # Update the UI for the tracked quest


# Function to handle moving to the next step
func _on_next_step(_step: Dictionary):
	if tracked_quest_id != "" and Runtimedata.quests.by_id(tracked_quest_id).name == quest_name_label.text:  # Check if it matches the tracked quest
		update_quest_ui(tracked_quest_id)  # Update the UI for the tracked quest


# Function to handle step update
func _on_step_updated(_step: Dictionary):
	if tracked_quest_id != "" and Runtimedata.quests.by_id(tracked_quest_id).name == quest_name_label.text:  # Check if it matches the tracked quest
		update_quest_ui(tracked_quest_id)  # Update the UI for the tracked quest


# Helper function to hide the UI elements
func hide_ui_elements():
	quest_name_label.text = ""
	quest_target_label.text = ""
	print("UI elements hidden for the current tracked quest.")
