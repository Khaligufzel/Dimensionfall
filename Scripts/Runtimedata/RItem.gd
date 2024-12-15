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

class Ranged:
	var firing_speed: float
	var firing_range: int
	var recoil: int
	var reload_speed: float
	var spread: int
	var sway: int
	var used_ammo: String
	var used_magazine: String
	var used_skill: Dictionary

	func _init(data: Dictionary):
		firing_speed = data.get("firing_speed", 0.0)
		firing_range = data.get("range", 0)
		recoil = data.get("recoil", 0)
		reload_speed = data.get("reload_speed", 0.0)
		spread = data.get("spread", 0)
		sway = data.get("sway", 0)
		used_ammo = data.get("used_ammo", "")
		used_magazine = data.get("used_magazine", "")
		used_skill = data.get("used_skill", {})

	func get_data() -> Dictionary:
		return {
			"firing_speed": firing_speed,
			"range": firing_range,
			"recoil": recoil,
			"reload_speed": reload_speed,
			"spread": spread,
			"sway": sway,
			"used_ammo": used_ammo,
			"used_magazine": used_magazine,
			"used_skill": used_skill
		}

class Melee:
	var damage: int
	var reach: int
	var used_skill: Dictionary

	func _init(data: Dictionary):
		damage = data.get("damage", 0)
		reach = data.get("reach", 0)
		used_skill = data.get("used_skill", {})

	func get_data() -> Dictionary:
		return {
			"damage": damage,
			"reach": reach,
			"used_skill": used_skill
		}

class Food:
	var attributes: Array

	func _init(data: Dictionary):
		attributes = data.get("attributes", [])

	func get_data() -> Dictionary:
		return { "attributes": attributes }

class Medical:
	var attributes: Array
	var amount: float
	var order: String

	func _init(data: Dictionary):
		attributes = data.get("attributes", [])
		amount = data.get("amount", 0.0)
		order = data.get("order", "Random")

	func get_data() -> Dictionary:
		return {
			"attributes": attributes,
			"amount": amount,
			"order": order
		}

class Ammo:
	var damage: int

	func _init(data: Dictionary):
		damage = data.get("damage", 0)

	func get_data() -> Dictionary:
		return { "damage": damage }

class Wearable:
	var slot: String
	var player_attributes: Array

	func _init(data: Dictionary):
		slot = data.get("slot", "")
		player_attributes = data.get("player_attributes", [])

	func get_data() -> Dictionary:
		return { "slot": slot, "player_attributes": player_attributes }

# Properties of the RItem class
var id: String
var name: String
var description: String
var weight: float
var volume: float
var stack_size: int
var max_stack_size: int
var image: String
var sprite: Texture
var spriteid: String
var craft: Craft
var ranged: Ranged
var melee: Melee
var food: Food
var medical: Medical
var ammo: Ammo
var wearable: Wearable
var referenced_items: Array[String]
var parent: RItems

# Constructor to initialize item properties
# myparent: The list containing all runtime items
# newid: The ID of the item being created
func _init(myparent: RItems, newid: String):
	parent = myparent
	id = newid

# Overwrite this item's properties using a DItem
func overwrite_from_ditem(ditem: DItem) -> void:
	if id != ditem.id:
		print_debug("Cannot overwrite from a different id")
		return
	
	# Get a list of all items that reference this item
	var myreferences: Dictionary = ditem.parent.references.get(id, {})
	var referenced_from_items: Array = myreferences.get("items", [])
	referenced_items = Helper.json_helper.merge_unique(referenced_items,referenced_from_items)
	name = ditem.name
	description = ditem.description
	weight = ditem.weight
	volume = ditem.volume
	stack_size = ditem.stack_size
	max_stack_size = ditem.max_stack_size
	spriteid = ditem.spriteid
	sprite = ditem.sprite
	image = ditem.image
	
	craft = Craft.new(ditem.craft.get_data()) if ditem.craft else null
	ranged = Ranged.new(ditem.ranged.get_data()) if ditem.ranged else null
	melee = Melee.new(ditem.melee.get_data()) if ditem.melee else null
	food = Food.new(ditem.food.get_data()) if ditem.food else null
	medical = Medical.new(ditem.medical.get_data()) if ditem.medical else null
	ammo = Ammo.new(ditem.ammo.get_data()) if ditem.ammo else null
	wearable = Wearable.new(ditem.wearable.get_data()) if ditem.wearable else null

# Get data function
func get_data() -> Dictionary:
	var data: Dictionary = {
		"id": id,
		"name": name,
		"description": description,
		"weight": weight,
		"volume": volume,
		"stack_size": stack_size,
		"max_stack_size": max_stack_size,
		"sprite": spriteid,
		"image": image
	}
	if craft:
		data["Craft"] = craft.get_data()
	if ranged:
		data["Ranged"] = ranged.get_data()
	if melee:
		data["Melee"] = melee.get_data()
	if food:
		data["Food"] = food.get_data()
	if medical:
		data["Medical"] = medical.get_data()
	if ammo:
		data["Ammo"] = ammo.get_data()
	if wearable:
		data["Wearable"] = wearable.get_data()
	return data
