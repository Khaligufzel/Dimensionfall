class_name RItem
extends RefCounted

# This class represents an item with its properties, only used while the game is running.
# Example item data:
# {
#     "id": "bullet_9mm",
#     "name": "9mm Bullet",
#     "description": "A standard 9mm caliber bullet.",
#     "weight": 0.01,
#     "volume": 0.002,
#     "stack_size": 50,
#     "max_stack_size": 200,
#     "sprite": "bullet_9mm.png",
#     "Craft": [
#         {
#             "craft_amount": 10,
#             "craft_time": 5,
#             "required_resources": [
#                 { "id": "steel_scrap", "amount": 1 }
#             ],
#             "skill_requirement": { "id": "fabrication", "level": 1 },
#             "skill_progression": { "id": "fabrication", "xp": 5 }
#         }
#     ]
# }

# Subclass to represent Craft recipes
class CraftRecipe:
	var craft_amount: int
	var craft_time: int
	var required_resources: Array
	var skill_requirement: Dictionary
	var skill_progression: Dictionary

	func _init(data: Dictionary):
		craft_amount = data.get("craft_amount", 1)
		craft_time = data.get("craft_time", 0)
		required_resources = data.get("required_resources", [])
		skill_requirement = data.get("skill_requirement", {})
		skill_progression = data.get("skill_progression", {})

	func get_data() -> Dictionary:
		var data: Dictionary = {
			"craft_amount": craft_amount,
			"craft_time": craft_time,
			"required_resources": required_resources
		}
		if not skill_requirement.is_empty():
			data["skill_requirement"] = skill_requirement
		if not skill_progression.is_empty():
			data["skill_progression"] = skill_progression
		return data

# Subclass to represent the Craft functionality
class Craft:
	var recipes: Array[CraftRecipe] = []

	func _init(data: Array):
		for recipe in data:
			recipes.append(CraftRecipe.new(recipe))

	func get_data() -> Array:
		var data: Array = []
		for recipe in recipes:
			data.append(recipe.get_data())
		return data

# Properties defined in the item
var id: String
var name: String
var description: String
var weight: float
var volume: float
var stack_size: int
var max_stack_size: int
var sprite: Texture
var spriteid: String
var craft: Craft
var parent: RItems  # Reference to the list containing all runtime items for this mod

# Constructor to initialize item properties
# myparent: The list containing all runtime items for this mod
# newid: The ID of the item being created
func _init(myparent: RItems, newid: String):
	parent = myparent
	id = newid

# Overwrite this item's properties using a DItem
func overwrite_from_ditem(ditem: DItem) -> void:
	if id != ditem.id:
		print_debug("Cannot overwrite from a different id")
		return
	name = ditem.name
	description = ditem.description
	weight = ditem.weight
	volume = ditem.volume
	stack_size = ditem.stack_size
	max_stack_size = ditem.max_stack_size
	spriteid = ditem.spriteid
	sprite = ditem.sprite

	# Convert DItem's Craft to RItem's Craft
	if ditem.craft:
		craft = Craft.new(ditem.craft.get_data())
	else:
		craft = null

# Get data function to return a dictionary with all properties
func get_data() -> Dictionary:
	var data: Dictionary = {
		"id": id,
		"name": name,
		"description": description,
		"weight": weight,
		"volume": volume,
		"stack_size": stack_size,
		"max_stack_size": max_stack_size,
		"sprite": spriteid
	}
	if craft:
		data["Craft"] = craft.get_data()
	return data

# Function to remove a reference from the item
func remove_reference(module: String, type: String, refid: String):
	if parent:
		parent.remove_reference(id, module, type, refid)

# Function to add a reference to the item
func add_reference(module: String, type: String, refid: String):
	if parent:
		parent.add_reference(id, module, type, refid)

# Called when an item is changed to update related references
func on_data_changed(oldditem: DItem):
	if craft and oldditem.craft:
		var old_resources = oldditem.craft.get_all_used_items()
		var new_resources = craft.get_all_used_items()

		# Remove references for resources no longer in use
		for res in old_resources:
			if not new_resources.has(res):
				remove_reference("core", "items", res)

		# Add references for new resources
		for res in new_resources:
			add_reference("core", "items", res)

# An item is being deleted
# Remove it from all references
func delete():
	if parent:
		parent.delete_by_id(id)
