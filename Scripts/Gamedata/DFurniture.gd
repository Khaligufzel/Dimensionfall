class_name DFurniture
extends RefCounted

# There's a D in front of the class name to indicate this class only handles furniture data, nothing more
# This script is intended to be used inside the GameData autoload singleton
# This script handles the data for one furniture. You can access it through Gamedata.mods.by_id("Core").furnitures

# Example json:
#	{
#		"id": "countertop_wood",
#		"name": "Wooden countertop",
#		"description": "One of the central pieces of fruniture that make up a kitchen",
#		"sprite": "countertop_100_52.png",
#		"Function": {
#			"container_group": "kitchen_cupboard",
#			"is_container": true,
#			"container_sprite_mode": default, // can be default, hide or random
#			"container_regeneration_time": -1
#		},
#		"categories": [
#			"Urban",
#			"Kitchen",
#			"Indoor"
#		],
#		"destruction": {
#			"group": "destroyed_furniture_medium",
#			"sprite": "wreck_wood_generic_32.png"
#		},
#		"disassembly": {
#			"group": "disassembled_furniture_medium",
#			"sprite": "wreck_wood_generic_32.png"
#		},
#		"edgesnapping": "North",
#		"moveable": false,
#		"support_shape": {
#			"color": "8d401bff",
#			"depth_scale": 100,
#			"height": 0.5,
#			"shape": "Box",
#			"transparent": false,
#			"width_scale": 100
#		},
#		"weight": 1,
#		"crafting": {
#			"items": ["wood_parts", "steel_parts]
#		},
#		"construction": {
#			"items": {"wood_planks": 4, "nails": 8}
#		}
#	}

# Constants for defaults
const DEFAULT_CONTAINER_REGEN = -1.0
const DEFAULT_COLOR = "ffffffff"

# This class represents a piece of furniture with its properties
var id: String
var name: String
var description: String
var categories: Array
var moveable: bool
var weight: float
var edgesnapping: String
var sprite: Texture
var spriteid: String
var function: Function
var support_shape: SupportShape
var destruction: Destruction
var disassembly: Disassembly
var crafting: Crafting
var construction: Construction
var parent: DFurnitures

# -------------------------------
# Inner Classes for Nested Data
# -------------------------------

# Function Property
class Function:
	var door: String = "None"  # Can be "None", "Open" or "Closed"
	var is_container: bool = false
	var container_sprite_mode: String = "default"  # Can be "default", "hide", or "random"
	var container_group: String = ""
	var container_regeneration_time: float = DEFAULT_CONTAINER_REGEN  # Time in days for container regeneration (-1.0 if it doesn't regenerate)

	func _init(data: Dictionary):
		door = data.get("door", "None")
		is_container = data.get("is_container", false)
		container_sprite_mode = data.get("container_sprite_mode", "default")  # Default to "default" if not specified
		container_group = data.get("container_group", "")
		container_regeneration_time = data.get("container_regeneration_time", DEFAULT_CONTAINER_REGEN)

	# Get data function to return a dictionary with all properties
	func get_data() -> Dictionary:
		var result = {}
		if is_container:
			result["is_container"] = is_container
			if container_sprite_mode != "default":  # Include container_sprite_mode if it differs from default
				result["container_sprite_mode"] = container_sprite_mode
			if container_group != "":
				result["container_group"] = container_group
			if container_regeneration_time != DEFAULT_CONTAINER_REGEN:
				result["container_regeneration_time"] = container_regeneration_time
		if door != "None":
			result["door"] = door
		return result  # Potentially return an empty dictionary


# Support Shape Property
class SupportShape:
	var color: String = DEFAULT_COLOR
	var depth_scale: float = 100.0
	var height: float = 0.5
	var shape: String = "Box"
	var transparent: bool = false
	var width_scale: float = 100.0
	var radius_scale: float = 100.0

	func _init(data: Dictionary):
		set_data(data)

	func set_data(data: Dictionary):
		color = data.get("color", DEFAULT_COLOR)
		depth_scale = data.get("depth_scale", 100.0)
		height = data.get("height", 0.5)
		shape = data.get("shape", "Box")
		transparent = data.get("transparent", false)
		width_scale = data.get("width_scale", 100.0)
		radius_scale = data.get("radius_scale", 100.0)

	func get_data() -> Dictionary:
		var result = {
			"color": color,
			"height": height,
			"shape": shape,
			"transparent": transparent
		}
		if shape == "Box":
			result["width_scale"] = width_scale
			result["depth_scale"] = depth_scale
		elif shape == "Cylinder":
			result["radius_scale"] = radius_scale
		return result

