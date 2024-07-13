extends Control

#This scene is intended to be used inside the content editor
#It is supposed to edit exactly one tile
#It expects to save the data to a JSON file that contains all tile data from a mod
#To load data, provide the name of the tile data file and an ID

@export var tileImageDisplay: TextureRect = null
@export var IDTextLabel: Label = null
@export var NameTextEdit: TextEdit = null
@export var DescriptionTextEdit: TextEdit = null
@export var CategoriesList: Control = null
@export var tileSelector: Popup = null
@export var imageNameStringLabel: Label = null
@export var cubeShapeCheckbox: Button = null
@export var slopeShapeCheckbox: Button = null
# This signal will be emitted when the user presses the save button
# This signal should alert Gamedata that the mob data array should be saved to disk
signal data_changed(game_data: Dictionary, new_data: Dictionary, old_data: Dictionary)

var olddata: Dictionary # Remember what the value of the data was before editing
var control_elements: Array = []
# The data that represents this tile
# The data is selected from the Gamedata.data.tiles.data array
# based on the ID that the user has selected in the content editor
var contentData: Dictionary = {}:
	set(value):
		contentData = value
		load_tile_data()
		tileSelector.sprites_collection = Gamedata.data.tiles.sprites
		olddata = contentData.duplicate(true)


func _ready():
	control_elements = [
		tileImageDisplay,
		NameTextEdit,
		DescriptionTextEdit,
		CategoriesList,
		cubeShapeCheckbox,
		slopeShapeCheckbox
	]
	data_changed.connect(Gamedata.on_data_changed)


func _input(event):
	if event.is_action_pressed("ui_focus_next"):
		for myControl in control_elements:
			if myControl.has_focus():
				if Input.is_key_pressed(KEY_SHIFT):  # Check if Shift key
					if !myControl.focus_previous.is_empty():
						myControl.get_node(myControl.focus_previous).grab_focus()
				else:
					if !myControl.focus_next.is_empty():
						myControl.get_node(myControl.focus_next).grab_focus()
				break
		get_viewport().set_input_as_handled()

# This function updates the form based on the contentData that has been loaded
func load_tile_data():
	if tileImageDisplay != null and contentData.has("sprite"):
		var myTexture: Resource = Gamedata.data.tiles.sprites[contentData["sprite"]]
		tileImageDisplay.texture = myTexture.albedo_texture
		imageNameStringLabel.text = contentData["sprite"]
	if IDTextLabel != null:
		IDTextLabel.text = str(contentData["id"])
	if NameTextEdit != null and contentData.has("name"):
		NameTextEdit.text = contentData["name"]
	if DescriptionTextEdit != null and contentData.has("description"):
		DescriptionTextEdit.text = contentData["description"]
	if CategoriesList != null and contentData.has("categories"):
		CategoriesList.clear_list()
		for category in contentData["categories"]:
			CategoriesList.add_item_to_list(category)
	if cubeShapeCheckbox != null and contentData.has("shape"):
		# By default the cubeShapeCheckbox is selected so we only account for slope
		if contentData["shape"] == "slope":
			cubeShapeCheckbox.button_pressed = false
			slopeShapeCheckbox.button_pressed = true


#The editor is closed, destroy the instance
#TODO: Check for unsaved changes
func _on_close_button_button_up():
	queue_free()
	
# This function takes all data fro the form elements stores them in the contentData
# Since contentData is a reference to an item in Gamedata.data.tiles.data
# the central array for tiledata is updated with the changes as well
# The function will signal to Gamedata that the data has changed and needs to be saved
func _on_save_button_button_up():
	contentData["sprite"] = imageNameStringLabel.text
	contentData["name"] = NameTextEdit.text
	contentData["description"] = DescriptionTextEdit.text
	contentData["categories"] = CategoriesList.get_items()
	contentData["shape"] = "cube"
	if slopeShapeCheckbox.button_pressed:
		contentData["shape"] = "slope"
	data_changed.emit(Gamedata.data.tiles, contentData, olddata)
	olddata = contentData.duplicate(true)

#When the tileImageDisplay is clicked, the user will be prompted to select an image from 
# "res://Mods/Core/Tiles/". The texture of the tileImageDisplay will change to the selected image
func _on_tile_image_display_gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		tileSelector.show()

func _on_sprite_selector_sprite_selected_ok(clicked_sprite) -> void:
	var tileTexture: Resource = clicked_sprite.get_texture()
	tileImageDisplay.texture = tileTexture
	imageNameStringLabel.text = tileTexture.resource_path.get_file()

# The tile can only be shaped like either a cube or a slope
# If the user clicks the cube shape button then only the cube shape
# button should be selected and no other shape buttons
# Having all shape buttons deselected should not happen.
func _on_cube_shape_check_box_button_up():
	slopeShapeCheckbox.button_pressed = false
	if !cubeShapeCheckbox.button_pressed:
		cubeShapeCheckbox.button_pressed = true

# The tile can only be shaped like either a cube or a slope
# If the user clicks the slope shape button then only the slope shape
# button should be selected and no other shape buttons.
# Having all shape buttons deselected should not happen.
func _on_slope_shape_check_box_button_up():
	cubeShapeCheckbox.button_pressed = false
	if !slopeShapeCheckbox.button_pressed:
		slopeShapeCheckbox.button_pressed = true
