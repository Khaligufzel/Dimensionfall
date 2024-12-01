extends Control

# This scene is intended to be used inside the content editor
# It is supposed to edit exactly one Mobfaction
# It expects to save the data to a JSON file
# To load data, provide the name of the mobfaction data file and an ID

@export var IDTextLabel: Label = null
@export var PathTextLabel: Label = null
@export var NameTextEdit: TextEdit = null
@export var DescriptionTextEdit: TextEdit = null
@export var mob_list: GridContainer = null


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
