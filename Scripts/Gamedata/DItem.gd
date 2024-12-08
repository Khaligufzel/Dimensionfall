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
var medical: Medical
var ammo: Ammo
var wearable: Wearable

# Inner class to handle the Craft property
class CraftRecipe:
	var craft_amount: int
	var craft_time: int
	var flags: Dictionary
	var required_resources: Array # A list of objects like {"amount": 1, "id": "steel_scrap"}
	var skill_progression: Dictionary # example: { "id": "fabrication", "xp": 10 }
	var skill_requirement: Dictionary # example: { "id": "fabrication", "level": 1 }

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
		var mydata: Dictionary = {
			"craft_amount": craft_amount,
			"craft_time": craft_time,
			"flags": flags,
			"required_resources": required_resources
		}
		if not skill_requirement.is_empty():
			mydata["skill_requirement"] = skill_requirement
		if not skill_progression.is_empty():
			mydata["skill_progression"] = skill_progression
		return mydata
		
	# Function to get used skill IDs
	func get_used_skill_ids() -> Array:
		var skill_ids = []
		if skill_requirement.has("id"):
			skill_ids.append(skill_requirement["id"])
		if skill_progression.has("id"):
			skill_ids.append(skill_progression["id"])
		return skill_ids

	# Function to remove all instances of a skill from the recipe
	func remove_skill(skill_id: String) -> bool:
		var changes_made = false
		if skill_requirement.has("id") and skill_requirement["id"] == skill_id:
			skill_requirement.clear()
			changes_made = true
		if skill_progression.has("id") and skill_progression["id"] == skill_id:
			skill_progression.clear()
			changes_made = true
		return changes_made


class Craft:
	var recipes: Array[CraftRecipe] = []

	# Constructor to initialize craft properties from a dictionary
	func _init(data: Array):
		for recipe in data:
			recipes.append(CraftRecipe.new(recipe))

	# Get data function to return a dictionary with all properties
	func get_data() -> Array:
		var craft_data: Array = []
		if recipes.size() > 0:
			for recipe in recipes:
				craft_data.append(recipe.get_data())
		return craft_data
		
	# Function to get used skill IDs
	func get_used_skill_ids() -> Array:
		var skill_ids = []
		for recipe in recipes:
			skill_ids += recipe.get_used_skill_ids()
		return skill_ids
	
	# Function to remove all instances of an item from all recipes
	func remove_item_from_recipes(item_id: String) -> bool:
		var changes_made = false
		for recipe in recipes:
			var resources = recipe.required_resources
			for i in range(len(resources) - 1, -1, -1):
				if resources[i].get("id") == item_id:
					resources.remove_at(i)
					changes_made = true
		return changes_made

	# Function to get all used items in the recipes
	func get_all_used_items() -> Array:
		var used_items = []
		for recipe in recipes:
			var resources = recipe.required_resources
			for resource in resources:
				if not used_items.has(resource["id"]):
					used_items.append(resource["id"])
		return used_items
	
	# Function to remove all instances of a skill from all recipes
	func remove_skill_from_recipes(skill_id: String) -> bool:
		var changes_made = false
		for recipe in recipes:
			if recipe.remove_skill(skill_id):
				changes_made = true
		return changes_made
	

# Inner class to handle the Magazine property
class Magazine:
	var current_ammo: int
	var max_ammo: int
	var used_ammo: String

	# Constructor to initialize magazine properties from a dictionary
	func _init(data: Dictionary):
		current_ammo = int(data.get("current_ammo", 0))
		max_ammo = int(data.get("max_ammo", 0))
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
	var firing_range: int
	var recoil: int
	var reload_speed: float
	var spread: int
	var sway: int
	var used_ammo: String
	var used_magazine: String
	var used_skill: Dictionary # example: {"skill_id": "handguns", "xp": 1}

	# Constructor to initialize ranged properties from a dictionary
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

	# Get data function to return a dictionary with all properties
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
		
	# Function to get used skill ID
	func get_used_skill_ids() -> Array:
		if used_skill.has("skill_id"):
			return [used_skill["skill_id"]]
		return []

	# Function to remove all instances of a skill
	func remove_skill(skill_id: String) -> bool:
		if used_skill.has("skill_id") and used_skill["skill_id"] == skill_id:
			used_skill.clear()
			return true
		return false


