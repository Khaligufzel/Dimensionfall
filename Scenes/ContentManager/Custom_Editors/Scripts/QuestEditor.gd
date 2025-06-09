extends Control

# This scene is intended to be used inside the content editor
# It is supposed to edit exactly one quest
# It expects to save the data to a JSON file
# To load data, provide the name of the quest data file and an ID

@export var questImageDisplay: TextureRect = null
@export var IDTextLabel: Label = null
@export var PathTextLabel: Label = null
@export var NameTextEdit: TextEdit = null
@export var DescriptionTextEdit: TextEdit = null
@export var questSelector: Popup = null
@export var step_type_option_button: OptionButton
@export var steps_container: VBoxContainer
@export var rewards_item_list: GridContainer
@export var dropabletextedit: PackedScene = null

# Step properties popup controls:
@export var step_properties_popup_panel: PopupPanel = null
@export var hint_text_edit: TextEdit = null
@export var description_text_edit: TextEdit = null
@export var ok_button: Button = null
@export var cancel_button: Button = null


# This signal will be emitted when the user presses the save button
# This signal should alert Gamedata that the quest data array should be saved to disk
signal data_changed()

var olddata: DQuest  # Remember what the value of the data was before editing
var selected_step: HBoxContainer = null  # Store the selected step when opening the popup
var step_factories: Dictionary = {}  # Maps step types to factory functions


# The data that represents this quest
# The data is selected from dquest.parent.quests
# based on the ID that the user has selected in the content editor
var dquest: DQuest = null:
	set(value):
		dquest = value
		load_quest_data()
		questSelector.sprites_collection = dquest.parent.sprites
		olddata = DQuest.new(dquest.get_data().duplicate(true), null)

func _ready():
	ok_button.pressed.connect(_on_ok_button_pressed)
	cancel_button.pressed.connect(_on_cancel_button_pressed)

	# Set custom can_drop_func and drop_func for the rewardscontainer, use default drag_func
	rewards_item_list.set_drag_forwarding(Callable(), _can_drop_reward, _drop_reward_data)

	# Initialize dictionary that maps step types to UI factory functions
	step_factories = {
		"craft": add_craft_step,
		"collect": add_collect_step,
		"call": add_call_step,
		"enter": add_enter_step,
		"kill": add_kill_step,
		"spawn_item": add_spawn_item_step,
		"spawn_mob": add_spawn_mob_step,
	}

# The editor is closed, destroy the instance
# TODO: Check for unsaved changes
func _on_close_button_button_up() -> void:
	queue_free()

# This function updates the form based on the DQuest that has been loaded
func load_quest_data() -> void:
	if questImageDisplay != null and dquest.spriteid != "":
		questImageDisplay.texture = dquest.sprite
		PathTextLabel.text = dquest.spriteid
	if IDTextLabel != null:
		IDTextLabel.text = str(dquest.id)
	if NameTextEdit != null:
		NameTextEdit.text = dquest.name
	if DescriptionTextEdit != null:
		DescriptionTextEdit.text = dquest.description
	if steps_container:
		for child in steps_container.get_children():
			child.queue_free()
		for step in dquest.steps:
			add_step_from_data(step)  # Loads step UI and metadata

	# Load rewards
	if rewards_item_list:
		for child in rewards_item_list.get_children():
			child.queue_free()
		for reward in dquest.rewards:
			add_reward_entry(reward["item_id"], reward["amount"], true)


