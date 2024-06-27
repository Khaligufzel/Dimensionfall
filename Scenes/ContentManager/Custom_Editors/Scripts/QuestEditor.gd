extends Control

#This scene is intended to be used inside the content editor
#It is supposed to edit exactly one quest
#It expects to save the data to a JSON file
#To load data, provide the name of the quest data file and an ID

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
signal data_changed(game_data: Dictionary, new_data: Dictionary, old_data: Dictionary)

var olddata: Dictionary # Remember what the value of the data was before editing
# The data that represents this quest
# The data is selected from the Gamedata.data.quests.data array
# based on the ID that the user has selected in the content editor
var contentData: Dictionary = {}:
	set(value):
		contentData = value
		load_quest_data()
		questSelector.sprites_collection = Gamedata.data.quests.sprites
		olddata = contentData.duplicate(true)

func _ready():
	data_changed.connect(Gamedata.on_data_changed)


#The editor is closed, destroy the instance
#TODO: Check for unsaved changes
func _on_close_button_button_up() -> void:
	queue_free()


#This function updates the form based on the contentData that has been loaded
func load_quest_data() -> void:
	if questImageDisplay != null and contentData.has("sprite") and \
	not contentData["sprite"] == "" and Gamedata.data.quests.sprites.has(contentData["sprite"]):
		questImageDisplay.texture = Gamedata.data.quests.sprites[contentData["sprite"]]
		PathTextLabel.text = contentData["sprite"]
	if IDTextLabel != null:
		IDTextLabel.text = str(contentData["id"])
	if NameTextEdit != null and contentData.has("name"):
		NameTextEdit.text = contentData["name"]
	if DescriptionTextEdit != null and contentData.has("description"):
		DescriptionTextEdit.text = contentData["description"]
	if steps_container:
		for child in steps_container.get_children():
			child.queue_free()
		if contentData.has("steps"):
			for step in contentData["steps"]:
				add_step_from_data(step)

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

# This function collects data from each step in the steps_container and stores it in contentData
# Since contentData is a reference to an item in Gamedata.data.quests.data
# the central array for questdata is updated with the changes as well
# The function will signal to Gamedata that the data has changed and needs to be saved
func _on_save_button_button_up() -> void:
	contentData["sprite"] = PathTextLabel.text
	contentData["name"] = NameTextEdit.text
	contentData["description"] = DescriptionTextEdit.text
	contentData["steps"] = []
	for hbox in steps_container.get_children():
		var step = {}
		var step_type_label = hbox.get_child(0) as Label
		if step_type_label.text == "Craft item:":
			step["type"] = "craft"
			step["item"] = (hbox.get_child(1)).get_text()
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
		elif step_type_label.text == "Kill:":
			step["type"] = "kill"
			step["mob"] = (hbox.get_child(1)).get_text()
			step["amount"] = (hbox.get_child(2) as SpinBox).value
		contentData["steps"].append(step)
	data_changed.emit(Gamedata.data.quests, contentData, olddata)
	olddata = contentData.duplicate(true)


# When the questImageDisplay is clicked, the user will be prompted to select an image from 
# "res://Mods/Core/Quests/". The texture of the questImageDisplay will change to the selected image
func _on_quest_image_display_gui_input(event) -> void:
	if event is InputEventMouseButton and event.pressed:
		questSelector.show()

func _on_sprite_selector_sprite_selected_ok(clicked_sprite) -> void:
	var questTexture: Resource = clicked_sprite.get_texture()
	questImageDisplay.texture = questTexture
	PathTextLabel.text = questTexture.resource_path.get_file()


