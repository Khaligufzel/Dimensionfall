class_name DItemgroup
extends RefCounted


# There's a D in front of the class name to indicate this class only handles itemgroup data, nothing more
# This script is intended to be used inside the GameData autoload singleton
# This script handles the data for one itemgroup. You can access it through Gamedata.itemgroups


# This class represents a itemgroup with its properties
# Example itemgroup data:
#	{
#		"description": "Loot that's dropped by a mob",
#		"id": "mob_loot",
#		"items": [
#			{
#				"id": "bullet_9mm",
#				"max": 20,
#				"min": 10,
#				"probability": 20
#			},
#			{
#				"id": "pistol_magazine",
#				"max": 1,
#				"min": 1,
#				"probability": 20
#			},
#			{
#				"id": "steel_scrap",
#				"max": 1,
#				"min": 1,
#				"probability": 20
#			},
#			{
#				"id": "plank_2x4",
#				"max": 1,
#				"min": 1,
#				"probability": 20
#			}
#		],
#		"mode": "Collection",
#		"name": "Mob loot",
#		"references": {
#			"core": {
#				"mobs": [
#					"rust_sentinel"
#				]
#			}
#		},
#		"sprite": "machete_32.png"
#	}


# Properties defined in the JSON
var id: String
var name: String
var description: String
var health: int
var hearing_range: int
var idle_move_speed: float
var loot_group: String
var melee_damage: int
var melee_range: float
var move_speed: float
var sense_range: int
var sight_range: int
var spriteid: String
var sprite: Texture
var references: Dictionary = {}

# Constructor to initialize itemgroup properties from a dictionary
func _init(data: Dictionary):
	id = data.get("id", "")
	name = data.get("name", "")
	description = data.get("description", "")
	health = data.get("health", 100)
	hearing_range = data.get("hearing_range", 1000)
	idle_move_speed = data.get("idle_move_speed", 0.5)
	loot_group = data.get("loot_group", "")
	melee_damage = data.get("melee_damage", 20)
	melee_range = data.get("melee_range", 1.5)
	move_speed = data.get("move_speed", 1.0)
	sense_range = data.get("sense_range", 50)
	sight_range = data.get("sight_range", 200)
	spriteid = data.get("sprite", "")
	references = data.get("references", {})

# Get data function to return a dictionary with all properties
func get_data() -> Dictionary:
	var data: Dictionary = {
		"id": id,
		"name": name,
		"description": description,
		"health": health,
		"hearing_range": hearing_range,
		"idle_move_speed": idle_move_speed,
		"loot_group": loot_group,
		"melee_damage": melee_damage,
		"melee_range": melee_range,
		"move_speed": move_speed,
		"sense_range": sense_range,
		"sight_range": sight_range,
		"sprite": spriteid
	}
	if not references.is_empty():
		data["references"] = references
	return data

# Removes the provided reference from references
func remove_reference(module: String, type: String, refid: String):
	var changes_made = Gamedata.dremove_reference(references, module, type, refid)
	if changes_made:
		Gamedata.itemgroups.save_itemgroups_to_disk()

# Adds a reference to the references list
func add_reference(module: String, type: String, refid: String):
	var changes_made = Gamedata.dadd_reference(references, module, type, refid)
	if changes_made:
		Gamedata.itemgroups.save_itemgroups_to_disk()


# Handles itemgroup changes and updates references if necessary
func on_data_changed(_olditemgroup: DItemgroup):
	var changes_made = false
	# If any references were updated, save the changes to the data file
	if changes_made:
		print_debug("itemgroup reference updates saved successfully.")
		Gamedata.itemgroups.save_itemgroups_to_disk()


# Some itemgroup has been changed
# INFO if the itemgroup reference other entities, update them here
func changed(olddata: DItemgroup):
	var old_loot_group: String = olddata.loot_group

	# Exit if old_group and new_group are the same
	if old_loot_group == loot_group:
		print_debug("No change in itemgroup. Exiting function.")
		return
	var changes_made = false
	# This itemgroup will be removed from the old itemgroup's references
	# The 'or' makes sure changes_made does not change back to false
	changes_made = Gamedata.remove_reference(Gamedata.data.itemgroups, "core", "itemgroups", old_loot_group, id) or changes_made
	# This itemgroup will be added to the new itemgroup's references
	# The 'or' makes sure changes_made does not change back to false
	changes_made = Gamedata.add_reference(Gamedata.data.itemgroups, "core", "itemgroups", loot_group, id) or changes_made
	# Save changes if any modifications were made
	if changes_made:
			Gamedata.save_data_to_file(Gamedata.data.itemgroups)


# A itemgroup is being deleted from the data
# We have to remove it from everything that references it
func delete():
	var changes_made = { "value": false }
	changes_made["value"] = Gamedata.remove_reference(Gamedata.data.itemgroups, "core", "itemgroups", loot_group, id) or changes_made["value"]
	
	# Check if the itemgroup has references to maps and remove it from those maps
	var mapsdata = Helper.json_helper.get_nested_data(references,"core.maps")
	if mapsdata:
		Gamedata.maps.remove_entity_from_selected_maps("itemgroup", id, mapsdata)
	
	# This callable will handle the removal of this itemgroup from all steps in quests
	var remove_from_quest: Callable = func(quest_id: String):
		var quest_data = Gamedata.get_data_by_id(Gamedata.data.quests, quest_id)
		changes_made["value"] = Helper.json_helper.remove_object_by_id(quest_data, "steps.itemgroup", id) or changes_made["value"]
		
	# Pass the callable to every quest in the itemgroup's references
	# It will call remove_from_quest on every itemgroup in itemgroup_data.references.core.quests
	execute_callable_on_references_of_type("core", "quests", remove_from_quest)

	# Save changes to the data file if any changes were made
	if changes_made["value"]:
		Gamedata.save_data_to_file(Gamedata.data.itemgroups)
		Gamedata.save_data_to_file(Gamedata.data.quests)
	else:
		print_debug("No changes needed for itemgroup", id)


# Executes a callable function on each reference of the given type
func execute_callable_on_references_of_type(module: String, type: String, callable: Callable):
	# Check if it contains the specified 'module' and 'type'
	if references.has(module) and references[module].has(type):
		# If the type exists, execute the callable on each ID found under this type
		for ref_id in references[module][type]:
			callable.call(ref_id)
