extends Control

#This scene is intended to be used inside the content editor
#It is supposed to edit exactly one item (friend and foe)
#It expects to save the data to a JSON file that contains all data from a mod
#To load data, provide the name of the item data file and an ID

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
@export var WidthNumberBox: SpinBox = null
@export var HeightNumberBox: SpinBox = null
@export var StackSizeNumberBox: SpinBox = null
@export var MaxStackSizeNumberBox: SpinBox = null

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

#This function update the form based on the contentData that has been loaded
func load_item_data() -> void:
	if itemImageDisplay != null and contentData.has("sprite"):
		itemImageDisplay.texture = Gamedata.data.items.sprites[contentData["sprite"]]
		PathTextLabel.text = contentData["sprite"]
	if IDTextLabel != null:
		IDTextLabel.text = str(contentData["id"])
	if NameTextEdit != null and contentData.has("name"):
		NameTextEdit.text = contentData["name"]
	if DescriptionTextEdit != null and contentData.has("description"):
		DescriptionTextEdit.text = contentData["description"]
	if WidthNumberBox != null and contentData.has("width"):
		WidthNumberBox.get_line_edit().text = contentData["width"]
	if HeightNumberBox != null and contentData.has("height"):
		HeightNumberBox.get_line_edit().text = contentData["height"]
	if StackSizeNumberBox != null and contentData.has("stack_size"):
		StackSizeNumberBox.get_line_edit().text = contentData["stack_size"]
	if MaxStackSizeNumberBox != null and contentData.has("max_stack_size"):
		MaxStackSizeNumberBox.get_line_edit().text = contentData["max_stack_size"]

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
	contentData["name"] = NameTextEdit.text
	contentData["description"] = DescriptionTextEdit.text
	contentData["width"] = WidthNumberBox.get_line_edit().text
	contentData["height"] = HeightNumberBox.get_line_edit().text
	contentData["stack_size"] = StackSizeNumberBox.get_line_edit().text
	contentData["max_stack_size"] = MaxStackSizeNumberBox.get_line_edit().text
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