# Destruction Property
class Destruction:
	var group: String = ""
	var sprite: String = ""

	func _init(data: Dictionary):
		group = data.get("group", "")
		sprite = data.get("sprite", "")

	func get_data() -> Dictionary:
		var result = {}
		if group != "":
			result["group"] = group
		if sprite != "":
			result["sprite"] = sprite
		return result

# Disassembly Property
class Disassembly:
	var group: String = ""
	var sprite: String = ""

	func _init(data: Dictionary):
		group = data.get("group", "")
		sprite = data.get("sprite", "")

	func get_data() -> Dictionary:
		var result = {}
		if group != "":
			result["group"] = group
		if sprite != "":
			result["sprite"] = sprite
		return result


# Crafting Property
class Crafting:
	var items: Array = []

	# Constructor to initialize crafting data from a dictionary
	func _init(data: Dictionary):
		items = data.get("items", [])

	# Get data function to return a dictionary with all properties
	func get_data() -> Dictionary:
		return {"items": items} if items.size() > 0 else {}


# Construction Property
class Construction:
	var items: Dictionary = {}

	# Constructor to initialize construction data from a dictionary
	func _init(data: Dictionary):
		items = data.get("items", {})  # Initialize as an empty dictionary if not present

	# Get data function to return a dictionary with all properties
	func get_data() -> Dictionary:
		return {"items": items} if items.size() > 0 else {}

	# Get items function to return the dictionary of items
	func get_items() -> Dictionary:
		return items

	# Add an item with the required amount
	func add_item(item_id: String, amount: int) -> void:
		items[item_id] = amount

	# Remove an item by ID
	func remove_item(item_id: String) -> void:
		items.erase(item_id)


# -------------------------------
# Initialization
# -------------------------------

func _init(data: Dictionary, myparent: DFurnitures):
	parent = myparent
	_initialize_properties(data)

func _initialize_properties(data: Dictionary):
	id = data.get("id", "")
	name = data.get("name", "")
	description = data.get("description", "")
	categories = data.get("categories", [])
	moveable = data.get("moveable", false)
	weight = data.get("weight", 1.0)
	edgesnapping = data.get("edgesnapping", "")
	spriteid = data.get("sprite", "")
	sprite = null  # Sprite is loaded lazily if required
	function = Function.new(data.get("Function", {}))
	support_shape = SupportShape.new(data.get("support_shape", {}))
	destruction = Destruction.new(data.get("destruction", {}))
	disassembly = Disassembly.new(data.get("disassembly", {}))
	crafting = Crafting.new(data.get("crafting", {}))  # Initialize Crafting inner class
	construction = Construction.new(data.get("construction", {}))  # Initialize Construction with a dictionary

# -------------------------------
# Data Retrieval
# -------------------------------

func get_data() -> Dictionary:
	var result = {
		"id": id,
		"name": name,
		"description": description,
		"categories": categories,
		"moveable": moveable,
		"edgesnapping": edgesnapping,
		"sprite": spriteid
	}
	# Save the weight only if moveable true, otherwise erase it.
	if moveable:
		result["weight"] = weight
	else: # Support shape only applies to static furniture
		result["support_shape"] = support_shape.get_data()

	if not function.get_data().is_empty():
		result["Function"] = function.get_data()

	if not destruction.get_data().is_empty():
		result["destruction"] = destruction.get_data()

	if not disassembly.get_data().is_empty():
		result["disassembly"] = disassembly.get_data()

	if not crafting.get_data().is_empty(): # Add crafting data if it exists
		result["crafting"] = crafting.get_data()

	if not construction.get_data().is_empty():  # Add construction data if it exists
		result["construction"] = construction.get_data()

	return result

func get_sprite_path() -> String:
	return parent.spritePath + spriteid

# -------------------------------
# Change Handlers
# -------------------------------

