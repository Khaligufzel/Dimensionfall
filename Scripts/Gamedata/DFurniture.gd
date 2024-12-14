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
var parent: DFurnitures


# Inner class to handle the Function property
class Function:
	var door: String  # Can be "None", "Open" or "Closed"
	var is_container: bool
	var container_group: String
	var container_regeneration_time: float  # Time in days for container regeneration (-1.0 if it doesn't regenerate)

	# Constructor to initialize function properties from a dictionary
	func _init(data: Dictionary):
		door = data.get("door", "None")
		is_container = data.get("is_container", false)
		container_group = data.get("container_group", "")
		container_regeneration_time = data.get("container_regeneration_time", -1.0)  # Default to -1.0

	# Get data function to return a dictionary with all properties
	func get_data() -> Dictionary:
		var functiondata: Dictionary = {}
		if is_container:
			functiondata["is_container"] = is_container
			if not container_group == "":
				functiondata["container_group"] = container_group
			if container_regeneration_time != -1:  # Only include if not the default
				functiondata["container_regeneration_time"] = container_regeneration_time
		if not door == "None":
			functiondata["door"] = door
		return functiondata  # Potentially return an empty dictionary


# Inner class to handle the Support Shape property
class SupportShape:
	var color: String
	var depth_scale: float
	var height: float
	var shape: String
	var transparent: bool
	var width_scale: float
	var radius_scale: float

	# Constructor to initialize support shape properties from a dictionary
	func _init(data: Dictionary):
		set_data(data)

	func set_data(data: Dictionary):
		color = data.get("color", "ffffffff")
		depth_scale = data.get("depth_scale", 100.0)
		height = data.get("height", 0.5)
		shape = data.get("shape", "Box")
		transparent = data.get("transparent", false)
		width_scale = data.get("width_scale", 100.0)
		radius_scale = data.get("radius_scale", 100.0)

	# Get data function to return a dictionary with all properties
	func get_data() -> Dictionary:
		var shapedata: Dictionary = {
			"color": color,
			"height": height,
			"shape": shape,
			"transparent": transparent
		}
		if shape == "Box":
			shapedata["width_scale"] = width_scale
			shapedata["depth_scale"] = depth_scale
		elif shape == "Cylinder":
			shapedata["radius_scale"] = radius_scale
		return shapedata


# Inner class to handle the Destruction property
class Destruction:
	var group: String
	var sprite: String

	# Constructor to initialize destruction properties from a dictionary
	func _init(data: Dictionary):
		group = data.get("group", "")
		sprite = data.get("sprite", "")

	# Get data function to return a dictionary with all properties
	func get_data() -> Dictionary:
		var destructiondata: Dictionary = {}
		if not group == "":
			destructiondata["group"] = group
		if not sprite == "":
			destructiondata["sprite"] = sprite
		return destructiondata # Potentially return an empty dictionary


# Inner class to handle the Disassembly property
class Disassembly:
	var group: String
	var sprite: String

	# Constructor to initialize disassembly properties from a dictionary
	func _init(data: Dictionary):
		group = data.get("group", "")
		sprite = data.get("sprite", "")

	# Get data function to return a dictionary with all properties
	func get_data() -> Dictionary:
		var disassemblydata: Dictionary = {}
		if not group == "":
			disassemblydata["group"] = group
		if not sprite == "":
			disassemblydata["sprite"] = sprite
		return disassemblydata # Potentially return an empty dictionary


# Constructor to initialize itemgroup properties from a dictionary
# myparent: The list containing all itemgroups for this mod
func _init(data: Dictionary, myparent: DFurnitures):
	parent = myparent
	id = data.get("id", 0)
	name = data.get("name", "")
	description = data.get("description", "")
	categories = data.get("categories", [])
	moveable = data.get("moveable", false)
	weight = data.get("weight", 1.0)
	edgesnapping = data.get("edgesnapping", "")
	spriteid = data.get("sprite", "")
	function = Function.new(data.get("Function", {}))  # Initialize Function inner class
	support_shape = SupportShape.new(data.get("support_shape", {}))  # Initialize SupportShape inner class
	destruction = Destruction.new(data.get("destruction", {}))  # Initialize Destruction inner class
	disassembly = Disassembly.new(data.get("disassembly", {}))  # Initialize Disassembly inner class


