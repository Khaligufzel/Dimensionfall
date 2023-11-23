extends Control

@onready var contentList: PackedScene = preload("res://Scenes/ContentManager/content_list.tscn")
@onready var mapEditor: PackedScene = preload("res://Scenes/ContentManager/Mapeditor/mapeditor.tscn")
var selectedMod: String = "Core"

@export var content: VBoxContainer = null
@export var tabContainer: TabContainer = null

# Called when the node enters the scene tree for the first time.
#This function will instatiate a tileScene, set the source property and add it as a child to the content VBoxContainer. The source property should be set to "./Mods/Core/Maps/"
func _ready():
	# Instantiate a tileScene
	var contentListInstance: Control = contentList.instantiate()

	# Set the source property
	contentListInstance.source = "./Mods/Core/Maps/"
	contentListInstance.header = "Maps"
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
func _on_content_item_activated(strSource: String, itemID: String):
	if strSource == "" or itemID == "":
		print_debug("Tried to load the selected contentitem, but either strSource ("+strSource+")\
		 or itemID ("+itemID+") is empty")
		return
	if strSource.ends_with(".json"):
		print_debug("There should be code here to load the item from a json file")
	else:
		var newMapEditor: Control = mapEditor.instantiate()
		newMapEditor.name = itemID
		tabContainer.add_child(newMapEditor)
		newMapEditor.mapSource = strSource + itemID + ".json"
