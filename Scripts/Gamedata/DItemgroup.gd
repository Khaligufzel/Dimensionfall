class_name DItemgroup
extends RefCounted


# There's a D in front of the class name to indicate this class only handles itemgroup data, nothing more
# This script is intended to be used inside the GameData autoload singleton
# This script handles the data for one itemgroup. You can access it through parent


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
#		"sprite": "machete_32.png",
#		"use_sprite": true
#	}

# Subclass to represent individual items in the itemgroup
class Item:
	var id: String
	var maxc: int # max count
	var minc: int # min count
	var probability: int

	func _init(data: Dictionary):
		id = data.get("id", "")
		maxc = data.get("max", 1)
		minc = data.get("min", 1)
		probability = data.get("probability", 100)

	func get_data() -> Dictionary:
		return {
			"id": id,
			"max": maxc,
			"min": minc,
			"probability": probability
		}


# Properties defined in the JSON
var id: String
var name: String
var description: String
var mode: String # can be "Collection" or "Distribution". See the itemgroup editor for info
var spriteid: String
var sprite: Texture
# If use_sprite is true, the sprite will be used to visualize 
# this itemgroup if it is spawned in a ContainerItem on the map
var use_sprite: bool = false
var items: Array[Item] = []
var parent: DItemgroups

# Constructor to initialize itemgroup properties from a dictionary
# myparent: The list containing all itemgroups for this mod
func _init(data: Dictionary, myparent: DItemgroups):
	parent = myparent
	id = data.get("id", "")
	name = data.get("name", "")
	description = data.get("description", "")
	mode = data.get("mode", "Collection")
	spriteid = data.get("sprite", "")
	use_sprite = data.get("use_sprite", false)
	
	var item_data = data.get("items", [])
	for item in item_data:
		items.append(Item.new(item))

# Get data function to return a dictionary with all properties
func get_data() -> Dictionary:
	var item_data = []
	for item in items:
		item_data.append(item.get_data())

	var data: Dictionary = {
		"id": id,
		"name": name,
		"description": description,
		"mode": mode,
		"sprite": spriteid,
		"use_sprite": use_sprite,
		"items": item_data
	}
	return data


# Some itemgroup has been changed
# INFO if the itemgroup reference other entities, update them here
func changed(olddata: DItemgroup):
	# Create lists of ids for each item in the itemgroup
	var oldlist = olddata.items.map(func(it): return it.id)
	var newlist = items.map(func(it): return it.id)
	var itemgroup = id

	# Remove itemgroup from items in the old list that are not in the new list
	for item_id in oldlist:
		if item_id not in newlist:
			Gamedata.items.remove_reference(item_id, "core", "itemgroups", itemgroup)

	# Add itemgroup to items in the new list that were not in the old list
	for item_id in newlist:
		if item_id not in oldlist:
			Gamedata.items.add_reference(item_id, "core", "itemgroups", itemgroup)

	parent.save_itemgroups_to_disk()


# A itemgroup is being deleted from the data
# We have to remove it from everything that references it
func delete():
	# Check to see if any mod has a copy of this tile. if one or more remain, we can keep references
	# Otherwise, the last copy was removed and we need to remove references
	var all_results: Array = Gamedata.mods.get_all_content_by_id(DMod.ContentType.MOBS, id)
	if all_results.size() > 1:
		return
	
	# Get a list of all maps that reference this mob
	var myreferences: Dictionary = parent.references.get(id, {})
	var myfurnitures: Array = myreferences.get("furnitures", [])
	for furniture in myfurnitures:
		Gamedata.furnitures.by_id(furniture).remove_itemgroup(id)

	# Remove references to this itemgroup from items listed in the itemgroup data.
	for item in items:
		Gamedata.items.remove_reference(item.id, "core", "itemgroups", id)

	# This callable will handle the removal of this mob from all steps in maps
	var mymapslist: Array = myreferences.get("maps", [])
	var remove_from_map: Callable = func(map_id: String):
		# Get all copies of the maps with map_id from all mods
		var mymaps: Array = Gamedata.mods.get_all_content_by_id(DMod.ContentType.MAPS, map_id)
		for dmap: DMap in mymaps:
			dmap.remove_entity_from_map("itemgroup", id)

	# Pass the callable to every map in the mob's references
	# It will call remove_from_map on every map in this mob's references
	execute_callable_on_references_of_type(DMod.ContentType.MAPS, remove_from_map)


# Executes a callable function on each reference of the given type
# type: The type of entity that you want to execute the callable for
# callable: The function that will be executed for every entity of this type
func execute_callable_on_references_of_type(type: DMod.ContentType, callable: Callable):
	# myreferences will ba dictionary that contains entity types that have references to this skill's id
	# See DMod.add_reference for an example structure of references
	var myreferences: Dictionary = parent.references.get(id, {})
	var type_string: String = DMod.get_content_type_string(type)
	# Check if it contains the specified 'module' and 'type'
	if myreferences.has(type_string):
		# If the type exists, execute the callable on each ID found under this type
		for ref_id in myreferences[type_string]:
			callable.call(ref_id)


# Removes an item by its ID from the items list
func remove_item_by_id(item_id: String) -> void:
	var item_to_remove: Item = null
	for item: Item in items:
		if item.id == item_id:
			item_to_remove = item
			break

	if item_to_remove:
		items.erase(item_to_remove)
		parent.save_itemgroups_to_disk()
