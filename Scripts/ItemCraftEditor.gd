extends Control

# This scene is intended to be used inside the item editor
# It is supposed to edit exactly one craft recipe

@export var craftAmountNumber: SpinBox = null
@export var craftTimeNumber: SpinBox = null
@export var requiresLightCheckbox: CheckBox = null
@export var resourcesGridContainer: GridContainer = null
@export var recipesContainer: OptionButton = null  # Dropdown to select which recipe to edit
@export var required_skill_text_edit: HBoxContainer
@export var skill_level_requirement_spin_box: SpinBox
@export var skill_progression_text_edit: HBoxContainer
@export var skill_progression_spin_box: SpinBox


var current_recipe_index = 0
var craft_recipes: Array[DItem.CraftRecipe] = []
var controls_disabled: bool = false


var ditem: DItem = null:
	set(value):
		ditem = value
		load_properties()


func _ready():
	if recipesContainer.get_item_count() == 0:
		disable_all_controls()
	else:
		enable_all_controls()
	set_drop_functions()
	recipesContainer.item_selected.connect(_on_recipe_selected)


func _on_recipe_selected(index: int):
	if index != current_recipe_index:
		_update_current_recipe()  # Save any changes made to the current recipe
	current_recipe_index = index
	load_recipe_into_ui(craft_recipes[current_recipe_index])
	enable_all_controls()  # Ensure controls are enabled when a recipe is selected


# Loads a recipe into the UI elements
func load_recipe_into_ui(recipe: DItem.CraftRecipe):
	craftAmountNumber.value = recipe.craft_amount
	craftTimeNumber.value = recipe.craft_time
	requiresLightCheckbox.button_pressed = recipe.flags.get("requires_light", false)

	# Load skill requirements
	required_skill_text_edit.set_text(recipe.skill_requirement.get("id", ""))
	skill_level_requirement_spin_box.value = recipe.skill_requirement.get("level", 1)

	# Load skill progression
	skill_progression_text_edit.set_text(recipe.skill_progression.get("id", ""))
	skill_progression_spin_box.value = recipe.skill_progression.get("xp", 1)

	# Clear previous entries
	for child in resourcesGridContainer.get_children():
		child.queue_free()

	# Load resources from the selected recipe
	for resource in recipe.required_resources:
		add_resource_entry(resource["id"], resource["amount"])


# Gathers the properties from the UI for saving
func save_properties() -> void:
	# First update the current viewed recipe with UI values
	_update_current_recipe()

	# Replace all recipes in ditem.craft.recipes with the recipes in craft_recipes
	if ditem.craft:
		ditem.craft.recipes = craft_recipes.duplicate(true)
	else:
		ditem.craft = DItem.Craft.new([])
		ditem.craft.recipes = craft_recipes.duplicate(true)


# Updates the current recipe data based on UI elements
func _update_current_recipe():
	if current_recipe_index >= 0 and current_recipe_index < craft_recipes.size():
		var current_recipe = craft_recipes[current_recipe_index]
		current_recipe.craft_amount = craftAmountNumber.value
		current_recipe.craft_time = craftTimeNumber.value
		current_recipe.flags = {"requires_light": requiresLightCheckbox.button_pressed}
		current_recipe.required_resources = _get_resources_from_ui()

		# Add skill_requirement if required_skill_text_edit has a value
		var required_skill_id = required_skill_text_edit.get_text()
		if required_skill_id != "":
			current_recipe.skill_requirement = {
				"id": required_skill_id,
				"level": skill_level_requirement_spin_box.value
			}
		else:
			current_recipe.skill_requirement.clear()

		# Add skill_progression if skill_progression_text_edit has a value
		var skill_progression_id = skill_progression_text_edit.get_text()
		if skill_progression_id != "":
			current_recipe.skill_progression = {
				"id": skill_progression_id,
				"xp": skill_progression_spin_box.value
			}
		else:
			current_recipe.skill_progression.clear()


