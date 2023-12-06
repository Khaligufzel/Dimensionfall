extends Panel

@export var button_container : NodePath
@export var item_craft_button : PackedScene

@export var button_group : ButtonGroup

@export var description : NodePath
@export var required_items : NodePath

@export var start_crafting_button : NodePath

@export var hud : NodePath

signal start_craft

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



func item_craft_button_clicked(recipe):
	active_recipe = recipe
	var recipe_id = recipe["id"]
	var item_to_craft
	for item in ItemManager.items:
		if item["id"] == recipe_id:
			item_to_craft = item
	
	get_node(description).text = item_to_craft["description"]
	
	var is_craft_possible = true
	
	for required_item in active_recipe["required_resource"]:
		get_node(required_items).text = required_item + ": " + str(active_recipe["required_resource"][required_item]) + "\n"
		
		if !get_node(hud).check_if_resources_are_available(required_item, int(active_recipe["required_resource"][required_item])):
			is_craft_possible = false
	
	if is_craft_possible:
		get_node(start_crafting_button).text = "Craft!"
		get_node(start_crafting_button).disabled = false
	else:
		get_node(start_crafting_button).text = "Not enough resources!"
		get_node(start_crafting_button).disabled = true
	


func _on_start_crafting_button_pressed():
	start_craft.emit(active_recipe)
