class_name DefaultBlock
extends StaticBody3D

var blockposition: Vector3
var tileJSON: Dictionary # The json that defines this block
var shape: String = "block"
var blockmeshinstance: MeshInstance3D # Reference to the MeshInstance3D


func _ready():
	position = blockposition
	rotation_degrees = Vector3(0,get_block_rotation(),0)
	#apply_block_rotation()


# Function to make it's own shape and texture based on an id and position
# This function is called by a Chunk to construct it's blocks
func construct_self(blockpos: Vector3, newTileJSON: Dictionary):
	tileJSON = newTileJSON
	blockposition = blockpos
	disable_mode = CollisionObject3D.DISABLE_MODE_MAKE_STATIC
	# Set collision layer to layer 1 and 5
	collision_layer = 1 | (1 << 4) # Layer 1 is 1, Layer 5 is 1 << 4 (16), combined with bitwise OR
	# Set collision mask to layer 1
	collision_mask = 1 # Layer 1 is 1

	# Get the shape of the block
	var tileJSONData = Gamedata.get_data_by_id(Gamedata.data.tiles,tileJSON.id)
	if tileJSONData.has("shape"):
		if tileJSONData.shape == "slope":
			shape = "slope"
	
	create_mesh()
	create_collider()


func create_mesh():
	blockmeshinstance = MeshInstance3D.new()
	var blockmesh = Helper.get_or_create_block_mesh(tileJSON.id, shape)
	blockmeshinstance.mesh = blockmesh
	add_child.call_deferred(blockmeshinstance)


func create_collider():
	var collider = CollisionShape3D.new()
	if shape == "block":
		collider.shape = BoxShape3D.new()
	else: # It's a slope
		collider.shape = ConvexPolygonShape3D.new()
		collider.shape.points = [
			Vector3(0.5, 0.5, 0.5),
			Vector3(0.5, 0.5, -0.5),
			Vector3(-0.5, -0.5, 0.5),
			Vector3(0.5, -0.5, 0.5),
			Vector3(0.5, -0.5, -0.5),
			Vector3(-0.5, -0.5, -0.5)
		]

	add_child.call_deferred(collider)


func get_block_rotation() -> int:
	var defaultRotation: int = 0
	# Only previously saved blocks have the block_x property, so we don't need to apply default rotation again
	if shape == "slope" and not tileJSON.has("block_x"):
		defaultRotation = 90
	# The slope has a default rotation of 90
	# The block has a default rotation of 0
	var myRotation: int = tileJSON.get("rotation", 0) + defaultRotation
	# Hack to get previouly saved slopes into the right rotation
	if (myRotation == 0 or myRotation == 180) and shape == "slope" and tileJSON.has("block_x"):
		myRotation += 180
	if myRotation == 0:
		# Only the block will match this case, not the slope. The block points north
		return myRotation+180
	elif myRotation == 90:
		# A block will point east
		# A slope will point north
		return myRotation+0
	elif myRotation == 180:
		# A block will point south
		# A slope will point east
		return myRotation-180
	elif myRotation == 270:
		# A block will point west
		# A slope will point south
		return myRotation+0
	elif myRotation == 360:
		# Only a slope can match this case if it's rotation is 270 and it gets 90 rotation by default
		return myRotation-180
	return myRotation


func get_mesh() -> Mesh:
	if blockmeshinstance:
		return blockmeshinstance.mesh
	return null
