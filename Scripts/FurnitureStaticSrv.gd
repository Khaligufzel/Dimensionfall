class_name FurnitureStaticSrv
extends Node3D

# Variables to store furniture data
var furniture_position: Vector3
var furnitureJSON: Dictionary
var dfurniture: DFurniture
var collider: RID
var shape: RID

# Function to initialize the furniture object
func _init(furniturepos: Vector3, newFurnitureJSON: Dictionary, world3d):
	furniture_position = furniturepos
	furnitureJSON = newFurnitureJSON
	dfurniture = Gamedata.furnitures.by_id(furnitureJSON.id)
	
	if is_new_furniture():
		furniture_position.y += 1.025 # Move the furniture to slightly above the block

	create_box_shape(Vector3(1,1,1), world3d)  # Example size


# Function to create a BoxShape3D collider based on the given size
func create_box_shape(size: Vector3, world3d):
	shape = PhysicsServer3D.box_shape_create()
	PhysicsServer3D.shape_set_data(shape, Vector3(size.x / 2.0, size.y / 2.0, size.z / 2.0))
	
	collider = PhysicsServer3D.body_create()
	PhysicsServer3D.body_set_mode(collider, PhysicsServer3D.BODY_MODE_STATIC)
	# Set space, so it collides in the same space as current scene.
	PhysicsServer3D.body_set_space(collider, world3d.space)
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

# Helper function to determine if the furniture is new
func is_new_furniture() -> bool:
	return not furnitureJSON.has("global_position_x")
