extends Control

#This scene is intended to be used inside the content editor
#It is supposed to edit exactly one item
#It expects to save the data to a DItem instance that contains all data from an item
#To load data, provide the DItem instance


@export var tab_container: TabContainer = null

# Used to open the sprite selector popup
@export var itemImageDisplay: TextureRect = null
@export var IDTextLabel: Label = null

# To show the name of the sprite
@export var PathTextLabel: Label = null

# Name and description of the item
@export var NameTextEdit: TextEdit = null
@export var DescriptionTextEdit: TextEdit = null

#The actual sprite selector popup
@export var itemSelector: Popup = null

# Inventory propeties
@export var VolumeNumberBox: SpinBox = null
@export var WeightNumberBox: SpinBox = null
@export var StackSizeNumberBox: SpinBox = null
@export var MaxStackSizeNumberBox: SpinBox = null

@export var types_container: HFlowContainer = null
@export var TwoHandedCheckBox: CheckBox = null

@export var references_editor: Control = null



# This signal will be emitted when the user presses the save button
# This signal should alert Gamedata that the mob data array should be saved to disk
signal data_changed()

var olddata: DItem # Remember what the value of the data was before editing
# The data that represents this item
# based on the ID that the user has selected in the content editor
var ditem: DItem = null:
	set(value):
		if value:
			ditem = value
			load_item_data()
			itemSelector.sprites_collection = Gamedata.items.sprites
			olddata = DItem.new(ditem.get_data().duplicate(true))
		
func _ready():
	refresh_tab_visibility()


#This function update the form based on the contentData that has been loaded
func load_item_data() -> void:
	if itemImageDisplay != null and ditem.spriteid:
		itemImageDisplay.texture = Gamedata.items.sprite_by_file(ditem.spriteid)
		PathTextLabel.text = ditem.spriteid
	if IDTextLabel != null:
		IDTextLabel.text = str(ditem.id)
	if NameTextEdit != null:
		NameTextEdit.text = ditem.name
	if DescriptionTextEdit != null:
		DescriptionTextEdit.text = ditem.description
	if VolumeNumberBox != null:
		VolumeNumberBox.value = float(ditem.volume)
	if WeightNumberBox != null:
		WeightNumberBox.value = float(ditem.weight)
	if StackSizeNumberBox != null:
		StackSizeNumberBox.value = float(ditem.stack_size)
	if MaxStackSizeNumberBox != null:
		MaxStackSizeNumberBox.value = float(ditem.max_stack_size)
	if TwoHandedCheckBox != null:
		TwoHandedCheckBox.button_pressed = ditem.two_handed

	# Loop through types_container children to load additional properties and set button_pressed
	for i in range(types_container.get_child_count()):
		var child = types_container.get_child(i)
		if child is CheckBox:
			var tabIndex = get_tab_by_title(child.text)
			var tab = tab_container.get_child(tabIndex)
			if not ditem.get(child.text.to_lower()) == null:
				tab.ditem = ditem
				 # Set button_pressed to true if contentData has the property
				child.button_pressed = true 
	refresh_tab_visibility()
	references_editor.reference_data = ditem.references


#The editor is closed, destroy the instance
#TODO: Check for unsaved changes
func _on_close_button_button_up() -> void:
	queue_free()

# This function takes all data from the form elements and stores them in the ditem
# The central array for item data is updated with the changes as well
# The function will signal to Gamedata that the data has changed and needs to be saved
func _on_save_button_button_up() -> void:
	ditem.spriteid = PathTextLabel.text
	ditem.sprite = itemImageDisplay.texture
	# We add this image property only for the itemprotosets of gloot
	ditem.image = Gamedata.items.spritePath + PathTextLabel.text
	ditem.name = NameTextEdit.text
	ditem.description = DescriptionTextEdit.text
	ditem.volume = VolumeNumberBox.value
	ditem.weight = WeightNumberBox.value
	ditem.stack_size = int(StackSizeNumberBox.value)
	ditem.max_stack_size = int(MaxStackSizeNumberBox.value)
	ditem.two_handed = TwoHandedCheckBox.button_pressed
	
	# Loop through types_container children to save additional properties
	for i in range(types_container.get_child_count()):
		var child = types_container.get_child(i)
		# Check if the child is a CheckBox and its button_pressed is true
		if child is CheckBox:
			if child.button_pressed:
				# Save additional properties if checkbox is checked
				var tabIndex = get_tab_by_title(child.text)
				var tab = tab_container.get_child(tabIndex)
				if tab:
					tab.save_properties()
			else:
				# Delete the property if checkbox is not checked and it exists in contentData
				if not ditem.get(child.text.to_lower()) == null:
					ditem.set(child.text.to_lower(),null)
	ditem.changed(olddata)
	data_changed.emit()
	olddata = DItem.new(ditem.get_data().duplicate(true))


#When the itemImageDisplay is clicked, the user will be prompted to select an image from 
# "res://Mods/Core/items/". The texture of the itemImageDisplay will change to the selected image
func _on_item_image_display_gui_input(event) -> void:
	if event is InputEventMouseButton and event.pressed:
		itemSelector.show()


func _on_sprite_selector_sprite_selected_ok(clicked_sprite) -> void:
	var itemTexture: Resource = clicked_sprite.get_texture()
	itemImageDisplay.texture = itemTexture
	PathTextLabel.text = itemTexture.resource_path.get_file()


func _on_type_check_button_up():
	refresh_tab_visibility()

# This function loops over the checkboxes.
# It will show corresponding tabs in the tab container if the box is checked.
# It will hide the corresponding tabs in the tab container if the box is unchecked.
func refresh_tab_visibility() -> void:
	# Loop over all children of the types_container
	for i in range(types_container.get_child_count()):
		# Get the child node at index 'i'
		var child = types_container.get_child(i)
		# Check if the child is a CheckBox
		if child is CheckBox:
			# Find the tab index in the TabContainer with the same name as the checkbox text
			var tabIndex = get_tab_by_title(child.text)
			if tabIndex != -1:  # Check if a valid tab index is returned
				tab_container.set_tab_hidden(tabIndex, !child.button_pressed)
				var tab = tab_container.get_child(tabIndex)
				tab.ditem = ditem if child.button_pressed else null


# Returns the tab control with the given name
func get_tab_by_title(tabName: String) -> int:
	# Loop over all children of the types_container
	for i in range(tab_container.get_tab_count()):
		if tab_container.get_tab_title(i) == tabName:
			return i
	return -1
