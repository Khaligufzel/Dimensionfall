extends Control

# This scene is intended to be used inside the content editor
# It is supposed to edit exactly one Mobfaction
# It expects to save the data to a JSON file
# To load data, provide the name of the mobfaction data file and an ID

@export var IDTextLabel: Label = null
# @export var PathTextLabel: Label = null
@export var NameTextEdit: TextEdit = null
@export var DescriptionTextEdit: TextEdit = null
@export var mob_list: GridContainer = null
@export var relation_type_option_button: OptionButton
@export var relations_container: VBoxContainer
@export var dropabletextedit: PackedScene = null


# This signal will be emitted when the user presses the save button
# This signal should alert Gamedata that the mobfaction data array should be saved to disk
signal data_changed()

var olddata: DMobfaction # Remember what the value of the data was before editing

# The data that represents this mobfaction
# The data is selected from the Gamedata.mobfactions
# based on the ID that the user has selected in the content editor
var dmobfaction: DMobfaction = null:
	set(value):
		dmobfaction = value
		load_mobfaction_data()
		olddata = DMobfaction.new(dmobfaction.get_data().duplicate(true))



# Forward drag-and-drop functionality to the attributesGridContainer
func _ready() -> void:
	mob_list.set_drag_forwarding(Callable(), _can_drop_mob_data, _drop_mob_data)


# This function updates the form based on the DMobfaction that has been loaded
func load_mobfaction_data() -> void:
	if IDTextLabel != null:
		IDTextLabel.text = str(dmobfaction.id)
	if NameTextEdit != null:
		NameTextEdit.text = dmobfaction.name
	if DescriptionTextEdit != null:
		DescriptionTextEdit.text = dmobfaction.description
	update_mob_list()

# The editor is closed, destroy the instance
# TODO: Check for unsaved changes
func _on_close_button_button_up() -> void:
	queue_free()

# This function takes all data from the form elements and stores them in the DMobfaction instance
# Since dmobfaction is a reference to an item in Gamedata.mobfactions
# the central array for mobfaction data is updated with the changes as well
# The function will signal to Gamedata that the data has changed and needs to be saved
func _on_save_button_button_up() -> void:
	save_mob_list_to_dmobfaction()
	dmobfaction.name = NameTextEdit.text
	dmobfaction.description = DescriptionTextEdit.text
	dmobfaction.changed(olddata)
	data_changed.emit()
	olddata = DMobfaction.new(dmobfaction.get_data().duplicate(true))

# Refreshes the mob_list based on the dmobfaction data
func update_mob_list():
	# Clear all existing children in mob_list
	while mob_list.get_child_count() > 0:
		var child = mob_list.get_child(0)
		mob_list.remove_child(child)
		child.queue_free()
	
	add_header_row_to_mob_list()
	
	# Populate mob_list with data from dmobfaction.mobs
	for mob_id in dmobfaction.mobs.keys():
		var weight = dmobfaction.mobs[mob_id]
		add_mob_entry(mob_id)


# Adds a new mob and its controls to the mob_list
func add_mob_entry(mob_id: String):
	var mob_icon = TextureRect.new()
	var mob_sprite = Gamedata.mobs.sprite_by_id(mob_id)
	mob_icon.texture = mob_sprite
	mob_icon.custom_minimum_size = Vector2(16, 16)

	var mob_label = Label.new()
	mob_label.text = mob_id

	var delete_button = Button.new()
	delete_button.text = "X"
	delete_button.button_up.connect(_on_delete_mob_button_pressed.bind(mob_id))

	# Add components to GridContainer
	mob_list.add_child(mob_icon)
	mob_list.add_child(mob_label)
	mob_list.add_child(delete_button)


# Deletes the mob entry from mob_list
func _on_delete_mob_button_pressed(mob_id: String):
	var num_columns = mob_list.columns
	var children_to_remove = []
	
	for i in range(mob_list.get_child_count()):
		var child = mob_list.get_child(i)
		if child is Label and child.text == mob_id:
			var start_index = i - (i % num_columns)
			for j in range(num_columns):
				children_to_remove.append(mob_list.get_child(start_index + j))
			break
	
	for child in children_to_remove:
		mob_list.remove_child(child)
		child.queue_free()
	
	# Remove mob from dmobfaction.mobs
	dmobfaction.mobs.erase(mob_id)


# Adds a header row to mob_list
func add_header_row_to_mob_list():
	var headers = ["Sprite", "Mob ID", "Delete"]
	for header_text in headers:
		var header_label = Label.new()
		header_label.text = header_text
		header_label.set_horizontal_alignment(HORIZONTAL_ALIGNMENT_CENTER)
		mob_list.add_child(header_label)


# Checks if the dropped mob can be added to mob_list
func _can_drop_mob_data(_newpos, data) -> bool:
	if not data or not data.has("id"):
		return false
	var mob_id = data["id"]
	return Gamedata.mobs.has_id(mob_id) and not dmobfaction.mobs.has(mob_id)


# Handles mob data being dropped
func _drop_mob_data(newpos, data) -> void:
	if _can_drop_mob_data(newpos, data):
		var mob_id = data["id"]
		dmobfaction.mobs[mob_id] = 1  # Default weight is 1
		add_mob_entry(mob_id)

# Save the mob data from mob_list into dmobfaction
func save_mob_list_to_dmobfaction():
	var new_mobs = {}
	var num_columns = mob_list.columns
	var num_children = mob_list.get_child_count()
	
	for i in range(4, num_children, num_columns):  # Skip header
		var mob_id = mob_list.get_child(i + 1).text
		new_mobs[mob_id]
	
	dmobfaction.mobs = new_mobs

