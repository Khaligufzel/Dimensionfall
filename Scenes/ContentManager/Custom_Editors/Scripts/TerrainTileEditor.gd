extends Control

#This scene is intended to be used inside the content editor
#It is supposed to edit exactly one tile
#It expects to save the data to a JSON file that contains all tile data from a mod
#To load data, provide the name of the tile data file and an ID


@onready var tileBrush: PackedScene = preload("res://Scenes/ContentManager/Mapeditor/tilebrush.tscn")

@export var tileImageDisplay: TextureRect = null
@export var IDTextEdit: TextEdit = null
@export var NameTextEdit: TextEdit = null
@export var DescriptionTextEdit: TextEdit = null
@export var CategoriesList: Control = null
@export var tileSelector: Popup = null
@export var tileBrushList: HFlowContainer = null
@export var tilePathStringLabel: Label = null

#The JSON file to be edited
var contentSource: String = "":
	set(value):
		contentSource = value
		load_tile_data()
		load_Brush_List()

#This function will find an item in the contentSource JSOn file with an iD that is equal to self.name
#If an item is found, it will set all the elements in the editor with the corresponding values
func load_tile_data():
	if not FileAccess.file_exists(contentSource):
		return

	var file = FileAccess.open(contentSource, FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text())
	file.close()

	for item in data:
		if item["id"] == self.name:
			if tileImageDisplay != null and item.has("imagePath"):
				tileImageDisplay.texture = load(item["imagePath"])
				tilePathStringLabel.text = item["imagePath"]
			if IDTextEdit != null:
				IDTextEdit.text = str(item["id"])
			if NameTextEdit != null and item.has("name"):
				NameTextEdit.text = item["name"]
			if DescriptionTextEdit != null and item.has("description"):
				DescriptionTextEdit.text = item["description"]
			if CategoriesList != null and item.has("categories"):
				CategoriesList.clear_list()
				for category in item["categories"]:
					CategoriesList.add_item_to_list(category)
			break
	

#The editor is closed, destroy the instance
#TODO: Check for unsaved changes
func _on_close_button_button_up():
	queue_free()

#This function takes all data fro the form elements and writes it to the contentSource JSON file.
func _on_save_button_button_up():
	var file = FileAccess.open(contentSource, FileAccess.READ_WRITE)
	var data = JSON.parse_string(file.get_as_text())
	file.close()

	for item in data:
		if item["id"] == IDTextEdit.text:
			item["imagePath"] = tileImageDisplay.texture.resource_path
			item["name"] = NameTextEdit.text
			item["description"] = DescriptionTextEdit.text
			item["categories"] = CategoriesList.get_items()
			break

	file = FileAccess.open(contentSource, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()


#When the tileImageDisplay is clicked, the user will be prompted to select an image from 
# "res://Mods/Core/Tiles/". The texture of the tileImageDisplay will change to the selected image
func _on_tile_image_display_gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		tileSelector.show()


# this function will read all files in "res://Mods/Core/Tiles/" and for each file it will create a texturerect and assign the file as the texture of the texturerect. Then it will add the texturerect as a child to $HSplitContainer/EntitiesContainer/TilesList
func load_Brush_List():
	var tilesDir = "res://Mods/Core/Tiles/"
	
	var dir = DirAccess.open(tilesDir)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			var extension = file_name.get_extension()

			if !dir.current_is_dir():
				if extension == "png":
					# Create a TextureRect node
					var brushInstance = tileBrush.instantiate()

					# Load the texture from file
					var texture: Resource = load(tilesDir + file_name)

					# Assign the texture to the TextureRect
					brushInstance.set_tile_texture(texture)
					brushInstance.set_meta("path", tilesDir + file_name)
					brushInstance.tilebrush_clicked.connect(tilebrush_clicked)

					# Add the TextureRect as a child to the TilesList
					tileBrushList.add_child(brushInstance)
			file_name = dir.get_next()
	else:
		print_debug("An error occurred when trying to access the path.")
	dir.list_dir_end()

#Called after the user selects a tile in the popup textbox and presses OK
func _on_ok_button_up():
	tileSelector.hide()
	var children = tileBrushList.get_children()
	for child in children:
		if child.selected:
			tileImageDisplay.texture = load(child.get_meta("path"))
			tilePathStringLabel.text = child.get_meta("path")
			
#Called after the users presses cancel on the popup asking for a tile
func _on_cancel_button_up():
	tileSelector.hide()
	
func deselect_all_brushes():
	var children = tileBrushList.get_children()
	for child in children:
		child.set_selected(false)

#Mark the clicked tilebrush as selected, but only after deselecting all other brushes
func tilebrush_clicked(tilebrush: Control) -> void:
	deselect_all_brushes()
	# If the clicked brush was not select it, we select it. Otherwise we deselect it
	tilebrush.set_selected(true)
