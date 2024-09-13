extends Panel

@export var item_button_container : VBoxContainer

@export var description : Label
@export var required_items : VBoxContainer
@export var skill_progression_label : Label
@export var recipeVBoxContainer : VBoxContainer
@export var feedback_label : Label

@export var start_crafting_button : Button

@export var hud : NodePath

signal start_craft(item: Dictionary, recipe: Dictionary)

var active_recipe: DItem.CraftRecipe # The currently selected recipe
var active_item: DItem # The currently selected item in the itemlist
# Dictionary to store buttons with item IDs as keys
var item_buttons = {}

# Called when the node enters the scene tree for the first time.
func _ready():
	start_craft.connect(ItemManager.on_crafting_menu_start_craft)
	ItemManager.allAccessibleItems_changed.connect(_on_allAccessibleItems_changed)
	Helper.signal_broker.player_skill_changed.connect(_on_player_skill_changed)
	ItemManager.craft_successful.connect(_on_craft_successful)
	ItemManager.craft_failed.connect(_on_craft_failed)
	create_item_buttons()


# Function to create item buttons based on craftable items
func create_item_buttons():
	for item: DItem in CraftingRecipesManager.craftable_items:
		if can_craft_with_skill(item):
			create_item_button(item)


# Updated function to store button references
func create_item_button(item: DItem):
	var button = Button.new()
	button.icon = item.sprite
	button.text = item.name
	button.button_up.connect(_on_item_button_clicked.bind(item))

	# Initially set the button color based on craftability
	update_button_color(button, item)

	item_button_container.add_child(button)
	# Store the button reference keyed by item's ID
	item_buttons[item.id] = button


# Function to update a button's color based on the item's craftability
func update_button_color(button, item: DItem):
	if can_craft_any_recipe(item):
		button.modulate = Color(0.4, 1, 0.4)  # Green for craftable
	else:
		button.modulate = Color(1, 0.4, 0.4)  # Red for not craftable


# The user has clicked on one of the item buttons in the itemlist
# Update the list of recipes for this item
func _on_item_button_clicked(item: DItem):
	active_item = item
	description.text = item["description"]  # Set the description label
	var recipes = item.craft.recipes  # Get the recipe array from the item
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
func _on_recipe_button_pressed(recipe: DItem.CraftRecipe):
	active_recipe = recipe
	update_required_items_display(recipe)
	
	# Display skill progression information if it exists
	if recipe.skill_progression:
		var skill_id = recipe.skill_progression.id
		var skill_xp = recipe.skill_progression.xp
		if skill_id and skill_xp:
			skill_progression_label.text = "Get XP: %s: %s" % [skill_id, skill_xp]
		else:
			skill_progression_label.text = ""
	else:
		skill_progression_label.text = ""
	
	# Enable or disable the start crafting button based on whether the player can craft
	start_crafting_button.disabled = not CraftingRecipesManager.can_craft_recipe(recipe)


# New function to update required items display
func update_required_items_display(recipe: DItem.CraftRecipe):
	# Clear previous required items display
	for element in required_items.get_children():
		element.queue_free()  # Properly free the node to avoid memory leaks

	for resource in recipe.required_resources:
		var item_id = resource["id"]
		var required_amount = resource["amount"]
		var current_amount = ItemManager.get_accessibleitem_amount(item_id)

		var resource_container = HBoxContainer.new()
		required_items.add_child(resource_container)

		var item_icon_texture = Gamedata.items.sprite_by_id(item_id)
		if item_icon_texture:
			var icon = TextureRect.new()
			icon.texture = item_icon_texture
			icon.custom_minimum_size = Vector2(32, 32)  # Set a fixed size for icons
			resource_container.add_child(icon)

		var item_name: String = Gamedata.items.by_id(item_id).name

		var label = Label.new()

		# Check if the player has enough of the resource
		if current_amount < required_amount:
			var missing_amount = required_amount - current_amount
			label.text = " %s: %d/%d (Missing %d)" % [item_name, current_amount, required_amount, missing_amount]
			label.modulate = Color.RED  # Set the text color
		else:
			label.text = " %s: %d/%d" % [item_name, current_amount, required_amount]
			label.modulate = Color.GREEN  # Set the text color

		resource_container.add_child(label)


