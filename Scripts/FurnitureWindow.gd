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
			furniture_container_view.set_inventory(furniture_instance.get_inventory())

# Called when the node enters the scene tree for the first time.
func _ready():
	Helper.signal_broker.furniture_interacted.connect(_on_furniture_interacted)
	Helper.signal_broker.container_exited_proximity.connect(_on_container_exited_proximity)

# Some furniture has been interacted with. We will show this window
func _on_furniture_interacted(new_furniture_instance: FurnitureStaticSrv):
	furniture_instance = new_furniture_instance
	self.show()

# Some furniture has left proximity. If it's the currently interacted furniture, we hide the window
func _on_container_exited_proximity(exited_furniture_instance: FurnitureStaticSrv):
	if exited_furniture_instance == furniture_instance:
		furniture_instance = null
		self.hide()

# The user has pressed the close window button
func _on_close_menu_button_button_up() -> void:
	furniture_instance = null
	self.hide()
