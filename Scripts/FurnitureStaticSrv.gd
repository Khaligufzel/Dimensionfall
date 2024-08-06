class_name FurnitureStaticSrv
extends Node3D # Has to be Node3D. Changing it to RefCounted doesn't work

# Variables to store furniture data
var furniture_position: Vector3
var furnitureJSON: Dictionary
var dfurniture: DFurniture
var collider: RID
var shape: RID
var mesh_instance: RID  # Variable to store the mesh instance RID
var myworld3d: World3D

# We have to keep a reference or it will be auto deleted
# TODO: We still have to manually delete the RID's
var box_mesh: BoxMesh
var boxrid: RID

# Function to initialize the furniture object
func _init(furniturepos: Vector3, newFurnitureJSON: Dictionary, world3d: World3D):
	furniture_position = furniturepos
	furnitureJSON = newFurnitureJSON
	dfurniture = Gamedata.furnitures.by_id(furnitureJSON.id)
	myworld3d = world3d
	
	if is_new_furniture():
		furniture_position.y += 0.525 # Move the furniture to slightly above the block

	create_box_shape(Vector3(0.5, 0.5, 0.5))  # Example size
	create_visual_instance(Vector3(0.5, 0.5, 0.5))  # Example size

# Function to create a BoxShape3D collider based on the given size
func create_box_shape(size: Vector3):
	shape = PhysicsServer3D.box_shape_create()
	PhysicsServer3D.shape_set_data(shape, Vector3(size.x / 2.0, size.y / 2.0, size.z / 2.0))
	
	collider = PhysicsServer3D.body_create()
	PhysicsServer3D.body_set_mode(collider, PhysicsServer3D.BODY_MODE_STATIC)
	# Set space, so it collides in the same space as current scene.
	PhysicsServer3D.body_set_space(collider, myworld3d.space)
	PhysicsServer3D.body_add_shape(collider, shape)
	PhysicsServer3D.body_set_state(collider, PhysicsServer3D.BODY_STATE_TRANSFORM, Transform3D(Basis(), furniture_position))
	set_collision_layers_and_masks()

# Function to set collision layers and masks
func set_collision_layers_and_masks():
	# Set collision layer to layer 3 (static obstacles layer)
	var collision_layer = 1 << 2  # Layer 3 is 1 << 2

	# Set collision mask to include layers 1, 2, 3, 4, 5, and 6
	var collision_mask = (1 << 0) | (1 << 1) | (1 << 2) | (1 << 3) | (1 << 4) | (1 << 5)
	# Explanation:
	# - 1 << 0: Layer 1 (player layer)
	# - 1 << 1: Layer 2 (enemy layer)
	# - 1 << 2: Layer 3 (movable obstacles layer)
	# - 1 << 3: Layer 4 (static obstacles layer)
	# - 1 << 4: Layer 5 (friendly projectiles layer)
	# - 1 << 5: Layer 6 (enemy projectiles layer)
	
	PhysicsServer3D.body_set_collision_layer(collider, collision_layer)
	PhysicsServer3D.body_set_collision_mask(collider, collision_mask)

# Function to create a visual instance with a mesh to represent the box shape
func create_visual_instance(size: Vector3):
	var color = Color.html(dfurniture.support_shape.color)
	
	box_mesh = BoxMesh.new()
	boxrid = box_mesh.get_rid()
	box_mesh.size = size
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	box_mesh.material = material
	var meshSurface: Dictionary = RenderingServer.mesh_get_surface(boxrid,0)
	meshSurface["material"] =  material.get_rid()
	
	var newmesh: RID = RenderingServer.mesh_create_from_surfaces([meshSurface])
	
	# Create the mesh instance using the RenderingServer
	mesh_instance = RenderingServer.instance_create2(newmesh,myworld3d.get_scenario())

	# Set the transform for the mesh instance to match the furniture position
	RenderingServer.instance_set_transform(mesh_instance, Transform3D(Basis(), furniture_position))


# Helper function to determine if the furniture is new
func is_new_furniture() -> bool:
	return not furnitureJSON.has("global_position_x")
