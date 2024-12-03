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
var references: Dictionary = {}

# Constructor to initialize itemgroup properties from a dictionary
func _init(data: Dictionary):
	id = data.get("id", "")
	name = data.get("name", "")
	description = data.get("description", "")
	mode = data.get("mode", "Collection")
	spriteid = data.get("sprite", "")
	use_sprite = data.get("use_sprite", false)
	references = data.get("references", {})
	
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

	Gamedata.itemgroups.save_itemgroups_to_disk()


# A itemgroup is being deleted from the data
# We have to remove it from everything that references it
func delete():
	# Callable to remove the itemgroup from every furniture that references this itemgroup.
	var myfunc: Callable = func(furn_id):
		var furniture: DFurniture = Gamedata.furnitures.by_id(furn_id)
		furniture.remove_itemgroup(id)

	# Pass the callable to every furniture in the itemgroup's references
	# It will call myfunc on every furniture in itemgroup_data.references.core.furniture
	execute_callable_on_references_of_type("core", "furniture", myfunc)

	# Remove references to this itemgroup from items listed in the itemgroup data.
	for item in items:
		Gamedata.items.remove_reference(item.id, "core", "itemgroups", id)

	# Remove references to maps
	var mapsdata: Array = Helper.json_helper.get_nested_data(references, "core.maps")
	for mymap: String in mapsdata:
		var mymaps: Array = Gamedata.mods.get_all_content_by_id(DMod.ContentType.MAPS, mymap)
		for dmap: DMaps in mymaps:
			dmap.remove_entity_from_selected_maps("itemgroup", id, mapsdata)


# Executes a callable function on each reference of the given type
func execute_callable_on_references_of_type(module: String, type: String, callable: Callable):
	# Check if it contains the specified 'module' and 'type'
	if references.has(module) and references[module].has(type):
		# If the type exists, execute the callable on each ID found under this type
		for ref_id in references[module][type]:
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
		Gamedata.itemgroups.save_itemgroups_to_disk()
