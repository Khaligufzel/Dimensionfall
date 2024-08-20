class_name FurniturePhysicsSrv
extends Node3D

var furniture_position: Vector3 = Vector3()
var furniture_rotation: int
var furnitureJSON: Dictionary
var dfurniture: DFurniture
var collider: RID
var shape: RID
var mesh_instance: RID
var sprite_instance: RID
var myworld3d: World3D
var current_chunk: Chunk
var in_starting_chunk: bool = false
var container: ContainerItem = null
var elapsed_time: float = 0.0
var is_animating_hit: bool = false
var current_health: float = 10.0

# Initialize the furniture object
func _init(furniturepos: Vector3, newFurnitureJSON: Dictionary, world3d: World3D):
	furniture_position = furniturepos
	furnitureJSON = newFurnitureJSON
	dfurniture = Gamedata.furnitures.by_id(furnitureJSON.id)
	myworld3d = world3d

	setup_physics_properties(dfurniture.weight)
	create_visual_instance(dfurniture.sprite)
	set_new_rotation(furnitureJSON.get("rotation", 0))

func _ready() -> void:
	pass
	# If needed, add additional initialization logic here

# Setup the physics properties of the furniture
func setup_physics_properties(weight: float) -> void:
	shape = PhysicsServer3D.box_shape_create()
	PhysicsServer3D.shape_set_data(shape, Vector3(0.5, 0.5, 0.5))  # Example size, adjust as needed
	
	collider = PhysicsServer3D.body_create()
	PhysicsServer3D.body_set_mode(collider, PhysicsServer3D.BODY_MODE_RIGID)
	PhysicsServer3D.body_set_space(collider, myworld3d.space)
	PhysicsServer3D.body_add_shape(collider, shape)
	PhysicsServer3D.body_set_state(collider, PhysicsServer3D.BODY_STATE_TRANSFORM, Transform3D(Basis(), furniture_position))
	
	PhysicsServer3D.body_set_param(collider, PhysicsServer3D.BODY_PARAM_MASS, weight)
	PhysicsServer3D.body_set_param(collider, PhysicsServer3D.BODY_PARAM_LINEAR_DAMP, 59)
	PhysicsServer3D.body_set_param(collider, PhysicsServer3D.BODY_PARAM_ANGULAR_DAMP, 59)

	set_collision_layers_and_masks()

	# Set the force integration callback to update the visual position
	PhysicsServer3D.body_set_force_integration_callback(collider, Callable(self, "_moved"), furniture_position)


# Handle movement logic when the furniture changes position
func _moved(state: PhysicsDirectBodyState3D) -> void:
	# Get the new position from the physics state
	var new_position = state.transform.origin

	# Update the internal furniture position
	furniture_position = new_position

	# Update the visual instance position to match the collider's position
	RenderingServer.instance_set_transform(mesh_instance, Transform3D(Basis(), new_position))

	# Handle chunk updates (if necessary)
	var new_chunk = Helper.map_manager.get_chunk_from_position(new_position)
	if not current_chunk == new_chunk:
		if current_chunk:
			current_chunk.remove_furniture_from_chunk(self)
		new_chunk.add_furniture_to_chunk(self)
		current_chunk = new_chunk


# Set collision layers and masks
func set_collision_layers_and_masks():
	
	# Set collision layer to layer 4 (moveable obstacles layer) and 7 (containers layer)
	var collision_layer = 1 << 3 | (1 << 6)  # Layer 4 is 1 << 3, Layer 7 is 1 << 6

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

# Create the visual instance using RenderingServer
func create_visual_instance(new_sprite: Texture) -> void:
	var material = StandardMaterial3D.new()
	material.albedo_texture = new_sprite
	
	var mesh = PlaneMesh.new()
	mesh.size = Vector2(1.0, 1.0)  # Example size, adjust to the actual sprite size
	mesh.material = material
	
	mesh_instance = RenderingServer.instance_create()
	RenderingServer.instance_set_base(mesh_instance, mesh)
	#RenderingServer.instance_set_material(mesh_instance, material)
	RenderingServer.instance_set_scenario(mesh_instance, myworld3d.scenario)
	RenderingServer.instance_set_transform(mesh_instance, Transform3D(Basis(), furniture_position))
	
	

# Set the new rotation for the furniture
func set_new_rotation(amount: int) -> void:
	var rotation_amount = amount
	if amount == 180:
		rotation_amount -= 180
	elif amount == 0:
		rotation_amount += 180
	
	var mytransform = PhysicsServer3D.body_get_state(collider, PhysicsServer3D.BODY_STATE_TRANSFORM)
	mytransform.basis = Basis(Vector3(0, 1, 0), deg_to_rad(rotation_amount))
	PhysicsServer3D.body_set_state(collider, PhysicsServer3D.BODY_STATE_TRANSFORM, mytransform)
	
	RenderingServer.instance_set_transform(mesh_instance, transform)



# Clean up and free resources
func free_resources() -> void:
	PhysicsServer3D.free_rid(collider)
	PhysicsServer3D.free_rid(shape)
	RenderingServer.free_rid(mesh_instance)

# Other methods such as get_data(), animate_hit(), and get_hit() would be adapted similarly
