class_name DItem
extends RefCounted

# There's a D in front of the class name to indicate this class only handles map data, nothing more
# This script is intended to be used inside the GameData autoload singleton
# This script handles the data for one item. You can access it through Gamedata.items

# This class represents a piece of item with its properties
var id: String
var name: String
var description: String
var weight: float
var volume: float
var sprite: Texture
var spriteid: String
var image: String
var stack_size: int
var max_stack_size: int
var two_handed: bool
var references: Dictionary = {}

# Other properties per type
var craft: Craft
var magazine: Magazine
var ranged: Ranged
var melee: Melee
var food: Food
var wearable: Wearable

# Inner class to handle the Craft property
class Craft:
	var craft_amount: int
	var craft_time: int
	var flags: Dictionary
	var required_resources: Array
	var skill_progression: Dictionary
	var skill_requirement: Dictionary

	# Constructor to initialize craft properties from a dictionary
	func _init(data: Dictionary):
		craft_amount = data.get("craft_amount", 1)
		craft_time = data.get("craft_time", 0)
		flags = data.get("flags", {})
		required_resources = data.get("required_resources", [])
		skill_progression = data.get("skill_progression", {})
		skill_requirement = data.get("skill_requirement", {})

	# Get data function to return a dictionary with all properties
	func get_data() -> Dictionary:
		return {
			"craft_amount": craft_amount,
			"craft_time": craft_time,
			"flags": flags,
			"required_resources": required_resources,
			"skill_progression": skill_progression,
			"skill_requirement": skill_requirement
		}

# Inner class to handle the Magazine property
class Magazine:
	var current_ammo: int
	var max_ammo: int
	var used_ammo: String

	# Constructor to initialize magazine properties from a dictionary
	func _init(data: Dictionary):
		current_ammo = data.get("current_ammo", 0)
		max_ammo = data.get("max_ammo", 0)
		used_ammo = data.get("used_ammo", "")

	# Get data function to return a dictionary with all properties
	func get_data() -> Dictionary:
		return {
			"current_ammo": current_ammo,
			"max_ammo": max_ammo,
			"used_ammo": used_ammo
		}


# Inner class to handle the Ranged property
class Ranged:
	var firing_speed: float
	var range: int
	var recoil: int
	var reload_speed: float
	var spread: int
	var sway: int
	var used_ammo: String
	var used_magazine: String
	var used_skill: Dictionary

	# Constructor to initialize ranged properties from a dictionary
	func _init(data: Dictionary):
		firing_speed = data.get("firing_speed", 0.0)
		range = data.get("range", 0)
		recoil = data.get("recoil", 0)
		reload_speed = data.get("reload_speed", 0.0)
		spread = data.get("spread", 0)
		sway = data.get("sway", 0)
		used_ammo = data.get("used_ammo", "")
		used_magazine = data.get("used_magazine", "")
		used_skill = data.get("used_skill", {})

	# Get data function to return a dictionary with all properties
	func get_data() -> Dictionary:
		return {
			"firing_speed": firing_speed,
			"range": range,
			"recoil": recoil,
			"reload_speed": reload_speed,
			"spread": spread,
			"sway": sway,
			"used_ammo": used_ammo,
			"used_magazine": used_magazine,
			"used_skill": used_skill
		}


# Inner class to handle the Melee property
class Melee:
	var damage: int
	var reach: int
	var used_skill: Dictionary

	# Constructor to initialize melee properties from a dictionary
	func _init(data: Dictionary):
		damage = data.get("damage", 0)
		reach = data.get("reach", 0)
		used_skill = data.get("used_skill", {})

	# Get data function to return a dictionary with all properties
	func get_data() -> Dictionary:
		return {
			"damage": damage,
			"reach": reach,
			"used_skill": used_skill
		}

# Inner class to handle the Food property
class Food:
	var health: int

	# Constructor to initialize food properties from a dictionary
	func _init(data: Dictionary):
		health = data.get("health", 0)

	# Get data function to return a dictionary with all properties
	func get_data() -> Dictionary:
		return {
			"health": health
		}

