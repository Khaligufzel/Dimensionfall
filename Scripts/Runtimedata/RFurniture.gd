class_name RFurniture
extends RefCounted

# This class represents furniture with its properties, only used while the game is running.
# Example furniture data:
# {
#     "id": "wooden_chair",
#     "name": "Wooden Chair",
#     "description": "A simple wooden chair.",
#     "categories": ["furniture", "wood"],
#     "moveable": true,
#     "weight": 5.0,
#     "edgesnapping": "none",
#     "Function": {
#         "door": "None",
#         "is_container": true,
#         "container_group": "basic_loot",
#         "container_regeneration_time": -1
#     },
#     "support_shape": {
#         "shape": "Box",
#         "width_scale": 100.0,
#         "depth_scale": 100.0,
#         "height": 1.0,
#         "transparent": false,
#         "color": "ffffffff"
#     },
#     "destruction": {
#         "group": "broken_wood",
#         "sprite": "broken_wood_32.png"
#     },
#     "disassembly": {
#         "group": "wood_parts",
#         "sprite": "wood_parts_32.png"
#     }
# }

# Inner class to handle the Function property
class Function:
	var door: String # Can be "None", "Open" or "Closed"
	var is_container: bool
	var container_group: String
	var container_regeneration_time: float  # Time in minutes for container regeneration (-1 if it doesn't regenerate)


	# Constructor to initialize function properties from a dictionary
	func _init(data: Dictionary):
		door = data.get("door", "None")
		is_container = data.get("is_container", false)
		container_group = data.get("container_group", "")
		container_regeneration_time = data.get("container_regeneration_time", -1.0)  # Default to -1

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
		return functiondata


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
		return destructiondata


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
		return disassemblydata

# Crafting Property
class Crafting:
	var items: Array = []

	# Constructor to initialize crafting data from a dictionary
	func _init(data: Dictionary):
		items = data.get("items", [])

	# Get data function to return a dictionary with all properties
	func get_data() -> Dictionary:
		return {"items": items} if items.size() > 0 else {}

# Properties defined in the furniture
var id: String
var name: String
var description: String
var categories: Array
var moveable: bool
var weight: float
var edgesnapping: String
var spriteid: String
var function: Function
var support_shape: SupportShape
var destruction: Destruction
var disassembly: Disassembly
var crafting: Crafting
var sprite: Texture
var parent: RFurnitures  # Reference to the list containing all runtime furnitures for this mod

# Constructor to initialize furniture properties
# myparent: The list containing all runtime furnitures for this mod
# newid: The ID of the furniture being created
func _init(myparent: RFurnitures, newid: String):
	parent = myparent
	id = newid

# Overwrite this furniture's properties using a DFurniture
func overwrite_from_dfurniture(dfurniture: DFurniture) -> void:
	if not id == dfurniture.id:
		print_debug("Cannot overwrite from a different id")
	name = dfurniture.name
	description = dfurniture.description
	categories = dfurniture.categories
	moveable = dfurniture.moveable
	weight = dfurniture.weight
	edgesnapping = dfurniture.edgesnapping
	spriteid = dfurniture.spriteid
	sprite = dfurniture.sprite
	function = Function.new(dfurniture.function.get_data())
	support_shape = SupportShape.new(dfurniture.support_shape.get_data())
	destruction = Destruction.new(dfurniture.destruction.get_data())
	disassembly = Disassembly.new(dfurniture.disassembly.get_data())
	crafting = Crafting.new(dfurniture.crafting.get_data())

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

	# Save the weight only if moveable true, otherwise add support shape.
	if moveable:
		data["weight"] = weight
	else:
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

	var craftingdata: Dictionary = crafting.get_data()
	if not craftingdata.is_empty():
		data["crafting"] = craftingdata

	return data
