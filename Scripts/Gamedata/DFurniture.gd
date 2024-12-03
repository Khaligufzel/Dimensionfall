class_name DFurniture
extends RefCounted

# There's a D in front of the class name to indicate this class only handles furniture data, nothing more
# This script is intended to be used inside the GameData autoload singleton
# This script handles the data for one furniture. You can access it through Gamedata.furnitures

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
var references: Dictionary = {}


# Inner class to handle the Function property
class Function:
	var door: String # Can be "None", "Open" or "Closed"
	var is_container: bool
	var container_group: String

	# Constructor to initialize function properties from a dictionary
	func _init(data: Dictionary):
		door = data.get("door", "None")
		is_container = data.get("is_container", false)
		container_group = data.get("container_group", "")

	# Get data function to return a dictionary with all properties
	func get_data() -> Dictionary:
		var functiondata: Dictionary = {}
		if is_container:
			functiondata["is_container"] = is_container
			if not container_group == "":
				functiondata["container_group"] = container_group
		if not door == "None":
			functiondata["door"] = door
		return functiondata # Potentially return an empty dictionary


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


# Constructor to initialize furniture properties from a dictionary
func _init(data: Dictionary):
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
	references = data.get("references", {})


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
	
	if not references.is_empty():
		data["references"] = references
	return data


# Removes the provided reference from references
# For example, remove "grass_field" to references.Core.maps
# module: the mod that the entity belongs to, for example "Core"
# type: The type of entity, for example "maps"
# refid: The id of the entity, for example "grass_field"
func remove_reference(module: String, type: String, refid: String):
	var changes_made = Gamedata.dremove_reference(references, module, type, refid)
	if changes_made:
		Gamedata.furnitures.save_furnitures_to_disk()


# Adds a reference to the references list
# For example, add "grass_field" to references.Core.maps
# module: the mod that the entity belongs to, for example "Core"
# type: The type of entity, for example "maps"
# refid: The id of the entity, for example "grass_field"
func add_reference(module: String, type: String, refid: String):
	var changes_made = Gamedata.dadd_reference(references, module, type, refid)
	if changes_made:
		Gamedata.furnitures.save_furnitures_to_disk()


# Returns the path of the sprite
func get_sprite_path() -> String:
	return Gamedata.furnitures.spritePath + spriteid


# Handles furniture changes and updates references if necessary
func on_data_changed(olddfurniture: DFurniture):
	var old_container_group = olddfurniture.function.container_group
	var new_container_group = function.container_group
	var old_destruction_group = olddfurniture.destruction.group
	var old_disassembly_group = olddfurniture.disassembly.group

	# Handle container itemgroup changes
	Gamedata.itemgroups.update_reference(old_container_group, new_container_group, "furniture", id)

	# Handle destruction group changes
	Gamedata.itemgroups.update_reference(old_destruction_group, destruction.group, "furniture", id)

	# Handle disassembly group changes
	Gamedata.itemgroups.update_reference(old_disassembly_group, disassembly.group, "furniture", id)


# Some furniture is being deleted from the data
# We have to remove it from everything that references it
func delete():
	Gamedata.itemgroups.remove_reference(function.container_group, "core", "furniture", id)
	Gamedata.itemgroups.remove_reference(destruction.group, "core", "furniture", id)
	Gamedata.itemgroups.remove_reference(disassembly.group, "core", "furniture", id)
	
	# Remove references to maps
	var mapsdata: Array = Helper.json_helper.get_nested_data(references, "core.maps")
	for mymap: String in mapsdata:
		var mymaps: Array = Gamedata.mods.get_all_content_by_id(DMod.ContentType.MAPS, mymap)
		for dmap: DMaps in mymaps:
			dmap.remove_entity_from_selected_maps("furniture", id, mapsdata)


# Removes any instance of an itemgroup from the furniture
func remove_itemgroup(itemgroup_id: String) -> void:
	if function.container_group == itemgroup_id:
		function.container_group = ""
	if destruction.group == itemgroup_id:
		destruction.group = ""
	if disassembly.group == itemgroup_id:
		disassembly.group = ""
	Gamedata.furnitures.save_furnitures_to_disk()