# Helper to get resources from UI
func _get_resources_from_ui() -> Array:
	var resources = []
	var children = resourcesGridContainer.get_children()
	for i in range(0, children.size(), 3): # Step by 3 to handle label-spinbox-deleteButton triples
		var label = children[i] as Label
		var spinBox = children[i + 1] as SpinBox
		resources.append({"id": label.text, "amount": spinBox.value})
	return resources


# Sets properties for all recipes and initializes the recipe editor
func load_properties():
	if not ditem or not ditem.craft:
		disable_all_controls()
		return
	
	craft_recipes.clear()
	for drecipe: DItem.CraftRecipe in ditem.craft.recipes:
		craft_recipes.append(DItem.CraftRecipe.new(drecipe.get_data().duplicate(true)))
	recipesContainer.clear()
	
	if craft_recipes.is_empty():
		add_new_recipe()  # Automatically add a new recipe if the list is empty
		load_recipe_into_ui(craft_recipes[0])
		enable_all_controls()  # Enable controls since a recipe was added
	else:
		for idx in range(len(craft_recipes)):
			recipesContainer.add_item("Recipe " + str(idx + 1))
		load_recipe_into_ui(craft_recipes[0])
		enable_all_controls()  # Enable controls since recipes exist


# Helper function to add a new recipe
func add_new_recipe():
	var new_recipe_data = {
		"craft_amount": 1,
		"craft_time": 10,
		"flags": {"requires_light": false},
		"skill_requirement": {"id": "", "level": 1},
		"skill_progression": {"id": "", "xp": 1},
		"required_resources": []
	}
	var new_recipe = DItem.CraftRecipe.new(new_recipe_data)
	craft_recipes.append(new_recipe)
	update_recipe_dropdown()


# This function should return true if the dragged data can be dropped here
func _can_drop_data(_newpos, data) -> bool:
	# If controls are disabled, disallow dropping
	if controls_disabled:
		return false
	
	# Check if the data dictionary has the 'id' property
	if not data or not data.has("id"):
		return false

	# Fetch item by ID from the Gamedata to ensure it exists and is valid
	if not Gamedata.items.has_id(data["id"]):
		return false

	# Check if the item ID already exists in the resources grid
	var children = resourcesGridContainer.get_children()
	for i in range(0, children.size(), 3):  # Step by 3 to handle label-spinbox-deleteButton triples
		var label = children[i] as Label
		if label.text == data["id"]:
			# Return false if this item ID already exists in the resources grid
			return false

	# If all checks pass, return true
	return true


# This function handles the data being dropped
func _drop_data(newpos, data) -> void:
	if _can_drop_data(newpos, data):
		_handle_item_drop(data, newpos)


# Called when the user has successfully dropped data onto the skillTextEdit
# We have to check the dropped_data for the id property
func _handle_item_drop(dropped_data, _newpos) -> void:
	# Dropped_data is a Dictionary that includes an 'id'
	if dropped_data and "id" in dropped_data:
		var item_id = dropped_data["id"]
		if not Gamedata.items.has_id(item_id):
			print_debug("No item data found for ID: " + item_id)
			return
		
		# Add the resource entry using the new function
		add_resource_entry(item_id, 1)
		# Check if the current recipe exists and update it directly
		if current_recipe_index >= 0 and current_recipe_index < craft_recipes.size():
			var current_recipe = craft_recipes[current_recipe_index]
			current_recipe["required_resources"].append({"id": item_id, "amount": 1})
	else:
		print_debug("Dropped data does not contain an 'id' key.")


# Deleting a resource UI element
func _delete_resource(elements_to_remove: Array) -> void:
	for element in elements_to_remove:
		resourcesGridContainer.remove_child(element)
		element.queue_free()  # Properly free the node to avoid memory leaks


func add_resource_entry(item_id: String, amount: int = 1):
	# Create UI elements for the resource
	var label = Label.new()
	label.text = item_id
	resourcesGridContainer.add_child(label)
	
	var amountSpinBox = SpinBox.new()
	amountSpinBox.value = amount
	resourcesGridContainer.add_child(amountSpinBox)
	
	var deleteButton = Button.new()
	deleteButton.text = "X"
	deleteButton.pressed.connect(_delete_resource.bind([label, amountSpinBox, deleteButton]))
	resourcesGridContainer.add_child(deleteButton)


