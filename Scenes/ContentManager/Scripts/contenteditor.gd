extends Control

@export var contentList: PackedScene = null
@export var mapEditor: PackedScene = null
@export var terrainTileEditor: PackedScene = null
@export var mobEditor: PackedScene = null
@export var content: VBoxContainer = null
@export var tabContainer: TabContainer = null
var selectedMod: String = "Core"

# Called when the node enters the scene tree for the first time.
#This function will instatiate a tileScene, set the source property and add it as a child to the content VBoxContainer. The source property should be set to "./Mods/Core/Maps/"
func _ready():
	load_content_list(Gamedata.all_map_files, "Maps")
	load_content_list(Gamedata.all_tiles, "Terrain Tiles")
	load_content_list(Gamedata.all_mobs, "Mobs")

func load_content_list(data: Array, strHeader: String):
	# Instantiate a contentlist
	var contentListInstance: Control = contentList.instantiate()

	# Set the source property
	contentListInstance.contentdata = data
	contentListInstance.header = strHeader
	contentListInstance.connect("item_activated", _on_content_item_activated)

	# Add it as a child to the content VBoxContainer
	content.add_child(contentListInstance)

func _on_back_button_button_up():
	get_tree().change_scene_to_file("res://Scenes/ContentManager/contentmanager.tscn")

#The user has doubleclicked or pressed enter on one of the items in the content lists
#Depending on wether the source is a JSON file, we are going to load the relevant content
#If strSource is a json file, we load an item from this file with the ID of itemText
#If the strSource is not a json file, we will assume it's a directory. 
#If it's a directory, we will load the entire json file with the name of the item ID
func _on_content_item_activated(data: Array, itemID: String):
	if data.is_empty() or itemID == "":
		print_debug("Tried to load the selected contentitem, but either \
		data (Array) or itemID ("+itemID+") is empty")
		return
	var strSource: String = Gamedata.get_data_directory(data)
	if data == Gamedata.all_tiles:
		instantiate_editor(strSource, itemID, terrainTileEditor)
	if data == Gamedata.all_mobs:
		instantiate_editor(strSource, itemID, mobEditor)
	if data == Gamedata.all_map_files:
		instantiate_editor(strSource + itemID + ".json", itemID, mapEditor)

#This will add an editor to the content editor tab view. 
#The editor that should be instantiated is passed trough in the newEditor parameter
#It is important that the editor has the property contentSource so it can be set
func instantiate_editor(strSource: String, itemID: String, newEditor: PackedScene):
	var newContentEditor: Control = newEditor.instantiate()
	newContentEditor.name = itemID
	tabContainer.add_child(newContentEditor)
	tabContainer.current_tab = tabContainer.get_child_count()-1
	newContentEditor.contentSource = strSource