# Inner class to handle the Melee property
class Melee:
	var damage: int
	var reach: int
	var used_skill: Dictionary # example: {"skill_id": "bashing", "xp": 1}

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

	# Function to get used skill ID
	func get_used_skill_ids() -> Array:
		if used_skill.has("skill_id"):
			return [used_skill["skill_id"]]
		return []

	# Function to remove all instances of a skill
	func remove_skill(skill_id: String) -> bool:
		if used_skill.has("skill_id") and used_skill["skill_id"] == skill_id:
			used_skill.clear()
			return true
		return false


# Inner class to handle the Food property
class Food:
	var attributes: Array = []  # example: [{"id":"food","amount":10}]

	# Constructor to initialize food properties from a dictionary
	func _init(data: Dictionary):
		attributes = []
		if data.has("attributes"):
			attributes = data["attributes"]

	# Get data function to return a dictionary with all properties
	func get_data() -> Dictionary:
		var food_data: Dictionary = {}
		if not attributes.is_empty():
			food_data["attributes"] = attributes
		return food_data

	# Function to return an array of all "id" values in the attributes array
	func get_attr_ids() -> Array:
		var ids: Array = []
		for attribute in attributes:
			if attribute.has("id"):
				ids.append(attribute["id"])
		return ids

	# Function to remove a player attribute by its ID
	func remove_player_attribute(attribute_id: String) -> void:
		for i in range(attributes.size()):
			if attributes[i]["id"] == attribute_id:
				attributes.remove_at(i)  # Remove the attribute if the ID matches
				break  # Exit the loop after removing the attribute


# Inner class to handle the Medical property
class Medical:
	var attributes: Array = []  # example: [{"id":"torso","amount":10}]
	var amount: float  # The general amount to be added to attributes
	# The order by which to apply the amount. Can be "Ascending", "Descending"
	# "Lowest first", "Highest first" and "Random"
	var order: String

	# Constructor to initialize Medical properties from a dictionary
	func _init(data: Dictionary):
		attributes = []
		if data.has("attributes"):
			attributes = data["attributes"]
		amount = data.get("amount", 0.0)
		order = data.get("order", "Random")  # Default to "Random" if not provided

	# Get data function to return a dictionary with all properties
	func get_data() -> Dictionary:
		var medical_data: Dictionary = {}
		if not attributes.is_empty():
			medical_data["attributes"] = attributes
		medical_data["amount"] = amount
		medical_data["order"] = order
		return medical_data

	# Function to return an array of all "id" values in the attributes array
	func get_attr_ids() -> Array:
		var ids: Array = []
		for attribute in attributes:
			if attribute.has("id"):
				ids.append(attribute["id"])
		return ids

	# Function to remove a player attribute by its ID
	func remove_player_attribute(attribute_id: String) -> void:
		for i in range(attributes.size()):
			if attributes[i]["id"] == attribute_id:
				attributes.remove_at(i)  # Remove the attribute if the ID matches
				break  # Exit the loop after removing the attribute


# Inner class to handle the Ammo property
class Ammo:
	var damage: int

	# Constructor to initialize food properties from a dictionary
	func _init(data: Dictionary):
		damage = int(data.get("damage", 0))

	# Get data function to return a dictionary with all properties
	func get_data() -> Dictionary:
		return {
			"damage": damage
		}

