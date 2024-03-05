extends Control

@export var contentList: PackedScene = null
@export var mapEditor: PackedScene = null
@export var tacticalmapEditor: PackedScene = null
@export var terrainTileEditor: PackedScene = null
@export var furnitureEditor: PackedScene = null
@export var mobEditor: PackedScene = null
@export var content: VBoxContainer = null
@export var tabContainer: TabContainer = null
var selectedMod: String = "Core"

# Called when the node enters the scene tree for the first time.
#This function will instatiate a tileScene, set the source property and add it as a child to the content VBoxContainer. The source property should be set to "./Mods/Core/Maps/"
func _ready():
	load_content_list(Gamedata.data.tacticalmaps, "Tactical Maps")
	load_content_list(Gamedata.data.maps, "Maps")
	load_content_list(Gamedata.data.tiles, "Terrain Tiles")
	load_content_list(Gamedata.data.mobs, "Mobs")
	load_content_list(Gamedata.data.furniture, "Furniture")

func load_content_list(data: Dictionary, strHeader: String):
	# Instantiate a contentlist
	var contentListInstance: Control = contentList.instantiate()

	# Set the source property
	contentListInstance.contentData = data
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
func _on_content_item_activated(data: Dictionary, itemID: String):
	if data.is_empty() or itemID == "":
		print_debug("Tried to load the selected contentitem, but either \
		data (Array) or itemID ("+itemID+") is empty")
		return
	if data == Gamedata.data.tiles:
		instantiate_editor(data, itemID, terrainTileEditor)
	if data == Gamedata.data.furniture:
		instantiate_editor(data, itemID, furnitureEditor)
	if data == Gamedata.data.mobs:
		instantiate_editor(data, itemID, mobEditor)
	if data == Gamedata.data.maps:
		instantiate_editor(data, itemID, mapEditor)
	if data == Gamedata.data.tacticalmaps:
		instantiate_editor(data, itemID, tacticalmapEditor)

#This will add an editor to the content editor tab view. 
#The editor that should be instantiated is passed trough in the newEditor parameter
#It is important that the editor has the property contentSource or contentData so it can be set
func instantiate_editor(data: Dictionary, itemID: String, newEditor: PackedScene):
	var newContentEditor: Control = newEditor.instantiate()
	newContentEditor.name = itemID
	tabContainer.add_child(newContentEditor)
	tabContainer.current_tab = tabContainer.get_child_count()-1
	if data.dataPath.ends_with(".json"):
		#We only pass the data for the specific id to the editor
		newContentEditor.contentData = data.data[Gamedata.get_array_index_by_id(data,itemID)]
		#Connect the data_changed signal to the Gamedata.on_data_changed function
		#We pass trough the data collection that the changed data belongs to
		newContentEditor.data_changed.connect(Gamedata.on_data_changed.bind(data))
	else:
		#If the data source does not end with json, it's a directory
		#So now we pass in the file we want the editor to edit
		newContentEditor.contentSource = data.dataPath + itemID + ".json"
