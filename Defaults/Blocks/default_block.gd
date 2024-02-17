class_name DefaultBlock
extends StaticBody3D

var blockposition: Vector3
var tileJSON: Dictionary # The json that defines this block
var shape: String = "block"


func _ready():
	position = blockposition
	apply_block_rotation()


func update_texture(material: BaseMaterial3D) -> void:
	$MeshInstance3D.mesh = BoxMesh.new()
	$MeshInstance3D.mesh.surface_set_material(0, material)
	
func get_texture_string() -> String:
	return $MeshInstance3D.mesh.material.albedo_texture.resource_path


# Function to make it's own shape and texture based on an id and position
# This function is called by a Chunk to construct it's blocks
func construct_self(blockpos: Vector3, newTileJSON: Dictionary):
	tileJSON = newTileJSON
	blockposition = blockpos

	# Get the shape of the block
	var tileJSONData = Gamedata.get_data_by_id(Gamedata.data.tiles,tileJSON.id)
	if tileJSONData.has("shape"):
		if tileJSONData.shape == "slope":
			shape = "slope"
	
	create_mesh()
	create_collider()


func create_mesh():
	var blockmeshisntance = MeshInstance3D.new()
	var blockmesh
	if shape == "block":
		blockmesh = BoxMesh.new()
	else: # It's a slope
		blockmesh = PrismMesh.new()
		blockmesh.left_to_right = 1
	blockmeshisntance.mesh = blockmesh
	blockmesh.surface_set_material(0, Gamedata.get_sprite_by_id(Gamedata.data.tiles,tileJSON.id))
	add_child.call_deferred(blockmeshisntance)


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


# When the map is created for the first time, we will apply block rotation
# This function will not be called when a map is loaded
func apply_block_rotation():
	var defaultRotation: int = 0
	# Only previously saved blocks have the block_x property, so we don't need to apply default rotation again
	if shape == "slope" and not tileJSON.has("block_x"):
		defaultRotation = 90
	# The slope has a default rotation of 90
	# The block has a default rotation of 0
	var myRotation: int = tileJSON.get("rotation", 0) + defaultRotation
	if myRotation == 0:
		# Only the block will match this case, not the slope. The block points north
		rotation_degrees = Vector3(0,myRotation+180,0)
	elif myRotation == 90:
		# A slope will point north
		# A block will point east
		rotation_degrees = Vector3(0,myRotation+0,0)
	elif myRotation == 180:
		# A block will point south
		# A slope will point east
		rotation_degrees = Vector3(0,myRotation-180,0)
	elif myRotation == 270:
		# A block will point west
		# A slope will point south
		rotation_degrees = Vector3(0,myRotation+0,0)
	elif myRotation == 360:
		# Only a slope can match this case
		rotation_degrees = Vector3(0,myRotation-180,0)
