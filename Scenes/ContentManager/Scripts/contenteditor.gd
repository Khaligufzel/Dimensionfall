extends Control

@onready var contentList: PackedScene = preload("res://Scenes/ContentManager/content_list.tscn")
var selectedMod: String = "Core"

@export var content: VBoxContainer = null

# Called when the node enters the scene tree for the first time.
#This function will instatiate a tileScene, set the source property and add it as a child to the content VBoxContainer. The source property should be set to "./Mods/Core/Maps/"
func _ready():
	# Instantiate a tileScene
	var contentListInstance = contentList.instantiate()

	# Set the source property
	contentListInstance.source = "./Mods/Core/Maps/"
	contentListInstance.header = "Maps"

	# Add it as a child to the content VBoxContainer
	content.add_child(contentListInstance)