# This function takes all data from the form elements and stores them in the DQuest instance
# Since dquest is a reference to an item in Gamedata.mods.by_id("Core").quests
# the central array for quest data is updated with the changes as well
# The function will signal to Gamedata that the data has changed and needs to be saved
func _on_save_button_button_up() -> void:
	dquest.spriteid = PathTextLabel.text
	dquest.sprite = questImageDisplay.texture
	dquest.name = NameTextEdit.text
	dquest.description = DescriptionTextEdit.text
	dquest.steps = []

	for hbox in steps_container.get_children():
		var step = {}
		var step_type_label = hbox.get_child(0) as Label

		# Handle each step type
		if step_type_label.text == "Craft item:":
			step["type"] = "craft"
			step["item"] = (hbox.get_child(1)).get_text()
		elif step_type_label.text == "Spawn item:":
			step["type"] = "spawn_item"
			step["item"] = (hbox.get_child(1)).get_text()
			step["amount"] = (hbox.get_child(2) as SpinBox).value
		elif step_type_label.text == "Spawn mob:":
			step["type"] = "spawn_mob"
			step["mob"] = (hbox.get_child(1)).get_text()
			step["map_id"] = (hbox.get_child(2)).get_text()
		elif step_type_label.text == "Collect:":
			step["type"] = "collect"
			step["item"] = (hbox.get_child(1)).get_text()
			step["amount"] = (hbox.get_child(2) as SpinBox).value
		elif step_type_label.text == "Call function:":
			step["type"] = "call"
			step["function"] = (hbox.get_child(1) as OptionButton).get_item_text(0)
			step["params"] = (hbox.get_child(2) as TextEdit).text
		elif step_type_label.text == "Enter map:":
			step["type"] = "enter"
			step["map_id"] = (hbox.get_child(1)).get_text()
			var myoptionbutton: OptionButton = hbox.get_child(2)
			step["reveal_condition"] = myoptionbutton.get_item_text(myoptionbutton.selected)
		elif step_type_label.text == "Kill:":
			step["type"] = "kill"
			var dropable_control = hbox.get_child(1) as HBoxContainer
			var mob_or_group = dropable_control.get_text()
			var entity_type = dropable_control.get_meta("entity_type")

			if entity_type == "mob":
				step["mob"] = mob_or_group
			elif entity_type == "mobgroup":
				step["mobgroup"] = mob_or_group
			else:
				print_debug("Invalid entity type metadata: " + str(entity_type))

			step["amount"] = (hbox.get_child(2) as SpinBox).value
			var map_guide_option_button: OptionButton = hbox.get_child(3)
			step["map_guide"] = map_guide_option_button.get_item_text(map_guide_option_button.selected)

		# **Retrieve tip and description from metadata**
		var step_tip = hbox.get_meta("tip", "")
		if step_tip != "":
			step["tip"] = step_tip  # Only add tip if it's not empty

		var step_description = hbox.get_meta("description", "")
		if step_description != "":
			step["description"] = step_description  # Only add description if it's not empty

		dquest.steps.append(step)

	# Save rewards
	var rewards = []
	for i in range(0, rewards_item_list.get_child_count(), 3):
		var label = rewards_item_list.get_child(i) as Label
		var spinbox = rewards_item_list.get_child(i + 1) as SpinBox
		var reward = {
			"item_id": label.text,
			"amount": spinbox.value
		}
		rewards.append(reward)

	# If there are no rewards, remove the rewards property from dquest
	if rewards.size() > 0:
		dquest.rewards = rewards
	else:
		dquest.rewards.clear()

	dquest.changed(olddata)
	data_changed.emit()
	olddata = DQuest.new(dquest.get_data().duplicate(true), null)




# When the questImageDisplay is clicked, the user will be prompted to select an image from
# "res://Mods/Core/Quests/". The texture of the questImageDisplay will change to the selected image
func _on_quest_image_display_gui_input(event) -> void:
	if event is InputEventMouseButton and event.pressed:
		questSelector.show()


func _on_sprite_selector_sprite_selected_ok(clicked_sprite) -> void:
	var questTexture: Resource = clicked_sprite.get_texture()
	questImageDisplay.texture = questTexture
	PathTextLabel.text = questTexture.resource_path.get_file()


# Function to add a step based on the step type selected
func _on_add_step_button_button_up():
	var step_type = step_type_option_button.get_selected_id()
	var empty_step = {}

	match step_type:
		0: # Craft item
			empty_step = {"type": "craft", "item": ""}
		1: # Collect x amount of item
			empty_step = {"type": "collect", "item": "", "amount": 1}
		2: # Call function
			empty_step = {"type": "call", "function": "QuestManager.testfunc()", "params": ""}
		3: # Enter map
			empty_step = {"type": "enter", "map_id": ""}
		4: # Kill x mobs of type
			empty_step = {"type": "kill", "mob": "", "amount": 1}
		5: # Spawn item on map
			empty_step = {"type": "spawn_item", "item": "", "amount": 1}
		6: # Spawn mob on map
			empty_step = {"type": "spawn_mob", "mob": "", "map_id": ""}

	add_step_from_data(empty_step)


