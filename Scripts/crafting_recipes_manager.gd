extends Node

var craftable_items


# Called when the node enters the scene tree for the first time.
func _ready():
	get_crafting_recipes_from_json()

func get_crafting_recipes_from_json():
	craftable_items = Gamedata.get_items_by_type("Craft")


# Function to check if there are enough resources in the inventory to craft a given recipe.
func can_craft_recipe(recipe: Dictionary) -> bool:
	# Ensure that the recipe contains the 'required_resources' key.
	if "required_resources" in recipe:
		# Loop through each resource required by the recipe.
		for resource in recipe["required_resources"]:
			# Check if the inventory has a sufficient amount of each required resource.
			if not ItemManager.has_sufficient_item_amount(resource.get("id"), resource.get("amount")):
				return false  # Return false immediately if any resource is insufficient.
	else:
		print_debug("No required resources specified for recipe")
		return false  # Return false if the recipe does not specify any required resources.
	
	# If all checks are passed, return true indicating that crafting can proceed.
	return true
