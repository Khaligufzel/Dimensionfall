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

# This signal will be emitted when the user presses the save button
# This signal should alert Gamedata that the quest data array should be saved to disk
signal data_changed()

var olddata: DQuest  # Remember what the value of the data was before editing

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
	# Set custom can_drop_func and drop_func for the rewardscontainer, use default drag_func
	rewards_item_list.set_drag_forwarding(Callable(), _can_drop_reward, _drop_reward_data)

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
			add_step_from_data(step)
	
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
			step["tip"] = (hbox.get_child(2) as TextEdit).text
		elif step_type_label.text == "Collect:":
			step["type"] = "collect"
			step["item"] = (hbox.get_child(1)).get_text()
			step["amount"] = (hbox.get_child(2) as SpinBox).value
			step["tip"] = (hbox.get_child(3) as TextEdit).text
		elif step_type_label.text == "Call function:":
			step["type"] = "call"
			step["function"] = (hbox.get_child(1) as OptionButton).get_item_text(0)
			step["params"] = (hbox.get_child(2) as TextEdit).text
			step["tip"] = (hbox.get_child(2) as TextEdit).text
		elif step_type_label.text == "Enter map:":
			step["type"] = "enter"
			step["map_id"] = (hbox.get_child(1)).get_text()
			var myoptionbutton: OptionButton = hbox.get_child(2)
			step["reveal_condition"] = myoptionbutton.get_item_text(myoptionbutton.selected)
			step["tip"] = (hbox.get_child(3) as TextEdit).text
		elif step_type_label.text == "Kill:":
			step["type"] = "kill"
			var dropable_control = hbox.get_child(1) as HBoxContainer
			var mob_or_group = dropable_control.get_text()
			var entity_type = dropable_control.get_meta("entity_type")

			# Save as mob or mobgroup based on metadata
			if entity_type == "mob":
				step["mob"] = mob_or_group
			elif entity_type == "mobgroup":
				step["mobgroup"] = mob_or_group
			else:
				print_debug("Invalid entity type metadata: " + str(entity_type))

			step["amount"] = (hbox.get_child(2) as SpinBox).value
			var map_guide_option_button: OptionButton = hbox.get_child(3)
			step["map_guide"] = map_guide_option_button.get_item_text(map_guide_option_button.selected)
			step["tip"] = (hbox.get_child(4) as TextEdit).text
		
		# Remove "tip" key if it is empty
		if step["tip"] == "":
			step.erase("tip")
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


# This function adds the move up, move down, and delete controls to a step
func add_step_controls(hbox: HBoxContainer, step: Dictionary):
	# Add custom tip TextEdit
	var tip_textedit = TextEdit.new()
	tip_textedit.placeholder_text = "Enter custom tip here"
	tip_textedit.size_flags_horizontal = Control.SIZE_EXPAND_FILL  # Make TextEdit stretch horizontally
	if step.has("tip"):
		tip_textedit.text = step["tip"]
	hbox.add_child(tip_textedit)
	
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
	var hbox: HBoxContainer
	match step["type"]:
		"craft":
			hbox = add_craft_step(step)
		"collect":
			hbox = add_collect_step(step)
		"call":
			hbox = add_call_step(step)
		"enter":
			hbox = add_enter_step(step)
		"kill":
			hbox = add_kill_step(step)
	add_step_controls(hbox, step)
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
func entity_drop(dropped_data: Dictionary, texteditcontrol: HBoxContainer) -> void:
	if dropped_data and "id" in dropped_data:
		var step_type = texteditcontrol.get_meta("step_type")
		var valid_data = false
		var entity_type = ""  # To store whether it is mob or mobgroup
		
		match step_type:
			"craft", "collect":
				valid_data = Gamedata.items.has_id(dropped_data["id"])
			"kill":
				if dropped_data["contentType"] == DMod.ContentType.MOBS:
					valid_data = true
					entity_type = "mob"
				elif dropped_data["contentType"] == DMod.ContentType.MOBGROUPS:
					valid_data = true
					entity_type = "mobgroup"
			"enter":
				valid_data = Gamedata.mods.by_id(dropped_data["mod_id"]).maps.has_id(dropped_data["id"])
		
		if valid_data:
			texteditcontrol.set_text(dropped_data["id"])
			if step_type == "kill":
				# Set metadata to specify if this is a mob or mobgroup
				texteditcontrol.set_meta("entity_type", entity_type)


# Determines if the dropped data can be accepted
func can_entity_drop(dropped_data: Dictionary, texteditcontrol: HBoxContainer) -> bool:
	if not dropped_data or not dropped_data.has("id"):
		return false
	
	var step_type = texteditcontrol.get_meta("step_type")
	var valid_data = false
	
	match step_type:
		"craft", "collect":
			valid_data = Gamedata.items.has_id(dropped_data["id"])
		"kill":
			valid_data = not Gamedata.mods.get_content_by_id(DMod.ContentType.MOBS, dropped_data["id"]) == null or Gamedata.mobgroups.has_id(dropped_data["id"])
		"enter":
			valid_data = Gamedata.mods.by_id(dropped_data["mod_id"]).maps.has_id(dropped_data["id"])
	
	return valid_data

# Set the drop functions on the provided control. It should be a dropabletextedit
# This enables them to receive drop data
func set_drop_functions(mydropabletextedit):
	mydropabletextedit.drop_function = entity_drop.bind(mydropabletextedit)
	mydropabletextedit.can_drop_function = can_entity_drop.bind(mydropabletextedit)

# This function should return true if the dragged data can be dropped here
func _can_drop_reward(_newpos, data: Dictionary) -> bool:
	# Check if the data dictionary has the 'id' property
	if not data or not data.has("id"):
		return false

	# Fetch item data by ID from the Gamedata to ensure it exists and is valid
	if not Gamedata.items.has_id(data["id"]):
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
func _handle_reward_drop(dropped_data: Dictionary, _newpos: Vector2) -> void:
	# Dropped_data is a Dictionary that includes an 'id'
	if dropped_data and "id" in dropped_data:
		var item_id = dropped_data["id"]
		if not Gamedata.items.has_id(item_id):
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
	var item: DItem = Gamedata.items.by_id(item_id)

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