# This function adds a craft step
func add_craft_step(step: Dictionary) -> HBoxContainer:
	var hbox = HBoxContainer.new()
	var labelinstance: Label = Label.new()
	labelinstance.text = "Craft item:"
	hbox.add_child(labelinstance)
	var dropabletextedit_instance: HBoxContainer = dropabletextedit.instantiate()
	dropabletextedit_instance.set_text(step["item"])
	dropabletextedit_instance.set_meta("step_type", "craft")
	dropabletextedit_instance.myplaceholdertext = "Drop an item from the left menu"
	set_drop_functions(dropabletextedit_instance)
	hbox.add_child(dropabletextedit_instance)
	return hbox


# This function adds a collect step
func add_collect_step(step: Dictionary) -> HBoxContainer:
	var hbox = HBoxContainer.new()
	var labelinstance: Label = Label.new()
	labelinstance.text = "Collect:"
	hbox.add_child(labelinstance)
	var dropabletextedit_instance: HBoxContainer = dropabletextedit.instantiate()
	dropabletextedit_instance.set_text(step["item"])
	dropabletextedit_instance.set_meta("step_type", "collect")
	dropabletextedit_instance.myplaceholdertext = "Drop an item from the left menu"
	set_drop_functions(dropabletextedit_instance)
	hbox.add_child(dropabletextedit_instance)
	var spinbox = SpinBox.new()
	spinbox.min_value = 1
	spinbox.value = step["amount"]
	hbox.add_child(spinbox)
	return hbox


# This function adds a call step
func add_call_step(step: Dictionary) -> HBoxContainer:
	var hbox = HBoxContainer.new()
	var labelinstance: Label = Label.new()
	labelinstance.text = "Call function:"
	hbox.add_child(labelinstance)
	var optionbutton = OptionButton.new()
	optionbutton.add_item(step["function"])
	hbox.add_child(optionbutton)
	var textedit = TextEdit.new()
	textedit.text = step["params"]
	hbox.add_child(textedit)
	return hbox


# This function adds an enter step with a dropdown to select the state
func add_enter_step(step: Dictionary) -> HBoxContainer:
	var hbox = HBoxContainer.new()

	# Add the label
	var labelinstance: Label = Label.new()
	labelinstance.text = "Enter map:"
	hbox.add_child(labelinstance)

	# Add the dropable text edit for the map ID
	var dropabletextedit_instance: HBoxContainer = dropabletextedit.instantiate()
	dropabletextedit_instance.set_text(step["map_id"])
	dropabletextedit_instance.set_meta("step_type", "enter")
	dropabletextedit_instance.myplaceholdertext = "Drop a map from the left menu"
	set_drop_functions(dropabletextedit_instance)
	hbox.add_child(dropabletextedit_instance)

	# Add the dropdown for selecting the state
	var dropdown = OptionButton.new()
	dropdown.add_item("HIDDEN")   # Default state
	dropdown.add_item("REVEALED") # The map is revealed
	dropdown.add_item("EXPLORED") # The map is explored
	dropdown.add_item("VISITED")  # The map is visited

	# Set the tooltip text to explain the options
	dropdown.tooltip_text = "Select the state of the target map on the overmap:\n" + \
		"HIDDEN: Will only target an instance of this map that isn't revealed yet.\n" + \
		"REVEALED: Will target an instance of this map that is visible on the overmap. \n" + \
		"If no instance of this map is visible on the overmap, it will target a hidden instance instead\n" + \
		"EXPLORED: Targets an instance of this map that has been loaded as a terrain \n" + \
		"chunk in proximity (meaning the player has been close to this, but hasn't \n" + \
		"visited it yet). If no instance of this map can be found in the explored state, \n" + \
		"it will target one that's in the revealed state instead.\n" + \
		"VISITED: Targets an instance of this map that has been previously visited by \n" + \
		"the player (meaning the player has entered the map's boundary). If no instance \n" + \
		"of this map can be found in the visited state, it will target one in the explored state instead.\n\n" + \
		"This can be used to encourage the player to explore, or keep him in familiar terrain."

	# Optionally, set the initial selection based on step data
	if step.has("reveal_condition"):
		var state = step["reveal_condition"]
		if state == "HIDDEN":
			dropdown.select(0)
		elif state == "REVEALED":
			dropdown.select(1)
		elif state == "EXPLORED":
			dropdown.select(2)
		elif state == "VISITED":
			dropdown.select(3)
	else:
		dropdown.select(0)  # Default to "HIDDEN"

	hbox.add_child(dropdown)

	return hbox