# This editor becomes visible when the user checks the 'craft' checkbox in the main item editor
func _on_visibility_changed():
	load_properties()


func _on_add_recipe_button_button_up():
	_update_current_recipe()  # Save the changes to the currently selected recipe before adding a new one

	add_new_recipe()  # Add a new recipe

	# Update the dropdown and select the new recipe
	update_recipe_dropdown()
	current_recipe_index = craft_recipes.size() - 1  # Update the current index to the new recipe
	recipesContainer.select(current_recipe_index)  # Select the newly added recipe

	load_recipe_into_ui(craft_recipes[current_recipe_index])  # Load the newly added recipe into the UI

	enable_all_controls()  # Enable controls since a recipe was added



func _on_remove_recipe_button_button_up():
	if craft_recipes.size() > 1:  # Ensure there's more than one recipe to allow removal
		craft_recipes.remove_at(current_recipe_index)  # Corrected method call here
		update_recipe_dropdown()
		current_recipe_index = max(current_recipe_index - 1, 0)
		recipesContainer.select(current_recipe_index)  # Select the new current recipe
		load_recipe_into_ui(craft_recipes[current_recipe_index])
	else:
		print("Cannot remove the last recipe.")


# Helper function to update the recipe dropdown
func update_recipe_dropdown():
	recipesContainer.clear()
	for idx in range(len(craft_recipes)):
		recipesContainer.add_item("Recipe " + str(idx + 1))


# Called when the user has successfully dropped data onto the skillTextEdit
# We have to check the dropped_data for the id property
func skill_drop(dropped_data: Dictionary, texteditcontrol: HBoxContainer) -> void:
	# Assuming dropped_data is a Dictionary that includes an 'id'
	if dropped_data and "id" in dropped_data:
		var skill_id = dropped_data["id"]
		if not Gamedata.mods.by_id(dropped_data["mod_id"]).skills.has_id(skill_id):
			print_debug("No item data found for ID: " + skill_id)
			return
		texteditcontrol.set_text(skill_id)
	else:
		print_debug("Dropped data does not contain an 'id' key.")


func can_skill_drop(dropped_data: Dictionary):
	# Check if the data dictionary has the 'id' property
	if not dropped_data or not dropped_data.has("id"):
		return false
	
	# Fetch skill data by ID from the Gamedata to ensure it exists and is valid
	if not Gamedata.mods.by_id(dropped_data["mod_id"]).skills.has_id(dropped_data["id"]):
		return false

	# If all checks pass, return true
	return true


# Set the drop funcitons on the required skill and skill progression controls
# This enables them to receive drop data
func set_drop_functions():
	required_skill_text_edit.drop_function = skill_drop.bind(required_skill_text_edit)
	required_skill_text_edit.can_drop_function = can_skill_drop
	skill_progression_text_edit.drop_function = skill_drop.bind(skill_progression_text_edit)
	skill_progression_text_edit.can_drop_function = can_skill_drop


func disable_all_controls() -> void:
	controls_disabled = true  # Set the state to disabled
	# Disable specific controls
	required_skill_text_edit.disable()
	skill_progression_text_edit.disable()
	craftAmountNumber.editable = false
	craftTimeNumber.editable = false
	requiresLightCheckbox.disabled = true
	skill_level_requirement_spin_box.editable = false
	skill_progression_spin_box.editable = false


func enable_all_controls() -> void:
	controls_disabled = false  # Set the state to enabled
	# Enable specific controls
	required_skill_text_edit.enable()
	skill_progression_text_edit.enable()
	craftAmountNumber.editable = true
	craftTimeNumber.editable = true
	requiresLightCheckbox.disabled = false
	skill_level_requirement_spin_box.editable = true
	skill_progression_spin_box.editable = true
