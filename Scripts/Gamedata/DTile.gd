class_name DTile
extends RefCounted


# There's a D in front of the class name to indicate this class only handles tile data, nothing more
# This script is intended to be used inside the GameData autoload singleton
# This script handles the data for one tile. You can access it through Gamedata.tiles

#Example tile data:
#	{
#		"id": "kitchen_tiles_green_00",
#		"name": "Kitchen tiles (green)",
#		"description": "A tiled floor you would find in a kitchen. The tiles are painted green",
#		"shape": "cube",
#		"sprite": "kitchentilesgreen.png",
#		"categories": [
#			"Floor",
#			"Urban"
#		],
#		"references": {
#			"core": {
#				"maps": [
#					"generichouse_t"
#				]
#			}
#		}
#	}

# This class represents a piece of item with its properties
var id: String
var name: String
var description: String
var shape: String
var sprite: Texture
var spriteid: String
var categories: Array
var references: Dictionary = {}


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

	if ammo:
		data["Ammo"] = ammo.get_data()

	if wearable:
		data["Wearable"] = wearable.get_data()

	return data


# Removes the provided reference from references
# For example, remove "grass_field" to references.Core.maps
# module: the mod that the entity belongs to, for example "Core"
# type: The type of entity, for example "maps"
# refid: The id of the entity, for example "grass_field"
func remove_reference(module: String, type: String, refid: String):
	var refitem: DItem = Gamedata.items.by_id(refid)
	var changes_made = Gamedata.dremove_reference(refitem.references, module, type, id)
	if changes_made:
		Gamedata.items.save_items_to_disk()


# Adds a reference to the references list
# For example, add "grass_field" to references.Core.maps
# module: the mod that the entity belongs to, for example "Core"
# type: The type of entity, for example "maps"
# refid: The id of the entity, for example "grass_field"
func add_reference(module: String, type: String, refid: String):
	var refitem: DItem = Gamedata.items.by_id(refid)
	var changes_made = Gamedata.dadd_reference(refitem.references, module, type, id)
	if changes_made:
		Gamedata.items.save_items_to_disk()


# Returns the path of the sprite
func get_sprite_path() -> String:
	return Gamedata.items.spritePath + spriteid


# Handles item changes and updates references if necessary
func on_data_changed(_oldditem: DItem):
	var changes_made = false

	# If any references were updated, save the changes to the data file
	if changes_made:
		print_debug("Item reference updates saved successfully.")
		Gamedata.save_data_to_file(Gamedata.data.itemgroups)


# Some item has been changed
# We need to update the relation between the item and other items based on crafting recipes
func changed(olddata: DItem):
	var changes_made = false
	
	# Handle wearable slot reference. 
	if wearable:
		# If the slot data changed between old and new, we update the reference
		var old_slot = null
		if olddata.wearable:
			old_slot = olddata.wearable.slot

		if old_slot != wearable.slot:
			if old_slot:
				changes_made = olddata.wearable.remove_reference(id) or changes_made
			if wearable.slot:
				changes_made = wearable.add_reference(id) or changes_made
	elif olddata.wearable and olddata.wearable.slot:
		# The wearable is present in the old data but not in the new, so we remove the reference
		changes_made = olddata.wearable.remove_reference(id) or changes_made
	
	
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
			changes_made = remove_reference("core", "items", res_id) or changes_made
	
	# Add references for new resources, nothing happens if they are already present
	for res_id in new_resource_ids:
		changes_made = add_reference("core", "items", res_id) or changes_made
	update_item_skill_references(olddata)
	
	Gamedata.items.save_items_to_disk()
	# Save changes if any modifications were made
	if changes_made:
		Gamedata.save_data_to_file(Gamedata.data.wearableslots)
		print_debug("Item changes saved successfully.")
	else:
		print_debug("No changes were made to item.")



# An item is being deleted from the data
# We have to remove it from everything that references it
func delete():
	var changes_made = { "value": false }
	
	# This callable will remove this item from itemgroups that reference this item.
	var myfunc: Callable = func (itemgroup_id):
		var itemlist: Array = Gamedata.get_property_by_path(Gamedata.data.itemgroups, "items", itemgroup_id)
		for i in range(itemlist.size()):
			if itemlist[i].has("id") and itemlist[i]["id"] == id:
				itemlist.remove_at(i)
				changes_made["value"] = true
				break  # Exit loop after removal to avoid index issues

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
		var quest_data = Gamedata.get_data_by_id(Gamedata.data.quests, quest_id)
		# Removes all steps where the item is equal to item_id
		changes_made["value"] = Helper.json_helper.remove_object_by_id(quest_data, \
		"steps.item", id) or changes_made["value"]
		# Removes all rewards where the reward's item_id is equal to item_id
		changes_made["value"] = Helper.json_helper.remove_object_by_id(quest_data, \
		"rewards.item_id", id) or changes_made["value"]

	# Pass the callable to every quest in the item's references
	# It will call remove_from_quest on every item in item_data.references.core.quests
	execute_callable_on_references_of_type("core", "quests", remove_from_quest)
	
	# For each recipe and for each item in each recipe, remove the reference to this item
	for resource in craft.get_all_used_items():
		changes_made["value"] = remove_reference("core", "items", resource) or changes_made["value"]

	# Collect unique skill IDs from the item's recipes
	var skill_ids: Dictionary = {}
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
		changes_made["value"] = Gamedata.remove_reference(Gamedata.data.skills, "core", \
		"items", skill_id, id) or changes_made["value"]

	# Save changes to the data file if any changes were made
	if changes_made["value"]:
		Gamedata.save_data_to_file(Gamedata.data.itemgroups)
		Gamedata.save_data_to_file(Gamedata.data.skills)
		Gamedata.save_data_to_file(Gamedata.data.quests)
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