# This function adds a kill step with a reveal condition option
func add_kill_step(step: Dictionary) -> HBoxContainer:
	var hbox = HBoxContainer.new()

	# Add the label
	var label_instance: Label = Label.new()
	label_instance.text = "Kill:"
	hbox.add_child(label_instance)

	# Add the dropable text edit for the mob or mobgroup ID
	var entity_type: String = "mob" if step.has("mob") else "mobgroup" if step.has("mobgroup") else ""
	var dropable_textedit_instance: HBoxContainer = dropabletextedit.instantiate()
	dropable_textedit_instance.set_text(step.get("mob", step.get("mobgroup", "")))
	dropable_textedit_instance.set_meta("step_type", "kill")
	# Set metadata to specify if this is a mob or mobgroup
	dropable_textedit_instance.set_meta("entity_type", entity_type)
	dropable_textedit_instance.myplaceholdertext = "Drop a mob or mobgroup from the left menu"
	set_drop_functions(dropable_textedit_instance)
	hbox.add_child(dropable_textedit_instance)

	# Add the SpinBox for the kill amount
	var spinbox = SpinBox.new()
	spinbox.min_value = 1
	spinbox.value = step["amount"]
	spinbox.tooltip_text = "The amount to kill"
	hbox.add_child(spinbox)

	# Add the reveal condition OptionButton
	var map_guide_button = create_map_guide_option_button()
	# Set the initial selection based on step data, if available
	if step.has("map_guide"):
		match step["map_guide"]:
			"none": map_guide_button.select(0)
			"hidden": map_guide_button.select(1)
			"revealed": map_guide_button.select(2)
			"explored": map_guide_button.select(3)
	else:
		map_guide_button.select(0)  # Default to "none"
	hbox.add_child(map_guide_button)

	return hbox


# Adds a spawn item step. The user configures an item id and an amount
# When this step is reached in-game, the item will spawn on the map where the player is at
func add_spawn_item_step(step: Dictionary) -> HBoxContainer:
	var hbox = HBoxContainer.new()
	var labelinstance: Label = Label.new()
	labelinstance.text = "Spawn item:"
	hbox.add_child(labelinstance)

	var dropabletextedit_instance: HBoxContainer = dropabletextedit.instantiate()
	dropabletextedit_instance.set_text(step["item"])
	dropabletextedit_instance.set_meta("step_type", "spawn_item")
	dropabletextedit_instance.myplaceholdertext = "Drop an item from the left menu"
	dropabletextedit_instance.tooltip_text = "The id of the item to spawn. The item \n" + \
		" will spawn on the map that the player is currently on. So if the player is \n" + \
		" at the overmap coordinate (-4,2), the item will spawn on the chunk that \n" + \
		" represents that coordinate. First, it will try to spawn in a static \n" + \
		" furniture container on the same y level as the player. If that's not  \n" + \
		" available, it will find an empty tile and spawn the item there."
	set_drop_functions(dropabletextedit_instance)
	hbox.add_child(dropabletextedit_instance)

	var spinbox = SpinBox.new()
	spinbox.min_value = 1
	spinbox.value = step["amount"]
	hbox.add_child(spinbox)

	return hbox