# Get data function to return a dictionary with all properties
func get_data() -> Dictionary:
	var data: Dictionary = {
		"id": id,
		"name": name,
		"description": description,
		"categories": categories,
		"moveable": moveable,
		"weight": weight,
		"edgesnapping": edgesnapping,
		"sprite": spriteid
	}
	# Save the weight only if moveable true, otherwise erase it.
	if moveable:
		data["weight"] = weight
	else: # Support shape only applies to static furniture
		data["support_shape"] = support_shape.get_data()
		
	var functiondata: Dictionary = function.get_data()
	if not functiondata.is_empty():
		data["Function"] = functiondata
		
	var destructiondata: Dictionary = destruction.get_data()
	if not destructiondata.is_empty():
		data["destruction"] = destructiondata
		
	var disassemblydata: Dictionary = disassembly.get_data()
	if not disassemblydata.is_empty():
		data["disassembly"] = disassemblydata
	return data


# Returns the path of the sprite
func get_sprite_path() -> String:
	return parent.spritePath + spriteid


# Handles furniture changes and updates references if necessary
func on_data_changed(olddfurniture: DFurniture):
	var old_container_group = olddfurniture.function.container_group
	var new_container_group = function.container_group
	var old_destruction_group = olddfurniture.destruction.group
	var old_disassembly_group = olddfurniture.disassembly.group

	if not old_container_group == new_container_group:
		# Remove from old group if necessary
		if old_container_group != "":
			Gamedata.mods.remove_reference(DMod.ContentType.ITEMGROUPS, old_container_group, DMod.ContentType.FURNITURES, id)
		if new_container_group != "":
			Gamedata.mods.add_reference(DMod.ContentType.ITEMGROUPS, new_container_group, DMod.ContentType.FURNITURES, id)
		
	if not old_destruction_group == destruction.group:
		# Remove from old group if necessary
		if old_destruction_group != "":
			Gamedata.mods.remove_reference(DMod.ContentType.ITEMGROUPS, old_destruction_group, DMod.ContentType.FURNITURES, id)
		if destruction.group != "":
			Gamedata.mods.add_reference(DMod.ContentType.ITEMGROUPS, destruction.group, DMod.ContentType.FURNITURES, id)
		
	if not old_disassembly_group == disassembly.group:
		# Remove from old group if necessary
		if old_disassembly_group != "":
			Gamedata.mods.remove_reference(DMod.ContentType.ITEMGROUPS, old_disassembly_group, DMod.ContentType.FURNITURES, id)
		if disassembly.group != "":
			Gamedata.mods.add_reference(DMod.ContentType.ITEMGROUPS, disassembly.group, DMod.ContentType.FURNITURES, id)


# Some furniture is being deleted from the data
# We have to remove it from everything that references it
func delete():
	Gamedata.mods.remove_reference(DMod.ContentType.ITEMGROUPS, function.container_group, DMod.ContentType.FURNITURES, id)
	Gamedata.mods.remove_reference(DMod.ContentType.ITEMGROUPS, destruction.group, DMod.ContentType.FURNITURES, id)
	Gamedata.mods.remove_reference(DMod.ContentType.ITEMGROUPS, disassembly.container_group, DMod.ContentType.FURNITURES, id)
	
	# Get a list of all maps that reference this mob
	var myreferences: Dictionary = parent.references.get(id, {})
	var mapsdata: Array = myreferences.get("maps", [])
	
	# Remove references to maps
	for mymap: String in mapsdata:
		var mymaps: Array = Gamedata.mods.get_all_content_by_id(DMod.ContentType.MAPS, mymap)
		for dmap: DMap in mymaps: # Loop over every DMap instance in every mod that has the same id as mymap
			dmap.remove_entity_from_map("furniture", id)


# Removes any instance of an itemgroup from the furniture
func remove_itemgroup(itemgroup_id: String) -> void:
	if function.container_group == itemgroup_id:
		function.container_group = ""
	if destruction.group == itemgroup_id:
		destruction.group = ""
	if disassembly.group == itemgroup_id:
		disassembly.group = ""
	parent.save_furnitures_to_disk()
