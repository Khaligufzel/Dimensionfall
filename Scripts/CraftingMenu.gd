extends Panel

@export var button_container : NodePath
@export var item_craft_button : PackedScene

@export var button_group : ButtonGroup

@export var description : NodePath
@export var required_items : NodePath

var active_recipe

var button_container_node

# Called when the node enters the scene tree for the first time.
func _ready():
	button_container_node = get_node(button_container)
	
	for recipe in CraftingRecipesManager.crafting_recipes:
		var button = item_craft_button.instantiate()
		button_container_node.add_child(button)
		button.text = recipe["name"]
		button.recipe = recipe
		button.button_group = button_group
		button.crafting_menu = [self]


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func item_craft_button_clicked(recipe):
	active_recipe = recipe
	var recipe_id = recipe["id"]
	#var items = ItemManager.items[recipe_id]
	var item_to_craft
	for item in ItemManager.items:
		if item["id"] == recipe_id:
			item_to_craft = item
	
	get_node(description).text = item_to_craft["description"]
	
	
	for required_item in active_recipe["required_resource"]:
		get_node(required_items).text = required_item + ": " + str(active_recipe["required_resource"][required_item]) + "\n"