func on_data_changed(old_furniture: DFurniture):
	# Existing reference updates for container, destruction, and disassembly
	_update_references(old_furniture.function.container_group, function.container_group)
	_update_references(old_furniture.destruction.group, destruction.group)
	_update_references(old_furniture.disassembly.group, disassembly.group)

	# Handle crafting item references
	var old_items: Array = old_furniture.crafting.items
	var current_items: Array = crafting.items

	# Remove references for items no longer in the list
	for old_item in old_items:
		if old_item not in current_items:
			Gamedata.mods.remove_reference(DMod.ContentType.ITEMS, old_item, DMod.ContentType.FURNITURES, id)

	# Add references for new items
	for current_item in current_items:
		Gamedata.mods.add_reference(DMod.ContentType.ITEMS, current_item, DMod.ContentType.FURNITURES, id)

	# Handle construction item references
	old_items = old_furniture.construction.items.keys()  # Get old construction item IDs
	current_items = construction.items.keys()  # Get current construction item IDs

	# Remove references for items no longer in the list
	for old_item in old_items:
		if old_item not in current_items:
			Gamedata.mods.remove_reference(DMod.ContentType.ITEMS, old_item, DMod.ContentType.FURNITURES, id)

	# Add references for new items
	for current_item in current_items:
		Gamedata.mods.add_reference(DMod.ContentType.ITEMS, current_item, DMod.ContentType.FURNITURES, id)


func _update_references(old_value: String, new_value: String):
	if old_value != new_value:
		if old_value != "":
			Gamedata.mods.remove_reference(DMod.ContentType.ITEMGROUPS, old_value, DMod.ContentType.FURNITURES, id)
		if new_value != "":
			Gamedata.mods.add_reference(DMod.ContentType.ITEMGROUPS, new_value, DMod.ContentType.FURNITURES, id)

# -------------------------------
# Deletion and Cleanup
# -------------------------------

func delete():
	# Check to see if any mod has a copy of this furniture. If one or more remain, we can keep references
	var all_results: Array = Gamedata.mods.get_all_content_by_id(DMod.ContentType.FURNITURES, id)
	if all_results.size() > 1:
		parent.remove_reference(id)  # Erase the reference for the ID in this mod
		return

	_remove_references("container_group", function.container_group)
	_remove_references("destruction_group", destruction.group)
	_remove_references("disassembly_group", disassembly.group)

	# Remove item references for crafting items
	for item in crafting.items:
		Gamedata.mods.remove_reference(DMod.ContentType.ITEMS, item, DMod.ContentType.FURNITURES, id)

	# Remove from all referencing maps
	for map_id in parent.references.get(id, {}).get("maps", []):
		for map_data: DMap in Gamedata.mods.get_all_content_by_id(DMod.ContentType.MAPS, map_id):
			map_data.remove_entity_from_map("furniture", id)


func _remove_references(_reference_type: String, value: String):
	if value != "":
		Gamedata.mods.remove_reference(DMod.ContentType.ITEMGROUPS, value, DMod.ContentType.FURNITURES, id)

# -------------------------------
# Utility Functions
# -------------------------------

func remove_itemgroup(itemgroup_id: String):
	if function.container_group == itemgroup_id:
		function.container_group = ""
	if destruction.group == itemgroup_id:
		destruction.group = ""
	if disassembly.group == itemgroup_id:
		disassembly.group = ""
	parent.save_furnitures_to_disk()

# Removes an item by its ID from crafting.items and updates references
func remove_item_from_crafting(item_id: String):
	if item_id in crafting.items:
		# Remove the reference
		Gamedata.mods.remove_reference(DMod.ContentType.ITEMS, item_id, DMod.ContentType.FURNITURES, id)
		# Remove the item from the crafting list
		crafting.items.erase(item_id)
		# Save the updated furniture state
		parent.save_furnitures_to_disk()

# Removes an item by its ID from construction.items and updates references
func remove_item_from_construction(item_id: String):
	if item_id in construction.items:
		# Remove the reference
		Gamedata.mods.remove_reference(DMod.ContentType.ITEMS, item_id, DMod.ContentType.FURNITURES, id)
		# Remove the item from the construction list
		construction.remove_item(item_id)
		# Save the updated furniture state
		parent.save_furnitures_to_disk()
