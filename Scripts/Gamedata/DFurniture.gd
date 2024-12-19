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
#		"weight": 1
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
var parent: DFurnitures

# -------------------------------
# Inner Classes for Nested Data
# -------------------------------

# Function Property
class Function:
	var door: String = "None"  # Can be "None", "Open" or "Closed"
	var is_container: bool = false
	var container_group: String = ""
	var container_regeneration_time: float = DEFAULT_CONTAINER_REGEN   # Time in days for container regeneration (-1.0 if it doesn't regenerate)

	func _init(data: Dictionary):
		door = data.get("door", "None")
		is_container = data.get("is_container", false)
		container_group = data.get("container_group", "")
		container_regeneration_time = data.get("container_regeneration_time", DEFAULT_CONTAINER_REGEN)

	# Get data function to return a dictionary with all properties
	func get_data() -> Dictionary:
		var result = {}
		if is_container:
			result["is_container"] = is_container
			if container_group != "":
				result["container_group"] = container_group
			if container_regeneration_time != DEFAULT_CONTAINER_REGEN:
				result["container_regeneration_time"] = container_regeneration_time
		if door != "None":
			result["door"] = door
		return result # Potentially return an empty dictionary

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
	var items: Array[String] = []

	# Constructor to initialize crafting data from a dictionary
	func _init(data: Dictionary):
		items = data.get("items", [])

	# Get data function to return a dictionary with all properties
	func get_data() -> Dictionary:
		return {"items": items}

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

	return result

func get_sprite_path() -> String:
	return parent.spritePath + spriteid

# -------------------------------
# Change Handlers
# -------------------------------

func on_data_changed(old_furniture: DFurniture):
	_update_references("container_group", old_furniture.function.container_group, function.container_group)
	_update_references("destruction_group", old_furniture.destruction.group, destruction.group)
	_update_references("disassembly_group", old_furniture.disassembly.group, disassembly.group)

func _update_references(reference_type: String, old_value: String, new_value: String):
	if old_value != new_value:
		if old_value != "":
			Gamedata.mods.remove_reference(DMod.ContentType.ITEMGROUPS, old_value, DMod.ContentType.FURNITURES, id)
		if new_value != "":
			Gamedata.mods.add_reference(DMod.ContentType.ITEMGROUPS, new_value, DMod.ContentType.FURNITURES, id)

# -------------------------------
# Deletion and Cleanup
# -------------------------------

func delete():
	_remove_references("container_group", function.container_group)
	_remove_references("destruction_group", destruction.group)
	_remove_references("disassembly_group", disassembly.group)

	# Remove from all referencing maps
	for map_id in parent.references.get(id, {}).get("maps", []):
		 # Loop over every DMap instance in every mod that has the same id as map_id
		for map_data: DMap in Gamedata.mods.get_all_content_by_id(DMod.ContentType.MAPS, map_id):
			map_data.remove_entity_from_map("furniture", id)

func _remove_references(reference_type: String, value: String):
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