func entity_drop(dropped_data: Dictionary, texteditcontrol: HBoxContainer) -> void:
	if dropped_data and "id" in dropped_data:
		var step_type = texteditcontrol.get_meta("step_type")
		var valid_data = false
		var entity_type = ""  # To store whether it is mob or mobgroup
		
		match step_type:
			"craft", "collect":
				valid_data = Gamedata.items.has_id(dropped_data["id"])
			"core":
				if Gamedata.mobs.has_id(dropped_data["id"]):
					valid_data = true
					entity_type = "mob"
				elif Gamedata.mobgroups.has_id(dropped_data["id"]):
					valid_data = true
					entity_type = "mobgroup"
			"friendly":
				if Gamedata.mobs.has_id(dropped_data["id"]):
					valid_data = true
					entity_type = "mob"
				elif Gamedata.mobgroups.has_id(dropped_data["id"]):
					valid_data = true
					entity_type = "mobgroup"
			"neutral":
				if Gamedata.mobs.has_id(dropped_data["id"]):
					valid_data = true
					entity_type = "mob"
				elif Gamedata.mobgroups.has_id(dropped_data["id"]):
					valid_data = true
					entity_type = "mobgroup"
			"hostile":
				if Gamedata.mobs.has_id(dropped_data["id"]):
					valid_data = true
					entity_type = "mob"
				elif Gamedata.mobgroups.has_id(dropped_data["id"]):
					valid_data = true
					entity_type = "mobgroup"
					
# Determines if the dropped data can be accepted
func can_entity_drop(dropped_data: Dictionary, texteditcontrol: HBoxContainer) -> bool:
	if not dropped_data or not dropped_data.has("id"):
		return false
	
	var relation_type = texteditcontrol.get_meta("relation_type")
	var valid_data = false
	
	match relation_type:
		"core":
			valid_data = Gamedata.mobs.has_id(dropped_data["id"]) or Gamedata.mobgroups.has_id(dropped_data["id"])
		"friendly":
			valid_data = Gamedata.mobs.has_id(dropped_data["id"]) or Gamedata.mobgroups.has_id(dropped_data["id"])
		"neutral":
			valid_data = Gamedata.mobs.has_id(dropped_data["id"]) or Gamedata.mobgroups.has_id(dropped_data["id"])
		"hostile":
			valid_data = Gamedata.mobs.has_id(dropped_data["id"]) or Gamedata.mobgroups.has_id(dropped_data["id"])
	return valid_data

func set_drop_functions(mydropabletextedit):
	mydropabletextedit.drop_function = entity_drop.bind(mydropabletextedit)
	mydropabletextedit.can_drop_function = can_entity_drop.bind(mydropabletextedit)

func add_relation_type(step: Dictionary) -> HBoxContainer:
	var hbox = HBoxContainer.new()

	# Add the label
	var label_instance: Label = Label.new()
	label_instance.text = "Relation type:"
	hbox.add_child(label_instance)

	# Add the dropable text edit for the mob or mobgroup ID
	var dropable_textedit_instance: HBoxContainer = dropabletextedit.instantiate()
	dropable_textedit_instance.set_text(step.get("mob", step.get("mobgroup", "")))
	dropable_textedit_instance.set_meta("step_type", "kill")
	dropable_textedit_instance.myplaceholdertext = "Drop a mob or mobgroup from the left menu"
	set_drop_functions(dropable_textedit_instance)
	hbox.add_child(dropable_textedit_instance)
	return hbox

# This function adds the move up, move down, and delete controls to a step
func add_relation_controls(hbox: HBoxContainer, step: Dictionary):
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

# Function to get the index of a child in the steps_container
func get_child_index(container: VBoxContainer, child: Control) -> int:
	var index = 0
	for element in container.get_children():
		if element == child:
			return index
		index += 1
	return -1

# Function to handle moving a step up
func _on_move_up_button_pressed(hbox: HBoxContainer):
	var index = get_child_index(relations_container, hbox)
	if index > 0:
		relations_container.move_child(hbox, index - 1)

# Function to handle moving a step down
func _on_move_down_button_pressed(hbox: HBoxContainer):
	var index = get_child_index(relations_container, hbox)
	if index < relations_container.get_child_count() - 1:
		relations_container.move_child(hbox, index + 1)
		
# Function to handle deleting a step
func _on_delete_button_pressed(hbox: HBoxContainer):
	hbox.queue_free()

# This function creates a step from loaded data
func add_relation_from_data(relation: Dictionary):
	var hbox: HBoxContainer
	match relation["type"]:
		"core":
			hbox = add_relation_type(relation)
		"friendly":
			hbox = add_relation_type(relation)
		"neutral":
			hbox = add_relation_type(relation)
		"hostile":
			hbox = add_relation_type(relation)

	add_relation_controls(hbox, relation)
	relations_container.add_child(hbox)

func _on_relation_step_button_button_up():
	var relation_type = relation_type_option_button.get_selected_id()
	var empty_relation = {}
	match relation_type:
		0: # Core monsters which will be part of the faction
			empty_relation = {"type": "core", "mob": ""}
		1: # Core monsters which will be part of the faction
			empty_relation = {"type": "friendly", "mob": ""}
		2: # Core monsters which will be part of the faction
			empty_relation = {"type": "neutral", "mob": ""}
		3: # Core monsters which will be part of the faction
			empty_relation = {"type": "hostile", "mob": ""}
	
	add_relation_from_data(empty_relation)
