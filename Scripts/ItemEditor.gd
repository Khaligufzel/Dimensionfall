extends Control

#This scene is intended to be used inside the content editor
#It is supposed to edit exactly one item (friend and foe)
#It expects to save the data to a JSON file that contains all data from a mod
#To load data, provide the name of the item data file and an ID


@export var tabContainer: TabContainer = null

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

@export var typesContainer: HFlowContainer = null
@export var TwoHandedCheckBox: CheckBox = null



# This signal will be emitted when the user presses the save button
# This signal should alert Gamedata that the item data array should be saved to disk
# The content editor has connected this signal to Gamedata already
signal data_changed()

# The data that represents this item
# The data is selected from the Gamedata.data.items.data array
# based on the ID that the user has selected in the content editor
var contentData: Dictionary = {}:
	set(value):
		contentData = value
		load_item_data()
		itemSelector.sprites_collection = Gamedata.data.items.sprites
		
func _ready():
	refresh_tab_visibility()

#This function update the form based on the contentData that has been loaded
func load_item_data() -> void:
	if itemImageDisplay != null and contentData.has("sprite") and Gamedata.data.items.sprites.has(contentData["sprite"]):
		itemImageDisplay.texture = Gamedata.data.items.sprites[contentData["sprite"]]
		PathTextLabel.text = contentData["sprite"]
	if IDTextLabel != null:
		IDTextLabel.text = str(contentData["id"])
	if NameTextEdit != null and contentData.has("name"):
		NameTextEdit.text = contentData["name"]
	if DescriptionTextEdit != null and contentData.has("description"):
		DescriptionTextEdit.text = contentData["description"]
	if VolumeNumberBox != null and contentData.has("volume"):
		VolumeNumberBox.value = float(contentData["volume"])
	if WeightNumberBox != null and contentData.has("weight"):
		WeightNumberBox.value = float(contentData["weight"])
	if StackSizeNumberBox != null and contentData.has("stack_size"):
		StackSizeNumberBox.value = float(contentData["stack_size"])
	if MaxStackSizeNumberBox != null and contentData.has("max_stack_size"):
		MaxStackSizeNumberBox.value = float(contentData["max_stack_size"])
	if TwoHandedCheckBox != null and contentData.has("two_handed"):
		TwoHandedCheckBox.button_pressed = contentData["two_handed"]

	# Loop through typesContainer children to load additional properties and set button_pressed
	for i in range(typesContainer.get_child_count()):
		var child = typesContainer.get_child(i)
		if child is CheckBox:
			var tabIndex = get_tab_by_title(child.text)
			var tab = tabContainer.get_child(tabIndex)
			if tab and tab.has_method("set_properties") and contentData.has(child.text):
				tab.set_properties(contentData[child.text])
				 # Set button_pressed to true if contentData has the property
				child.button_pressed = true 
	refresh_tab_visibility()

#The editor is closed, destroy the instance
#TODO: Check for unsaved changes
func _on_close_button_button_up() -> void:
	queue_free()

# This function takes all data fro the form elements stores them in the contentData
# Since contentData is a reference to an item in Gamedata.data.items.data
# the central array for itemdata is updated with the changes as well
# The function will signal to Gamedata that the data has changed and needs to be saved
func _on_save_button_button_up() -> void:
	contentData["sprite"] = PathTextLabel.text
	# We add this image property only for the itemprotosets of gloot
	contentData["image"] = Gamedata.data.items.spritePath + PathTextLabel.text
	contentData["name"] = NameTextEdit.text
	contentData["description"] = DescriptionTextEdit.text
	contentData["volume"] = VolumeNumberBox.get_line_edit().text
	contentData["weight"] = WeightNumberBox.get_line_edit().text
	contentData["stack_size"] = StackSizeNumberBox.get_line_edit().text
	contentData["max_stack_size"] = MaxStackSizeNumberBox.get_line_edit().text
	contentData["two_handed"] = TwoHandedCheckBox.button_pressed
	
	# Loop through typesContainer children to save additional properties
	for i in range(typesContainer.get_child_count()):
		var child = typesContainer.get_child(i)
		# Check if the child is a CheckBox and its button_pressed is true
		if child is CheckBox and child.button_pressed:
			var tabIndex = get_tab_by_title(child.text)
			var tab = tabContainer.get_child(tabIndex)
			if tab and tab.has_method("get_properties"):
				contentData[child.text] = tab.get_properties()
	data_changed.emit()

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
	# Loop over all children of the typesContainer
	for i in range(typesContainer.get_child_count()):
		# Get the child node at index 'i'
		var child = typesContainer.get_child(i)
		# Check if the child is a CheckBox
		if child is CheckBox:
			# Find the tab index in the TabContainer with the same name as the checkbox text
			var tabIndex = get_tab_by_title(child.text)
			if tabIndex != -1:  # Check if a valid tab index is returned
				tabContainer.set_tab_hidden(tabIndex, !child.button_pressed)

# Returns the tab control with the given name
func get_tab_by_title(tabName: String) -> int:
	# Loop over all children of the typesContainer
	for i in range(tabContainer.get_tab_count()):
		if tabContainer.get_tab_title(i) == tabName:
			return i
	return -1