# Adds a spawn mob step. The user configures a mob id and a map id where it will spawn
func add_spawn_mob_step(step: Dictionary) -> HBoxContainer:
	var hbox = HBoxContainer.new()
	var labelinstance: Label = Label.new()
	labelinstance.text = "Spawn mob:"
	hbox.add_child(labelinstance)

	# Mob ID (dropable)
	var mob_dropabletextedit_instance: HBoxContainer = dropabletextedit.instantiate()
	mob_dropabletextedit_instance.set_text(step["mob"])
	mob_dropabletextedit_instance.set_meta("step_type", "spawn_mob")
	mob_dropabletextedit_instance.myplaceholdertext = "Drop a mob from the left menu"
	mob_dropabletextedit_instance.tooltip_text = "The mob that will spawn on the \n" + \
		"selected map. The mob will spawn the moment the player gets close enough. \n" + \
		"Then the quest will move on to the next step."
	set_drop_functions(mob_dropabletextedit_instance)
	hbox.add_child(mob_dropabletextedit_instance)

	# Map ID (dropable)
	var map_dropabletextedit_instance: HBoxContainer = dropabletextedit.instantiate()
	map_dropabletextedit_instance.set_text(step["map_id"])
	map_dropabletextedit_instance.set_meta("step_type", "spawn_mob_map")
	map_dropabletextedit_instance.myplaceholdertext = "Drop a map from the left menu"
	map_dropabletextedit_instance.tooltip_text = "The map that the mob will spawn on. \n" + \
		"This will select the nearest overmap cell with this map id that's either \n" + \
		"hidden or revealed (meaning the player hasn't seen it or hasn't been close \n" + \
		"enough). The player will see a marker on the map for the target location. \n" + \
		"When the player gets close enough, the marker will disappear, the mob will \n" + \
		"spawn and the quest moves on to the next step."
	set_drop_functions(map_dropabletextedit_instance)
	hbox.add_child(map_dropabletextedit_instance)
	return hbox

# Create UI for a quest step using the appropriate factory
func create_step_ui(step: Dictionary) -> HBoxContainer:
	var factory: Callable = step_factories.get(step.get("type", ""), null)
	if factory:
		return factory.call(step)
	print_debug("No factory for step type: " + str(step.get("type", "")))
	return HBoxContainer.new()


# This function adds the move up, move down, and delete controls to a step
func add_step_controls(hbox: HBoxContainer):
	# Create the settings button (⚙️)
	var settings_button = Button.new()
	settings_button.text = "⚙️"  # Use a cog emoji as the button text
	settings_button.tooltip_text = "Edit step properties"
	settings_button.pressed.connect(_on_settings_button_pressed.bind(hbox))
	hbox.add_child(settings_button)

	var move_up_button = Button.new()
	move_up_button.text = "^"
	move_up_button.pressed.connect(_on_move_up_button_pressed.bind(hbox))
	hbox.add_child(move_up_button)

	var move_down_button = Button.new()
	move_down_button.text = "v"
	move_down_button.pressed.connect(_on_move_down_button_pressed.bind(hbox))
	hbox.add_child(move_down_button)

	var delete_button = Button.new()
	delete_button.text = "X"
	delete_button.pressed.connect(_on_delete_button_pressed.bind(hbox))
	hbox.add_child(delete_button)



# This function creates a step from loaded data
func add_step_from_data(step: Dictionary):
	var hbox: HBoxContainer = create_step_ui(step)
	add_step_controls(hbox)

	# **Store tip and description in metadata**
	if step.has("tip"):
		hbox.set_meta("tip", step["tip"])  # Save tip to metadata
	if step.has("description"):
		hbox.set_meta("description", step["description"])  # Save description to metadata

	steps_container.add_child(hbox)



# Function to handle moving a step up
func _on_move_up_button_pressed(hbox: HBoxContainer):
	var index = get_child_index(steps_container, hbox)
	if index > 0:
		steps_container.move_child(hbox, index - 1)


