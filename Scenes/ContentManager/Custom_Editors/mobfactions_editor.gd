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
#func _ready() -> void:
	#relation_list.set_drag_forwarding(Callable(), _can_drop_mob_data, _drop_mob_data)

# The editor is closed, destroy the instance
# TODO: Check for unsaved changes
func _on_close_button_button_up() -> void:
	queue_free()

# This function updates the form based on the DMobfaction that has been loaded
func load_mobfaction_data() -> void:
	if IDTextLabel != null:
		IDTextLabel.text = str(dmobfaction.id)
	if NameTextEdit != null:
		NameTextEdit.text = dmobfaction.name
	if DescriptionTextEdit != null:
		DescriptionTextEdit.text = dmobfaction.description
	if relations_container:
		for child in relations_container.get_children():
			child.queue_free()
		for relation in dmobfaction.relations:
			add_relation_from_data(relation)

# This function takes all data from the form elements and stores them in the DMobfaction instance
# Since dmobfaction is a reference to an item in Gamedata.mobfactions
# the central array for mobfaction data is updated with the changes as well
# The function will signal to Gamedata that the data has changed and needs to be saved
func _on_save_button_button_up() -> void:
	dmobfaction.name = NameTextEdit.text
	dmobfaction.description = DescriptionTextEdit.text
	dmobfaction.changed(olddata)
	dmobfaction.relations = []
	
	for hbox in relations_container.get_children():
		var relation = {}
		var relation_type_label = hbox.get_child(0) as Label
	
	# Handle each relation type
		if relation_type_label.text == "Relation type:":
			relation["type"] = "core"
			var dropable_control = hbox.get_child(1) as HBoxContainer
			var mob_or_group = dropable_control.get_text()
			var entity_type = dropable_control.get_meta("entity_type")
		if relation_type_label.text == "Relation type:":
			relation["type"] = "friendly"
			var dropable_control = hbox.get_child(1) as HBoxContainer
			var mob_or_group = dropable_control.get_text()
			var entity_type = dropable_control.get_meta("entity_type")
		if relation_type_label.text == "Relation type:":
			relation["type"] = "neutral"
			var dropable_control = hbox.get_child(1) as HBoxContainer
			var mob_or_group = dropable_control.get_text()
			var entity_type = dropable_control.get_meta("entity_type")
		if relation_type_label.text == "Relation type:":
			relation["type"] = "hostile"
			var dropable_control = hbox.get_child(1) as HBoxContainer
			var mob_or_group = dropable_control.get_text()
			var entity_type = dropable_control.get_meta("entity_type")
			
			# Save as mob or mobgroup based on metadata
			if entity_type == "mob":
				relation["mob"] = mob_or_group
			elif entity_type == "mobgroup":
				relation["mobgroup"] = mob_or_group
			else:
				print_debug("Invalid entity type metadata: " + str(entity_type))
				dmobfaction.relations.append(relation)
	dmobfaction.changed(olddata)
	data_changed.emit()
	olddata = DMobfaction.new(dmobfaction.get_data().duplicate(true))

# Function to add a relation based on the relation type selected
func _on_add_relation_button_button_up():
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
	
func add_relation_type(relation: Dictionary) -> HBoxContainer:
	var hbox = HBoxContainer.new()

	# Add the label
	var label_instance: Label = Label.new()
	label_instance.text = "Relation type:"
	hbox.add_child(label_instance)

	# Add the dropable text edit for the mob or mobgroup ID
	var dropable_textedit_instance: HBoxContainer = dropabletextedit.instantiate()
	dropable_textedit_instance.set_text(relation.get("mob", relation.get("mobgroup", "")))
	dropable_textedit_instance.set_meta("relation_type", "core")
	dropable_textedit_instance.set_meta("relation_type", "friendly")
	dropable_textedit_instance.set_meta("relation_type", "neutral")
	dropable_textedit_instance.set_meta("relation_type", "hostile")
	dropable_textedit_instance.myplaceholdertext = "Drop a mob or mobgroup from the left menu"
	set_drop_functions(dropable_textedit_instance)
	hbox.add_child(dropable_textedit_instance)
	return hbox

func add_relations_controls(hbox: HBoxContainer, relation: Dictionary):
	var delete_button = Button.new()
	delete_button.text = "X"
	delete_button.pressed.connect(_on_delete_button_pressed.bind(hbox))
	hbox.add_child(delete_button)

# This function creates a relation from loaded data
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
	add_relations_controls(hbox, relation)
	relations_container.add_child(hbox)

func get_child_index(container: VBoxContainer, child: Control) -> int:
	var index = 0
	for element in container.get_children():
		if element == child:
			return index
		index += 1
	return -1

func entity_drop(dropped_data: Dictionary, texteditcontrol: HBoxContainer) -> void:
	if dropped_data and "id" in dropped_data:
		var relation_type = texteditcontrol.get_meta("relation_type")
		var valid_data = false
		var entity_type = ""  # To store whether it is mob or mobgroup
		
		match relation_type:
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
					
		if valid_data:
			texteditcontrol.set_text(dropped_data["id"])
			if relation_type == "core" or relation_type == "friendly" or relation_type == "neutral" or relation_type == "hostile":
				# Set metadata to specify if this is a mob or mobgroup
				texteditcontrol.set_meta("entity_type", entity_type)
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

# Function to handle deleting a relation
func _on_delete_button_pressed(hbox: HBoxContainer):
	hbox.queue_free()
