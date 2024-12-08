extends Control

# This scene is intended to be used inside the content editor
# It is supposed to edit exactly one Mobgroup
# It expects to save the data to a JSON file
# To load data, provide the name of the mobgroup data file and an ID

@export var mobgroupImageDisplay: TextureRect = null
@export var IDTextLabel: Label = null
@export var PathTextLabel: Label = null
@export var NameTextEdit: TextEdit = null
@export var DescriptionTextEdit: TextEdit = null
@export var mobgroupSelector: Popup = null
@export var mob_list: GridContainer = null


# This signal will be emitted when the user presses the save button
# This signal should alert Gamedata that the mobgroup data array should be saved to disk
signal data_changed()

var olddata: DMobgroup # Remember what the value of the data was before editing

# The data that represents this mobgroup
# The data is selected from the Gamedata.mobgroups
# based on the ID that the user has selected in the content editor
var dmobgroup: DMobgroup = null:
	set(value):
		dmobgroup = value
		load_mobgroup_data()
		mobgroupSelector.sprites_collection = Gamedata.mobgroups.sprites
		olddata = DMobgroup.new(dmobgroup.get_data().duplicate(true))



# Forward drag-and-drop functionality to the attributesGridContainer
func _ready() -> void:
	mob_list.set_drag_forwarding(Callable(), _can_drop_mob_data, _drop_mob_data)


# This function updates the form based on the DMobgroup that has been loaded
func load_mobgroup_data() -> void:
	if mobgroupImageDisplay != null and dmobgroup.spriteid != "":
		mobgroupImageDisplay.texture = dmobgroup.sprite
		PathTextLabel.text = dmobgroup.spriteid
	if IDTextLabel != null:
		IDTextLabel.text = str(dmobgroup.id)
	if NameTextEdit != null:
		NameTextEdit.text = dmobgroup.name
	if DescriptionTextEdit != null:
		DescriptionTextEdit.text = dmobgroup.description
	update_mob_list()

# The editor is closed, destroy the instance
# TODO: Check for unsaved changes
func _on_close_button_button_up() -> void:
	queue_free()

# This function takes all data from the form elements and stores them in the DMobgroup instance
# Since dmobgroup is a reference to an item in Gamedata.mobgroups
# the central array for mobgroup data is updated with the changes as well
# The function will signal to Gamedata that the data has changed and needs to be saved
func _on_save_button_button_up() -> void:
	save_mob_list_to_dmobgroup()
	dmobgroup.spriteid = PathTextLabel.text
	dmobgroup.name = NameTextEdit.text
	dmobgroup.description = DescriptionTextEdit.text
	dmobgroup.sprite = mobgroupImageDisplay.texture
	dmobgroup.changed(olddata)
	data_changed.emit()
	olddata = DMobgroup.new(dmobgroup.get_data().duplicate(true))


# When the mobgroupImageDisplay is clicked, the user will be prompted to select an image from 
# "res://Mods/Core/Mobs/". The texture of the mobgroupImageDisplay will change to the selected image
func _on_mobgroup_image_display_gui_input(event) -> void:
	if event is InputEventMouseButton and event.pressed:
		mobgroupSelector.show()

func _on_sprite_selector_sprite_selected_ok(clicked_sprite) -> void:
	var mobgroupTexture: Resource = clicked_sprite.get_texture()
	mobgroupImageDisplay.texture = mobgroupTexture
	PathTextLabel.text = mobgroupTexture.resource_path.get_file()


# Refreshes the mob_list based on the dmobgroup data
func update_mob_list():
	# Clear all existing children in mob_list
	while mob_list.get_child_count() > 0:
		var child = mob_list.get_child(0)
		mob_list.remove_child(child)
		child.queue_free()
	
	add_header_row_to_mob_list()
	
	# Populate mob_list with data from dmobgroup.mobs
	for mob_id in dmobgroup.mobs.keys():
		var weight = dmobgroup.mobs[mob_id]
		add_mob_entry(mob_id, weight)


# Adds a new mob and its controls to the mob_list
func add_mob_entry(mob_id: String, weight: int):
	var mob_icon = TextureRect.new()
	var mob_sprite = Gamedata.mods.get_content_by_id(DMod.ContentType.MOBS,mob_id).sprite
	mob_icon.texture = mob_sprite
	mob_icon.custom_minimum_size = Vector2(16, 16)

	var mob_label = Label.new()
	mob_label.text = mob_id

	var weight_spinbox = SpinBox.new()
	weight_spinbox.min_value = 1
	weight_spinbox.max_value = 100
	weight_spinbox.value = weight
	weight_spinbox.step = 1
	weight_spinbox.tooltip_text = "Assign the weight for this mob (1 to 100)."

	var delete_button = Button.new()
	delete_button.text = "X"
	delete_button.button_up.connect(_on_delete_mob_button_pressed.bind(mob_id))

	# Add components to GridContainer
	mob_list.add_child(mob_icon)
	mob_list.add_child(mob_label)
	mob_list.add_child(weight_spinbox)
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
	
	# Remove mob from dmobgroup.mobs
	dmobgroup.mobs.erase(mob_id)


# Adds a header row to mob_list
func add_header_row_to_mob_list():
	var headers = ["Sprite", "Mob ID", "Weight", "Delete"]
	for header_text in headers:
		var header_label = Label.new()
		header_label.text = header_text
		header_label.set_horizontal_alignment(HORIZONTAL_ALIGNMENT_CENTER)
		mob_list.add_child(header_label)


# Checks if the dropped mob can be added to mob_list
# data: A dictionary like this:
#	{
#		"id": selected_item_id,
#		"text": selected_item_text,
#		"mod_id": mod_id,
#		"contentType": contentType
#	}
func _can_drop_mob_data(_newpos, data) -> bool:
	if not data or not data.has("id"):
		return false
	var mob_id = data["id"]
	return Gamedata.mods.by_id(data["mod_id"]).mobs.has_id(mob_id) and not dmobgroup.mobs.has(mob_id)


# Handles mob data being dropped
func _drop_mob_data(newpos, data) -> void:
	if _can_drop_mob_data(newpos, data):
		var mob_id = data["id"]
		dmobgroup.mobs[mob_id] = 1  # Default weight is 1
		add_mob_entry(mob_id, 1)


# Save the mob data from mob_list into dmobgroup
func save_mob_list_to_dmobgroup():
	var new_mobs = {}
	var num_columns = mob_list.columns
	var num_children = mob_list.get_child_count()
	
	for i in range(4, num_children, num_columns):  # Skip header
		var mob_id = mob_list.get_child(i + 1).text
		var weight = mob_list.get_child(i + 2).get_value()
		new_mobs[mob_id] = weight
	
	dmobgroup.mobs = new_mobs


func _on_mob_group_image_display_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		mobgroupSelector.show()