# Function to handle moving a step down
func _on_move_down_button_pressed(hbox: HBoxContainer):
	var index = get_child_index(steps_container, hbox)
	if index < steps_container.get_child_count() - 1:
		steps_container.move_child(hbox, index + 1)


# Function to handle deleting a step
func _on_delete_button_pressed(hbox: HBoxContainer):
	hbox.queue_free()


# Function to get the index of a child in the steps_container
func get_child_index(container: VBoxContainer, child: Control) -> int:
	var index = 0
	for element in container.get_children():
		if element == child:
			return index
		index += 1
	return -1


# Called when the user has successfully dropped data onto the texteditcontrol
# We are expecting a dictionary like this:
#	{
#		"id": selected_item_id,
#		"text": selected_item_text,
#		"mod_id": mod_id,
#		"contentType": contentType # an DMod.ContentType
#	}
func entity_drop(dropped_data: Dictionary, texteditcontrol: HBoxContainer) -> void:
	if dropped_data and "id" in dropped_data:
		var step_type = texteditcontrol.get_meta("step_type")
		var entity_type = ""  # To store whether it is mob or mobgroup

		var content_type: DMod.ContentType = dropped_data.get("contentType", -1)
		var mymod: String = dropped_data.get("mod_id", "")
		var datainstance: RefCounted = Gamedata.mods.by_id(mymod).get_data_of_type(content_type)

		if content_type == DMod.ContentType.MOBS:
			entity_type = "mob"
		elif content_type == DMod.ContentType.MOBGROUPS:
			entity_type = "mobgroup"

		if datainstance.has_id(dropped_data["id"]):
			texteditcontrol.set_text(dropped_data["id"])
			if step_type == "kill":
				# Set metadata to specify if this is a mob or mobgroup
				texteditcontrol.set_meta("entity_type", entity_type)


# Determines if the dropped data can be accepted
# We are expecting a dictionary like this:
#	{
#		"id": selected_item_id,
#		"text": selected_item_text,
#		"mod_id": mod_id,
#		"contentType": contentType # an DMod.ContentType
#	}
func can_entity_drop(dropped_data: Dictionary, _texteditcontrol: HBoxContainer) -> bool:
	if not dropped_data or not dropped_data.has("id"):
		return false
	var content_type: DMod.ContentType = dropped_data.get("contentType", -1)
	var mymod: String = dropped_data.get("mod_id", "")
	var datainstance: RefCounted = Gamedata.mods.by_id(mymod).get_data_of_type(content_type)
	return datainstance.has_id(dropped_data["id"])


# Set the drop functions on the provided control. It should be a dropabletextedit
# This enables them to receive drop data
func set_drop_functions(mydropabletextedit):
	mydropabletextedit.drop_function = entity_drop.bind(mydropabletextedit)
	mydropabletextedit.can_drop_function = can_entity_drop.bind(mydropabletextedit)


# This function should return true if the dragged data can be dropped here
# We are expecting a dictionary like this:
#	{
#		"id": selected_item_id,
#		"text": selected_item_text,
#		"mod_id": mod_id,
#		"contentType": contentType
#	}
func _can_drop_reward(_newpos, data: Dictionary) -> bool:
	# Check if the data dictionary has the 'id' property
	if not data or not data.has("id"):
		return false

	# Fetch item data by ID from the Gamedata to ensure it exists and is valid
	if not Gamedata.mods.by_id(data["mod_id"]).items.has_id(data["id"]):
		return false

	# Check if the item ID already exists in the resources grid
	var children = rewards_item_list.get_children()
	for i in range(0, children.size(), 3):  # Step by 3 to handle label-spinbox-deleteButton triples
		var label = children[i] as Label
		if label.text == data["id"]:
			# Return false if this item ID already exists in the resources grid
			return false

	# If all checks pass, return true
	return true


# This function handles the data being dropped
func _drop_reward_data(newpos, data: Dictionary) -> void:
	if _can_drop_reward(newpos, data):
		_handle_reward_drop(data, newpos)


