class_name DefaultBlock
extends StaticBody3D

var id: String = ""
var blockposition: Vector3

func _ready():
	position = blockposition


func update_texture(material: BaseMaterial3D) -> void:
	$MeshInstance3D.mesh = BoxMesh.new()
	$MeshInstance3D.mesh.surface_set_material(0, material)
	
func get_texture_string() -> String:
	return $MeshInstance3D.mesh.material.albedo_texture.resource_path


# Function to make it's own shape and texture based on an id and position
# This function is called by a Chunk to construct it's blocks
func construct_self(blockpos: Vector3, myid: String):
	id = myid
	blockposition = blockpos
	var shape: String = "block"
	
	# Get the shape of the block
	var tileJSONData = Gamedata.data.tiles
	var tileJSON = tileJSONData.data[Gamedata.get_array_index_by_id(tileJSONData,id)]
	if tileJSON.has("shape"):
		if tileJSON.shape == "slope":
			shape = "slope"
	
	create_mesh(shape)
	create_collider(shape)


func create_mesh(shape: String):
	var blockmeshisntance = MeshInstance3D.new()
	var blockmesh
	if shape == "block":
		blockmesh = BoxMesh.new()
	else: # It's a slope
		blockmesh = PrismMesh.new()
		blockmesh.left_to_right = 1
	blockmeshisntance.mesh = blockmesh
	blockmesh.surface_set_material(0, Gamedata.get_sprite_by_id(Gamedata.data.tiles,id))
	add_child.call_deferred(blockmeshisntance)


func create_collider(shape: String):
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