# Inner class to handle the Wearable property
class Wearable:
	var slot: String
	# Hold key-value pairs for player attributes. New format: {"id": "inventory_space", "value": 200}
	var player_attributes: Array  

	# Constructor to initialize wearable properties from a dictionary
	func _init(data: Dictionary):
		slot = data.get("slot", "")
		# Initialize player_attributes with the new format
		player_attributes = data.get("player_attributes", [])

	# Get data function to return a dictionary with all properties
	func get_data() -> Dictionary:
		var mydata: Dictionary = {}
		if slot:
			mydata["slot"] = slot
		if not player_attributes.is_empty():
			mydata["player_attributes"] = player_attributes
		return mydata

	# Function to add a reference for the wearable slot
	func add_reference(item_id: String):
		if slot != "":
			Gamedata.mods.add_reference(DMod.ContentType.WEARABLESLOTS, slot, DMod.ContentType.ITEMS, item_id)

	# Function to remove a reference for the wearable slot
	func remove_reference(item_id: String):
		if slot != "":
			Gamedata.mods.remove_reference(DMod.ContentType.WEARABLESLOTS, slot, DMod.ContentType.ITEMS, item_id)

	# Function to get the value of a specific player attribute by ID
	func get_attribute_value(attribute_id: String) -> Variant:
		for attribute in player_attributes:
			if attribute["id"] == attribute_id:
				return attribute["value"]
		return null  # Return null if the attribute is not found

	# Function to remove a player attribute by its ID
	func remove_player_attribute(attribute_id: String) -> void:
		for i in range(player_attributes.size()):
			if player_attributes[i]["id"] == attribute_id:
				player_attributes.remove_at(i)  # Remove the attribute if the ID matches
				break  # Exit the loop after removing the attribute


# Constructor to initialize item properties from a dictionary
func _init(data: Dictionary):
	id = data.get("id", "")
	name = data.get("name", "")
	description = data.get("description", "")
	weight = data.get("weight", 1.0)
	volume = data.get("volume", 1.0)
	spriteid = data.get("sprite", "")
	image = data.get("image", "")
	stack_size = data.get("stack_size", 1)
	max_stack_size = data.get("max_stack_size", 1)
	two_handed = data.get("two_handed", false)
	references = data.get("references", {})

	# Initialize Craft and Magazine subclasses if they exist in data
	if data.has("Craft"):
		craft = Craft.new(data["Craft"])
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

	if data.has("Medical"):
		medical = Medical.new(data["Medical"])
	else:
		medical = null

	if data.has("Ammo"):
		ammo = Ammo.new(data["Ammo"])
	else:
		ammo = null

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
		"two_handed": two_handed
	}
	if not references.is_empty():
		data["references"] = references

	# Add Craft and Magazine data if they exist
	if craft:
		data["Craft"] = craft.get_data()

	if magazine:
		data["Magazine"] = magazine.get_data()

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
		var wearabledata = wearable.get_data()
		if not wearabledata.is_empty():
			data["Wearable"] = wearabledata

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


# Some item has been changed
# We need to update the relation between the item and other items based on crafting recipes
func changed(olddata: DItem):
	# Handle wearable slot reference. 
	if wearable:
		# If the slot data changed between old and new, we update the reference
		var old_slot = null
		if olddata.wearable:
			old_slot = olddata.wearable.slot

		if old_slot != wearable.slot:
			if old_slot:
				olddata.wearable.remove_reference(id)
			if wearable.slot:
				wearable.add_reference(id)
		
		process_wearable_player_attributes(olddata)
		
	elif olddata.wearable and olddata.wearable.slot:
		# The wearable is present in the old data but not in the new, so we remove the reference
		olddata.wearable.remove_reference(id)
	
	
	# Dictionaries to track unique resource IDs across all recipes
	var old_resource_ids: Dictionary = {}
	var new_resource_ids: Dictionary = {}

	# Collect all unique resource IDs from old recipes if olddata.craft is not null
	if olddata.craft:
		for recipe: CraftRecipe in olddata.craft.recipes:
			for resource in recipe.required_resources:
				old_resource_ids[resource["id"]] = true

	# Collect all unique resource IDs from new recipes if craft is not null
	if craft:
		for recipe in craft.recipes:
			for resource in recipe.required_resources:
				new_resource_ids[resource["id"]] = true

	# Resources that are no longer in the recipe will no longer reference this item
	for res_id in old_resource_ids:
		if not new_resource_ids.has(res_id):
			remove_reference("core", "items", res_id)
	
	# Add references for new resources, nothing happens if they are already present
	for res_id in new_resource_ids:
		add_reference("core", "items", res_id)
	update_item_skill_references(olddata)
	update_item_attribute_references(olddata)
	
	Gamedata.items.save_items_to_disk()


