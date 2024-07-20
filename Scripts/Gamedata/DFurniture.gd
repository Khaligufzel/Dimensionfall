class_name DFurniture
extends RefCounted

# There's a D in front of the class name to indicate this class only handles map data, nothing more
# This script is intended to be used inside the GameData autoload singleton
# This script handles the data for one furniture. You can access it through Gamedata.furnitures

# This class represents a piece of furniture with its properties
var id: int
var name: String
var description: String
var categories: Array
var moveable: bool
var weight: float
var edgesnapping: String
var sprite: String
var function_data: Function
var support_shape_data: SupportShape
var destruction: Destruction
var disassembly: Disassembly

# Inner class to handle the Function property
class Function:
	var door: String
	var container_itemgroup: String

	# Constructor to initialize function properties from a dictionary
	func _init(data: Dictionary):
		door = data.get("door", "None")
		container_itemgroup = data.get("container", {}).get("itemgroup", "")

# Inner class to handle the Support Shape property
class SupportShape:
	var color: String
	var depth_scale: float
	var height: float
	var shape: String
	var transparent: bool
	var width_scale: float

	# Constructor to initialize support shape properties from a dictionary
	func _init(data: Dictionary):
		color = data.get("color", "ffffffff")
		depth_scale = data.get("depth_scale", 0.0)
		height = data.get("height", 0.0)
		shape = data.get("shape", "Box")
		transparent = data.get("transparent", false)
		width_scale = data.get("width_scale", 0.0)

# Inner class to handle the Destruction property
class Destruction:
	var group: String
	var sprite: String

	# Constructor to initialize destruction properties from a dictionary
	func _init(data: Dictionary):
		group = data.get("group", "")
		sprite = data.get("sprite", "")

# Inner class to handle the Disassembly property
class Disassembly:
	var group: String
	var sprite: String

	# Constructor to initialize disassembly properties from a dictionary
	func _init(data: Dictionary):
		group = data.get("group", "")
		sprite = data.get("sprite", "")

# Constructor to initialize furniture properties from a dictionary
func _init(data: Dictionary):
	id = data.get("id", 0)
	name = data.get("name", "")
	description = data.get("description", "")
	categories = data.get("categories", [])
	moveable = data.get("moveable", false)
	weight = data.get("weight", 0.0)
	edgesnapping = data.get("edgesnapping", "")
	sprite = data.get("sprite", "")
	function_data = Function.new(data.get("Function", {}))  # Initialize Function inner class
	support_shape_data = SupportShape.new(data.get("support_shape", {}))  # Initialize SupportShape inner class
	destruction = Destruction.new(data.get("destruction", {}))  # Initialize Destruction inner class
	disassembly = Disassembly.new(data.get("disassembly", {}))  # Initialize Disassembly inner class