# Function to create a step from loaded data
func add_step_from_data(step):
	var hbox = HBoxContainer.new()
	match step["type"]:
		"craft":
			var labelinstance: Label = Label.new()
			labelinstance.text = "Craft item:"
			hbox.add_child(labelinstance)
			var dropabletextedit_instance: HBoxContainer = dropabletextedit.instantiate()
			dropabletextedit_instance.set_text(step["item"])
			dropabletextedit_instance.set_meta("step_type", "craft")
			dropabletextedit_instance.myplaceholdertext = "Drop an item from the left menu"
			set_drop_functions(dropabletextedit_instance)
			hbox.add_child(dropabletextedit_instance)
		"collect":
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
		"call":
			var labelinstance: Label = Label.new()
			labelinstance.text = "Call function:"
			hbox.add_child(labelinstance)
			var optionbutton = OptionButton.new()
			optionbutton.add_item(step["function"])
			hbox.add_child(optionbutton)
			var textedit = TextEdit.new()
			textedit.text = step["params"]
			hbox.add_child(textedit)
		"enter":
			var labelinstance: Label = Label.new()
			labelinstance.text = "Enter map:"
			hbox.add_child(labelinstance)
			var dropabletextedit_instance: HBoxContainer = dropabletextedit.instantiate()
			dropabletextedit_instance.set_text(step["map_id"])
			dropabletextedit_instance.set_meta("step_type", "enter")
			dropabletextedit_instance.myplaceholdertext = "Drop a map from the left menu"
			set_drop_functions(dropabletextedit_instance)
			hbox.add_child(dropabletextedit_instance)
		"kill":
			var labelinstance: Label = Label.new()
			labelinstance.text = "Kill:"
			hbox.add_child(labelinstance)
			var dropabletextedit_instance: HBoxContainer = dropabletextedit.instantiate()
			dropabletextedit_instance.set_text(step["mob"])
			dropabletextedit_instance.set_meta("step_type", "kill")
			dropabletextedit_instance.myplaceholdertext = "Drop a mob from the left menu"
			set_drop_functions(dropabletextedit_instance)
			hbox.add_child(dropabletextedit_instance)
			var spinbox = SpinBox.new()
			spinbox.min_value = 1
			spinbox.value = step["amount"]
			hbox.add_child(spinbox)

	# Add move up button
	var move_up_button = Button.new()
	move_up_button.text = "^"
	move_up_button.pressed.connect(_on_move_up_button_pressed.bind(hbox))
	hbox.add_child(move_up_button)

	# Add move down button
	var move_down_button = Button.new()
	move_down_button.text = "v"
	move_down_button.pressed.connect(_on_move_down_button_pressed.bind(hbox))
	hbox.add_child(move_down_button)

	# Add delete button
	var delete_button = Button.new()
	delete_button.text = "X"
	delete_button.pressed.connect(_on_delete_button_pressed.bind(hbox))
	hbox.add_child(delete_button)

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
		
		match step_type:
			"craft", "collect":
				valid_data = not Gamedata.get_data_by_id(Gamedata.data.items, dropped_data["id"]).is_empty()
			"kill":
				valid_data = not Gamedata.get_data_by_id(Gamedata.data.mobs, dropped_data["id"]).is_empty()
			"enter":
				valid_data = not Gamedata.get_data_by_id(Gamedata.data.maps, dropped_data["id"]).is_empty()
		
		if valid_data:
			texteditcontrol.set_text(dropped_data["id"])


# Determines if the dropped data can be accepted
func can_entity_drop(dropped_data: Dictionary, texteditcontrol: HBoxContainer) -> bool:
	if not dropped_data or not dropped_data.has("id"):
		return false
	
	var step_type = texteditcontrol.get_meta("step_type")
	var valid_data = false
	
	match step_type:
		"craft", "collect":
			valid_data = not Gamedata.get_data_by_id(Gamedata.data.items, dropped_data["id"]).is_empty()
		"kill":
			valid_data = not Gamedata.get_data_by_id(Gamedata.data.mobs, dropped_data["id"]).is_empty()
		"enter":
			valid_data = not Gamedata.get_data_by_id(Gamedata.data.maps, dropped_data["id"]).is_empty()
	
	return valid_data


# Set the drop functions on the provided control. It should be a dropabletextedit
# This enables them to receive drop data
func set_drop_functions(mydropabletextedit):
	mydropabletextedit.drop_function = entity_drop.bind(mydropabletextedit)
	mydropabletextedit.can_drop_function = can_entity_drop.bind(mydropabletextedit)