# Function to process player attributes in the wearable and update references accordingly
func process_wearable_player_attributes(olddata: DItem):
	if not wearable:
		# If there's no wearable in the new data but the olddata wearable has attributes, remove their references
		if olddata.wearable and not olddata.wearable.player_attributes.is_empty():
			# Loop over old player attributes and remove references
			for old_attr in olddata.wearable.player_attributes:
				Gamedata.mods.remove_reference(DMod.ContentType.PLAYERATTRIBUTES, old_attr["id"], DMod.ContentType.ITEMS, id)
		return  # Exit since there's no wearable in the new data
	
	if wearable.player_attributes.is_empty():
		# If the new wearable has no player attributes, remove all references from olddata if they exist
		if olddata.wearable and not olddata.wearable.player_attributes.is_empty():
			for old_attr in olddata.wearable.player_attributes:
				Gamedata.mods.remove_reference(DMod.ContentType.PLAYERATTRIBUTES, old_attr["id"], DMod.ContentType.ITEMS, id)
		return  # Exit since there are no player attributes to add

	# Collect new and old player attributes
	var new_player_attributes = wearable.player_attributes
	var old_player_attributes = olddata.wearable.player_attributes if olddata.wearable else []

	# Dictionary to track old attribute ids for easy lookup
	var old_attr_dict: Dictionary = {}
	for old_attr in old_player_attributes:
		old_attr_dict[old_attr["id"]] = old_attr

	# Loop over new attributes and add references
	for new_attr in new_player_attributes:
		var attribute_id = new_attr["id"]
		# Add reference for the new attribute
		Gamedata.mods.add_reference(DMod.ContentType.PLAYERATTRIBUTES, attribute_id, DMod.ContentType.ITEMS, id)

		# Remove the old attribute from the dictionary, as it still exists
		old_attr_dict.erase(attribute_id)

	# Any remaining attributes in old_attr_dict were removed, so remove their references
	for old_attr_id in old_attr_dict.keys():
		Gamedata.mods.remove_reference(DMod.ContentType.PLAYERATTRIBUTES, old_attr_id, DMod.ContentType.ITEMS, id)


# Collects all skills defined in an item and updates the references to that skill
func update_item_skill_references(olddata: DItem):
	# Function to collect skill IDs from a list of used skills
	var collect_skill_ids: Callable = func (item: DItem):
		var skill_ids = []
		if item.craft:
			skill_ids += item.craft.get_used_skill_ids()
		if item.ranged:
			skill_ids += item.ranged.get_used_skill_ids()
		if item.melee:
			skill_ids += item.melee.get_used_skill_ids()
		return skill_ids

	# Collect skill IDs from old and new data
	var old_skill_ids = collect_skill_ids.call(olddata)
	var new_skill_ids = collect_skill_ids.call(self)

	# Remove old skill references that are not in the new list
	for old_skill_id in old_skill_ids:
		if not new_skill_ids.has(old_skill_id):
			Gamedata.mods.remove_reference(DMod.ContentType.SKILLS, old_skill_id, DMod.ContentType.ITEMS, id)
	
	# Add new skill references
	for new_skill_id in new_skill_ids:
		Gamedata.mods.add_reference(DMod.ContentType.SKILLS, new_skill_id, DMod.ContentType.ITEMS, id)


# Collects all attributes defined in an item and updates the references to that attribute
func update_item_attribute_references(olddata: DItem):
	# Collect all attribute IDs from old and new data (food and medical)
	var old_attr_ids = []
	var new_attr_ids = []

	if olddata.food:
		old_attr_ids.append_array(olddata.food.get_attr_ids())
	if olddata.medical:
		old_attr_ids.append_array(olddata.medical.get_attr_ids())

	if food:
		new_attr_ids.append_array(food.get_attr_ids())
	if medical:
		new_attr_ids.append_array(medical.get_attr_ids())

	# Remove old attribute references that are not in the new list
	for old_attr_id in old_attr_ids:
		if not new_attr_ids.has(old_attr_id):
			Gamedata.mods.remove_reference(DMod.ContentType.PLAYERATTRIBUTES, old_attr_id, DMod.ContentType.ITEMS, id)
	
	# Add new attribute references
	for new_attr_id in new_attr_ids:
		Gamedata.mods.add_reference(DMod.ContentType.PLAYERATTRIBUTES, new_attr_id, DMod.ContentType.ITEMS, id)


