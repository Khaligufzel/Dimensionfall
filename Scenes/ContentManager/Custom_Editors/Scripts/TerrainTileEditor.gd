extends Control

# This scene is intended to be used inside the content editor
# It is supposed to edit exactly one tile
# It expects to save the data to a JSON file that contains all tile data from a mod
# To load data, provide the name of the tile data file and an ID

@export var tileImageDisplay: TextureRect = null
@export var IDTextLabel: Label = null
@export var NameTextEdit: TextEdit = null
@export var DescriptionTextEdit: TextEdit = null
@export var CategoriesList: Control = null
@export var tileSelector: Popup = null
@export var imageNameStringLabel: Label = null
@export var cubeShapeCheckbox: Button = null
@export var slopeShapeCheckbox: Button = null

signal data_changed()

var olddata: DTile # Remember what the value of the data was before editing
var control_elements: Array = []
# The data that represents this tile
# The data is selected from the Gamedata.mods.by_id("Core").tiles array
# based on the ID that the user has selected in the content editor
var dtile: DTile = null:
	set(value):
		dtile = value
		load_tile_data()
		tileSelector.sprites_collection = Gamedata.mods.by_id("Core").tiles.sprites
		olddata = DTile.new(dtile.get_data().duplicate(true), null)


func _ready():
	control_elements = [
		tileImageDisplay,
		NameTextEdit,
		DescriptionTextEdit,
		CategoriesList,
		cubeShapeCheckbox,
		slopeShapeCheckbox
	]

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

# This function updates the form based on the dtile that has been loaded
func load_tile_data():
	if tileImageDisplay != null and dtile.spriteid:
		var myTexture: Resource = Gamedata.mods.by_id("Core").tiles.sprite_by_file(dtile.spriteid)
		tileImageDisplay.texture = myTexture
		imageNameStringLabel.text = dtile.spriteid
	if IDTextLabel != null:
		IDTextLabel.text = str(dtile.id)
	if NameTextEdit != null:
		NameTextEdit.text = dtile.name
	if DescriptionTextEdit != null:
		DescriptionTextEdit.text = dtile.description
	if CategoriesList != null:
		CategoriesList.clear_list()
		for category in dtile.categories:
			CategoriesList.add_item_to_list(category)
	if cubeShapeCheckbox != null and dtile.shape:
		# By default the cubeShapeCheckbox is selected so we only account for slope
		if dtile.shape == "slope":
			cubeShapeCheckbox.button_pressed = false
			slopeShapeCheckbox.button_pressed = true

# The editor is closed, destroy the instance
# TODO: Check for unsaved changes
func _on_close_button_button_up():
	queue_free()

# This function takes all data from the form elements and stores them in dtile
# Since dtile is a reference to an item in Gamedata.mods.by_id("Core").tiles
# the central array for tile data is updated with the changes as well
# The function will signal to Gamedata that the data has changed and needs to be saved
func _on_save_button_button_up():
	dtile.spriteid = imageNameStringLabel.text
	dtile.sprite = tileImageDisplay.texture
	dtile.name = NameTextEdit.text
	dtile.description = DescriptionTextEdit.text
	dtile.categories = CategoriesList.get_items()
	dtile.shape = "cube"
	if slopeShapeCheckbox.button_pressed:
		dtile.shape = "slope"
	dtile.changed(olddata)
	data_changed.emit()
	olddata = DTile.new(dtile.get_data().duplicate(true), null)

# When the tileImageDisplay is clicked, the user will be prompted to select an image from
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
