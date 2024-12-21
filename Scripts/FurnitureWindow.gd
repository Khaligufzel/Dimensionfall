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
			_populate_crafting_recipe_container()

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


# Retrieves the crafting time for a specific item by its ID
func _get_craft_time_by_id(item_id: String) -> float:
	var first_recipe: RItem.CraftRecipe = Runtimedata.items.get_first_recipe_by_id(item_id)
	return first_recipe.craft_time if first_recipe else 10.0  # Default to 10 seconds


# Adds an item to the crafting_recipe_container
func _add_item_to_crafting_recipe_container(item_id: String):
	# Get item details
	var ritem: RItem = Runtimedata.items.by_id(item_id)
	if not ritem:
		return
	
	var craft_time: float = _get_craft_time_by_id(item_id)
	
	# Create item container
	var item_container = HBoxContainer.new()
	
	# Create and add icon
	var icon = TextureRect.new()
	icon.texture = ritem.sprite
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	item_container.add_child(icon)
	
	# Create and add label
	var label = Label.new()
	label.text = ritem.name
	item_container.add_child(label)
	
	# Create and add button
	var queue_button = Button.new()
	queue_button.text = "Queue (Craft: %s sec)".format(craft_time)
	queue_button.button_up.connect(_on_queue_button_pressed.bind(item_id))
	item_container.add_child(queue_button)
	
	# Add the item container to the recipe container
	crafting_recipe_container.add_child(item_container)

# Populates the crafting_recipe_container with items from furniture_instance
func _populate_crafting_recipe_container():
	if not furniture_instance:
		return
	
	var crafting_items: Array[String] = furniture_instance.get_crafting_items()
	Helper.free_all_children(crafting_recipe_container)
	
	for item_id in crafting_items:
		_add_item_to_crafting_recipe_container(item_id)

# Callback for queue button pressed
func _on_queue_button_pressed(item_id: String):
	furniture_instance.add_to_crafting_queue(item_id)
