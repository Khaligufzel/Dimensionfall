extends Control

#This scene is intended to be used inside the content editor
#It is supposed to edit exactly one tile
#It expects to save the data to a JSON file that contains all tile data from a mod
#To load data, provide the name of the tile data file and an ID


@export var tileImageDisplay: TextureRect = null
@export var IDTextEdit: TextEdit = null
@export var NameTextEdit: TextEdit = null
@export var DescriptionTextEdit: TextEdit = null
@export var CategoriesList: Control = null

#The JSON file to be edited
var contentSource: String = "":
	set(value):
		contentSource = value
		load_tile_data()

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