# The user has pressed the start crafting button
func _on_start_crafting_button_pressed():
	start_craft.emit(active_item, active_recipe)


# Function to determine if any of the item's recipes can be crafted
func can_craft_any_recipe(item: DItem) -> bool:
	# Iterate over each recipe in the 'Craft' property
	for recipe in item.craft.recipes:
		# Call the CraftingRecipesManager to check if the recipe can be crafted
		if CraftingRecipesManager.can_craft_recipe(recipe):
			return true  # Return true if any recipe can be crafted
	# Return false if no recipes can be crafted or if there are no recipes
	return false


# Function to update the color of the button associated with a given item data
func update_item_button_color(item: DItem) -> void:
	if item.id in item_buttons:
		var button = item_buttons[item.id]
		update_button_color(button, item)


# Some inventory item has been moved or changed. Now we want to update the UI so that
# the player knows what items can be crafted based on the new inventory contents
# We could update all of the recipes, but we only need to update recipes that
# reference the item that was added/moved/removed. Therefore,
# - We get the item references from the inventory item
# - For each item reference, update the button that represents the item in the ui
func _update_button_from_inventory_item(item: InventoryItem) -> void:
	var ditem: DItem = Gamedata.items.by_id(item.get("prototype_id"))
	var item_references = Helper.json_helper.get_nested_data(ditem.references, "core.items")
	if item_references:
		for item_reference: String in item_references:
			var ditem_reference: DItem = Gamedata.items.by_id(item_reference)
			update_item_button_color(ditem_reference)


func _on_allAccessibleItems_changed(items_added: Array, items_removed: Array):
	# Update buttons for items that were added
	for item in items_added:
		_update_button_from_inventory_item(item)

	# Update buttons for items that were removed
	for item in items_removed:
		_update_button_from_inventory_item(item)

	# Check if the crafting menu is open and a recipe is selected
	if self.visible and active_recipe != null:
		# Refresh the display as though the recipe button was pressed
		_on_recipe_button_pressed(active_recipe)


# Function to determine if any of the item's recipes can be crafted based on player's skills
func can_craft_with_skill(item: DItem) -> bool:
	# Iterate over each recipe in the 'Craft' property
	for recipe in item.craft.recipes:
		# Call the CraftingRecipesManager to check if the recipe can be crafted
		if CraftingRecipesManager.has_required_skill(recipe):
			return true  # Return true if any recipe can be crafted based on skills
	# Return false if no recipes can be crafted or if there are no recipes
	return false


# Function to clear all item buttons from the item_button_container
func clear_item_buttons():
	for button in item_button_container.get_children():
		item_button_container.remove_child(button)
		button.queue_free()  # Properly free the node to avoid memory leaks
	item_buttons.clear()  # Clear the item_buttons dictionary


# Function to clear and refresh the item buttons
func refresh_item_buttons():
	clear_item_buttons()
	create_item_buttons()


# The player's skill has changed so new recipes might be unlocked. Refresh the list
func _on_player_skill_changed(_playernode: CharacterBody3D):
	refresh_item_buttons()


# Function to display feedback message temporarily
func display_feedback(message: String, color: Color):
	feedback_label.text = message
	feedback_label.modulate = color  # Set the text color
	feedback_label.visible = true
	
	# Create a timer to hide the feedback label after 0.5 seconds
	var timer = Timer.new()
	timer.wait_time = 0.5
	timer.one_shot = true
	timer.timeout.connect(func():
		feedback_label.visible = false
		timer.queue_free()  # Properly free the timer node
	)
	add_child(timer)  # Add the timer to the scene tree
	timer.start()


func _on_craft_successful(_item: DItem, _recipe: DItem.CraftRecipe):
	var color = Color(0.4, 1, 0.4)  # Brighter green color with more white
	display_feedback("craft succesful!", color)


func _on_craft_failed(_item: DItem, _recipe: DItem.CraftRecipe, reason: String):
	var color = Color(1, 0, 0)  # Red color
	display_feedback(reason, color)
