extends Panel

@export var item_button_container : VBoxContainer
@export var item_craft_button : PackedScene

@export var description : Label
@export var required_items : VBoxContainer
@export var recipeVBoxContainer : VBoxContainer

@export var start_crafting_button : Button

@export var hud : NodePath

signal start_craft(item: Dictionary, recipe: Dictionary)


var active_recipe: Dictionary # The currently selected recipe
var active_item: Dictionary # THe currently selected item in the itemlist


# Called when the node enters the scene tree for the first time.
func _ready():
	start_craft.connect(ItemManager.on_crafting_menu_start_craft)
	for item: Dictionary in CraftingRecipesManager.craftable_items:
		active_item = item
		var button = Button.new()
		var button_icon = Gamedata.get_sprite_by_id(Gamedata.data.items, item.get("id"))
		if button_icon:
			button.icon = button_icon
		item_button_container.add_child(button)
		button.text = item["name"]
		button.button_up.connect(_on_item_button_clicked.bind(item))


# The user has clicked on one of the item buttons in the itemlist
# Update the list of recipes for this item
func _on_item_button_clicked(item: Dictionary):
	active_item = item
	description.text = item["description"]  # Set the description label
	var recipes = item.get("Craft",[])             # Get the recipe array from the item
	for element in recipeVBoxContainer.get_children():
		recipeVBoxContainer.remove_child(element)
		element.queue_free()  # Properly free the node to avoid memory leaks

	for i in range(recipes.size()):
		var recipe_button = Button.new()
		recipe_button.text = "Recipe %d" % (i + 1)
		recipeVBoxContainer.add_child(recipe_button)
		recipe_button.button_up.connect(_on_recipe_button_pressed.bind(recipes[i]))

	if recipes.size() > 0:
		_on_recipe_button_pressed(recipes[0])  # Automatically select the first recipe


# When a recipe button is pressed, update the required items label
func _on_recipe_button_pressed(recipe):
	active_recipe = recipe
	for element in required_items.get_children():
		required_items.remove_child(element)
		element.queue_free()  # Properly free the node to avoid memory leaks

	for resource in recipe.get("required_resources", []):
		var item_id = resource["id"]
		var amount = resource["amount"]
		var resource_container = HBoxContainer.new()
		var item_data = Gamedata.get_data_by_id(Gamedata.data.items,item_id)
		var item_name: String = item_data["name"]
		required_items.add_child(resource_container)

		var item_icon_texture = Gamedata.get_sprite_by_id(Gamedata.data.items, item_id)
		if item_icon_texture:
			var icon = TextureRect.new()
			icon.texture = item_icon_texture
			icon.custom_minimum_size = Vector2(32, 32)  # Set a fixed size for icons
			resource_container.add_child(icon)

		var label = Label.new()
		label.text = " %s: %d" % [item_name, amount]
		resource_container.add_child(label)


func _on_start_crafting_button_pressed():
	start_craft.emit(active_item, active_recipe)