# Inner class to handle the Wearable property
class Wearable:
	var slot: String

	# Constructor to initialize wearable properties from a dictionary
	func _init(data: Dictionary):
		slot = data.get("slot", "")

	# Get data function to return a dictionary with all properties
	func get_data() -> Dictionary:
		return {
			"slot": slot
		}

# Constructor to initialize item properties from a dictionary
func _init(data: Dictionary):
	id = data.get("id", "")
	name = data.get("name", "")
	description = data.get("description", "")
	weight = data.get("weight", 0.0)
	volume = data.get("volume", 0.0)
	spriteid = data.get("sprite", "")
	image = data.get("image", "")
	stack_size = data.get("stack_size", 0)
	max_stack_size = data.get("max_stack_size", 0)
	two_handed = data.get("two_handed", false)
	references = data.get("references", {})

	# Initialize Craft and Magazine subclasses if they exist in data
	if data.has("Craft"):
		craft = Craft.new(data["Craft"][0])
	else:
		craft = null

	if data.has("Magazine"):
		magazine = Magazine.new(data["Magazine"])
	else:
		magazine = null

	if data.has("Ranged"):
		ranged = Ranged.new(data["Ranged"])
	else:
		ranged = null

	if data.has("Melee"):
		melee = Melee.new(data["Melee"])
	else:
		melee = null

	if data.has("Food"):
		food = Food.new(data["Food"])
	else:
		food = null

	if data.has("Wearable"):
		wearable = Wearable.new(data["Wearable"])
	else:
		wearable = null


# Get data function to return a dictionary with all properties
func get_data() -> Dictionary:
	var data: Dictionary = {
		"id": id,
		"name": name,
		"description": description,
		"weight": weight,
		"volume": volume,
		"sprite": spriteid,
		"image": image,
		"stack_size": stack_size,
		"max_stack_size": max_stack_size,
		"two_handed": two_handed,
		"references": references
	}

	# Add Craft and Magazine data if they exist
	if craft:
		data["Craft"] = [craft.get_data()]

	if magazine:
		data["Magazine"] = magazine.get_data()

	if ranged:
		data["Ranged"] = ranged.get_data()

	if melee:
		data["Melee"] = melee.get_data()

	if food:
		data["Food"] = food.get_data()

	if wearable:
		data["Wearable"] = wearable.get_data()

	return data


# Removes the provided reference from references
# For example, remove "grass_field" to references.Core.maps
# module: the mod that the entity belongs to, for example "Core"
# type: The type of entity, for example "maps"
# refid: The id of the entity, for example "grass_field"
func remove_reference(module: String, type: String, refid: String):
	var changes_made = Gamedata.dremove_reference(references, module, type, refid)
	if changes_made:
		Gamedata.items.save_items_to_disk()


# Adds a reference to the references list
# For example, add "grass_field" to references.Core.maps
# module: the mod that the entity belongs to, for example "Core"
# type: The type of entity, for example "maps"
# refid: The id of the entity, for example "grass_field"
func add_reference(module: String, type: String, refid: String):
	var changes_made = Gamedata.dadd_reference(references, module, type, refid)
	if changes_made:
		Gamedata.items.save_items_to_disk()


# Returns the path of the sprite
func get_sprite_path() -> String:
	return Gamedata.items.spritePath + spriteid


# Handles item changes and updates references if necessary
func on_data_changed(oldditem: DItem):
	var changes_made = false

	# If any references were updated, save the changes to the data file
	if changes_made:
		print_debug("Item reference updates saved successfully.")
		Gamedata.save_data_to_file(Gamedata.data.itemgroups)


# Some item is being deleted from the data
# We have to remove it from everything that references it
func delete():
	var changes_made = false
	if changes_made:
		Gamedata.save_data_to_file(Gamedata.data.itemgroups)
	else:
		print_debug("No changes needed for item", id)