# An item is being deleted from the data
# We have to remove it from everything that references it
func delete():
	var changes_made = { "value": false }
	
	# This callable will remove this item from itemgroups that reference this item.
	var myfunc: Callable = func (itemgroup_id):
		var ditemgroup: DItemgroup = Gamedata.itemgroups.by_id(itemgroup_id)
		ditemgroup.remove_item_by_id(id)

	execute_callable_on_references_of_type("core", "itemgroups", myfunc)
	
	# This callable will handle the removal of this item from all crafting recipes in other items
	var remove_from_item: Callable = func(other_item_id: String):
		var other_item: DItem = Gamedata.items.by_id(other_item_id)
		if other_item and other_item.craft:
			if other_item.craft.remove_item_from_recipes(id):
				changes_made["value"] = true

	# Pass the callable to every item in the item's references
	# It will call remove_from_item on every item in item_data.references.core.items
	execute_callable_on_references_of_type("core", "items", remove_from_item)
	
	# This callable will handle the removal of this item from all steps in quests
	var remove_from_quest: Callable = func(quest_id: String):
		Gamedata.mods.by_id("Core").quests.remove_item_from_quest(quest_id, id)

	# Pass the callable to every quest in the item's references
	# It will call remove_from_quest on every item in item_data.references.core.quests
	execute_callable_on_references_of_type("core", "quests", remove_from_quest)
	
	if food and not food.attributes.is_empty():
		for food_attribute in food.attributes:
			Gamedata.mods.remove_reference(DMod.ContentType.PLAYERATTRIBUTES, food_attribute["id"], DMod.ContentType.ITEMS, id)
			
	if medical and not medical.attributes.is_empty():
		for medical_attribute in medical.attributes:
			Gamedata.mods.remove_reference(DMod.ContentType.PLAYERATTRIBUTES, medical_attribute["id"], DMod.ContentType.ITEMS, id)
			
	if wearable and not wearable.player_attributes.is_empty():
		for wearableattr in wearable.player_attributes:
			Gamedata.mods.remove_reference(DMod.ContentType.PLAYERATTRIBUTES, wearableattr["id"], DMod.ContentType.ITEMS, id)
			
	var skill_ids: Dictionary = {}
	# Check if 'craft' is not null before proceeding
	if craft:
		# For each recipe and for each item in each recipe, remove the reference to this item
		for resource in craft.get_all_used_items():
			changes_made["value"] = remove_reference("core", "items", resource) or changes_made["value"]

		# Collect unique skill IDs from the item's recipes
		for skillid in craft.get_used_skill_ids():
			skill_ids[skillid] = true

	# Add the ranged skill to the skill list
	if ranged and ranged.used_skill:
		skill_ids[ranged.used_skill.skill_id] = true

	# Add the melee skill to the skill list
	if melee and melee.used_skill:
		skill_ids[melee.used_skill.skill_id] = true

	# Remove the reference of this item from each skill
	for skill_id in skill_ids.keys():
		Gamedata.mods.remove_reference(DMod.ContentType.SKILLS, skill_id, DMod.ContentType.ITEMS, id)

	# Save changes to the data file if any changes were made
	if changes_made["value"]:
		Gamedata.items.save_items_to_disk()
	else:
		print_debug("No changes needed for item", id)


# Executes a callable function on each reference of the given type
# module = name of the mod. for example "core"
# type = the type of reference we want to handle. For example "itemgroup"
# callable = a function to execute on each reference ID
# We will check if data has the [module] and [type] properties and execute the callable on each found ID
func execute_callable_on_references_of_type(module: String, type: String, callable: Callable):
	# Check if it contains the specified 'module' and 'type'
	if references.has(module) and references[module].has(type):
		# If the type exists, execute the callable on each ID found under this type
		for ref_id in references[module][type]:
			callable.call(ref_id)



# Function to remove all instances of a skill from the item
func remove_skill(skill_id: String) -> bool:
	var changes_made = false
	if craft and craft.remove_skill_from_recipes(skill_id):
		changes_made = true
	if ranged and ranged.remove_skill(skill_id):
		changes_made = true
	if melee and melee.remove_skill(skill_id):
		changes_made = true
	return changes_made