# Called when the user has successfully dropped data onto the rewards_item_list
# We have to check the dropped_data for the id property
# We are expecting a dictionary like this:
#	{
#		"id": selected_item_id,
#		"text": selected_item_text,
#		"mod_id": mod_id,
#		"contentType": contentType
#	}
func _handle_reward_drop(dropped_data: Dictionary, _newpos: Vector2) -> void:
	# Dropped_data is a Dictionary that includes an 'id'
	if dropped_data and "id" in dropped_data:
		var item_id = dropped_data["id"]
		if not Gamedata.mods.by_id(dropped_data["mod_id"]).items.has_id(item_id):
			print_debug("No item data found for ID: " + item_id)
			return

		# Add the reward entry using the new function
		add_reward_entry(item_id, 1, false)
	else:
		print_debug("Dropped data does not contain an 'id' key.")


# Adds UI elements to control the rewards
# Parameters:
# - item_id: The ID of the item being added as a reward
# - amount: The initial amount of the item
# - use_loaded_amount: Boolean to determine if the loaded amount should be used (default is false)
func add_reward_entry(item_id: String, amount: int = 1, use_loaded_amount: bool = false):
	# Get item data using the item ID
	var item: DItem = Gamedata.mods.get_content_by_id(DMod.ContentType.ITEMS, item_id)

	# Create UI elements for the reward
	var label = Label.new()
	label.text = item_id
	rewards_item_list.add_child(label)

	# Create and configure the amount SpinBox
	var amountSpinBox = SpinBox.new()
	amountSpinBox.max_value = item.max_stack_size

	if use_loaded_amount:
		amountSpinBox.value = amount
	else:
		amountSpinBox.value = item.stack_size

	rewards_item_list.add_child(amountSpinBox)

	# Create and configure the delete button
	var deleteButton = Button.new()
	deleteButton.text = "X"
	deleteButton.pressed.connect(_delete_reward.bind([label, amountSpinBox, deleteButton]))
	rewards_item_list.add_child(deleteButton)


# Deleting a reward UI element
func _delete_reward(elements_to_remove: Array) -> void:
	for element in elements_to_remove:
		rewards_item_list.remove_child(element)
		element.queue_free()  # Properly free the node to avoid memory leaks


# Function to create an OptionButton for selecting map guide
func create_map_guide_option_button() -> OptionButton:
	var option_button = OptionButton.new()

	# Add items to the OptionButton
	option_button.add_item("none")      # No guide
	option_button.add_item("hidden")   # Target appears on unrevealed locations
	option_button.add_item("revealed") # Target appears on revealed locations
	option_button.add_item("explored") # Target appears on explored locations

	# Set a user-friendly tooltip text
	option_button.tooltip_text = "Select how the player will be guided to the right location in this step:\n\n" + \
		"1. **none**: No guide will be provided.\n" + \
		"2. **hidden**: The target will only appear on locations that have not been revealed on the overmap.\n" + \
		"3. **revealed**: The target will appear on a location that has been revealed, but not explored.\n" + \
		"4. **explored**: The target will appear on a location that has been explored (the player has been close by or on it).\n\n" + \
		"If no location meets the selected criteria, fallback options will be used in this order:\n" + \
		"- Explored → Revealed → Hidden\n\n" + \
		"The closest map that allows the player to complete this step will be selected. If the player enters the \n" + \
		"target map and has not completed this step, a new target will be selected."

	return option_button

# Function to open the step properties popup
func _on_settings_button_pressed(hbox: HBoxContainer):
	selected_step = hbox  # Store the reference to the step being edited
	hint_text_edit.text = selected_step.get_meta("tip", "")  # Load tip from metadata
	description_text_edit.text = selected_step.get_meta("description", "")  # Load description from metadata
	step_properties_popup_panel.popup_centered()

# Function to handle OK button press
func _on_ok_button_pressed():
	if selected_step:
		selected_step.set_meta("tip", hint_text_edit.text)  # Store tip in metadata
		selected_step.set_meta("description", description_text_edit.text)  # Store description in metadata
	step_properties_popup_panel.hide()


# Function to handle Cancel button press
func _on_cancel_button_pressed():
	step_properties_popup_panel.hide()  # Hide the popup
