extends Control

@export var contentList: PackedScene = null
@export var mapEditor: PackedScene = null
@export var tacticalmapEditor: PackedScene = null
@export var terrainTileEditor: PackedScene = null
@export var furnitureEditor: PackedScene = null
@export var itemEditor: PackedScene = null
@export var mobEditor: PackedScene = null
@export var itemgroupEditor: PackedScene = null
@export var wearableslotEditor: PackedScene = null
@export var statsEditor: PackedScene = null
@export var skillsEditor: PackedScene = null
@export var content: VBoxContainer = null
@export var tabContainer: TabContainer = null
var selectedMod: String = "Core"


#This function will load the contents of the data into the ontentListInstance
func _ready():
	load_content_list(Gamedata.data.tacticalmaps, "Tactical Maps")
	load_content_list(Gamedata.data.maps, "Maps")
	load_content_list(Gamedata.data.items, "Items")
	load_content_list(Gamedata.data.tiles, "Terrain Tiles")
	load_content_list(Gamedata.data.mobs, "Mobs")
	load_content_list(Gamedata.data.furniture, "Furniture")
	load_content_list(Gamedata.data.itemgroups, "Item Groups")
	load_content_list(Gamedata.data.wearableslots, "Wearable slots")
	load_content_list(Gamedata.data.stats, "Stats")
	load_content_list(Gamedata.data.skills, "Skills")


func load_content_list(data: Dictionary, strHeader: String):
	# Instantiate a contentlist
	var contentListInstance: Control = contentList.instantiate()

	# Set the source property
	contentListInstance.header = strHeader
	contentListInstance.contentData = data
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
	if data == Gamedata.data.items:
		instantiate_editor(data, itemID, itemEditor)
	if data == Gamedata.data.mobs:
		instantiate_editor(data, itemID, mobEditor)
	if data == Gamedata.data.maps:
		instantiate_editor(data, itemID, mapEditor)
	if data == Gamedata.data.tacticalmaps:
		instantiate_editor(data, itemID, tacticalmapEditor)
	if data == Gamedata.data.itemgroups:
		instantiate_editor(data, itemID, itemgroupEditor)
	if data == Gamedata.data.wearableslots:
		instantiate_editor(data, itemID, wearableslotEditor)
	if data == Gamedata.data.stats:
		instantiate_editor(data, itemID, statsEditor)
	if data == Gamedata.data.skills:
		instantiate_editor(data, itemID, skillsEditor)


#This will add an editor to the content editor tab view. 
#The editor that should be instantiated is passed trough in the newEditor parameter
#It is important that the editor has the property contentSource or contentData so it can be set
func instantiate_editor(data: Dictionary, itemID: String, newEditor: PackedScene):
	var newContentEditor: Control = newEditor.instantiate()
	newContentEditor.name = itemID
	tabContainer.add_child(newContentEditor)
	tabContainer.current_tab = tabContainer.get_child_count()-1
	if data.dataPath.ends_with(".json"):
		var itemdata: Dictionary = data.data[Gamedata.get_array_index_by_id(data,itemID)]
		#We only pass the data for the specific id to the editor
		newContentEditor.contentData = itemdata
		newContentEditor.data_changed.connect(_on_editor_data_changed)
	else:
		#If the data source does not end with json, it's a directory
		#So now we pass in the file we want the editor to edit
		newContentEditor.contentSource = data.dataPath + itemID + ".json"


# The content_list that had it's data changed refreshes
func _on_editor_data_changed(data: Dictionary, _newdata: Dictionary, _olddata: Dictionary):
	# Loop over each of the contentlists. Only the list that matches
	# the data will refresh
	for element in content.get_children():
		if element.contentData == data:
			element.load_data()
