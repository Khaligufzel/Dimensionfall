extends Control

# This script is used in the FurnitureWindow.tscn scene. 
# It supports the UI in controlling a StaticFurnitureSrv when the player interacts with it
# It shows the furniture details and if it's a crafting station, it allows for crafting


@export var furniture_container_view: Control = null
@export var furniture_namer_label: Label = null
@export var crafting_queue_container: GridContainer = null
@export var crafting_recipe_container: GridContainer = null

# The current furniture that the player is interacting with
var furniture_instance: FurnitureStaticSrv = null:
	set(value):
		if value:
			furniture_instance = value

# Called when the node enters the scene tree for the first time.
func _ready():
	pass
