class_name FurnitureStaticSrv
extends Node3D # Has to be Node3D. Changing it to RefCounted doesn't work

# Variables to store furniture data
var furniture_position: Vector3
var furniture_rotation: int
var furnitureJSON: Dictionary # The json that defines this furniture on the map
var dfurniture: DFurniture # The json that defines this furniture's basics in general
var collider: RID
var shape: RID
var mesh_instance: RID  # Variable to store the mesh instance RID
var myworld3d: World3D

# We have to keep a reference or it will be auto deleted
# TODO: We still have to manually delete the RID's
var support_mesh: PrimitiveMesh
var sprite_texture: Texture2D  # Variable to store the sprite texture
var quad_mesh: PlaneMesh

# Function to initialize the furniture object
func _init(furniturepos: Vector3, newFurnitureJSON: Dictionary, world3d: World3D):
	furniture_position = furniturepos
	furnitureJSON = newFurnitureJSON
	furniture_rotation = furnitureJSON.get("rotation", 0)
	dfurniture = Gamedata.furnitures.by_id(furnitureJSON.id)
	myworld3d = world3d

	sprite_texture = dfurniture.sprite
	var sprite_size = calculate_sprite_size()

	if is_new_furniture():
		furniture_position.y += 0.525 # Move the furniture to slightly above the block
		apply_edge_snapping_if_needed(sprite_size)

	set_new_rotation(furniture_rotation) # Apply rotation after setting up the shape and visual instance
	if dfurniture.support_shape.shape == "Box":
		create_box_shape(sprite_size)
		create_visual_instance(sprite_size, "Box")
	elif dfurniture.support_shape.shape == "Cylinder":
		create_cylinder_shape(Vector2(sprite_size.x, sprite_size.z))
		create_visual_instance(Vector3(sprite_size.x, dfurniture.support_shape.height, sprite_size.z), "Cylinder")

	create_sprite_instance(sprite_size)


# Function to calculate the size of the sprite
func calculate_sprite_size() -> Vector3:
	if sprite_texture:
		var sprite_width = sprite_texture.get_width() / 100.0 # Convert pixels to meters
		var sprite_height = sprite_texture.get_height() / 100.0 # Convert pixels to meters
		return Vector3(sprite_width, 0.5, sprite_height)  # Default height of 0.5 meters
	return Vector3(0.5, 0.5, 0.5)  # Default size if texture is not set


# Function to create a BoxShape3D collider based on the given size
func create_box_shape(size: Vector3):
	shape = PhysicsServer3D.box_shape_create()
	PhysicsServer3D.shape_set_data(shape, Vector3(size.x / 2.0, size.y / 2.0, size.z / 2.0))
	
	collider = PhysicsServer3D.body_create()
	PhysicsServer3D.body_set_mode(collider, PhysicsServer3D.BODY_MODE_STATIC)
	# Set space, so it collides in the same space as current scene.
	PhysicsServer3D.body_set_space(collider, myworld3d.space)
	PhysicsServer3D.body_add_shape(collider, shape)
	# Apply rotation to the transform
	var mytransform = Transform3D(Basis(Vector3(0, 1, 0), deg_to_rad(furniture_rotation)), furniture_position)
	PhysicsServer3D.body_set_state(collider, PhysicsServer3D.BODY_STATE_TRANSFORM, mytransform)
	set_collision_layers_and_masks()

# Function to create a CylinderShape3D collider based on the given size
func create_cylinder_shape(size: Vector2):
	shape = PhysicsServer3D.cylinder_shape_create()
	PhysicsServer3D.shape_set_data(shape, {"radius": size.x / 4.0, "height": dfurniture.support_shape.height})
	
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


# Function to create a visual instance with a mesh to represent the shape
func create_visual_instance(size: Vector3, shape_type: String):
	var color = Color.html(dfurniture.support_shape.color)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	if dfurniture.support_shape.transparent:
		material.flags_transparent = true
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	if shape_type == "Box":
		support_mesh = BoxMesh.new()
		(support_mesh as BoxMesh).size = size
	elif shape_type == "Cylinder":
		support_mesh = CylinderMesh.new()
		(support_mesh as CylinderMesh).height = size.y
		(support_mesh as CylinderMesh).top_radius = size.x / 4.0
		(support_mesh as CylinderMesh).bottom_radius = size.z / 4.0

	support_mesh.material = material

	mesh_instance = RenderingServer.instance_create()
	RenderingServer.instance_set_base(mesh_instance, support_mesh)
	
	RenderingServer.instance_set_scenario(mesh_instance, myworld3d.scenario)
	# Apply rotation to the transform
	var mytransform = Transform3D(Basis(Vector3(0, 1, 0), deg_to_rad(furniture_rotation)), furniture_position)
	RenderingServer.instance_set_transform(mesh_instance, mytransform)


# Function to create a QuadMesh to display the sprite texture on top of the furniture
func create_sprite_instance(size: Vector3):
	quad_mesh = PlaneMesh.new()
	quad_mesh.size = Vector2(size.x, size.z)
	var material = StandardMaterial3D.new()
	material.albedo_texture = sprite_texture
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	#material.flags_unshaded = true  # Optional: make the sprite unshaded
	quad_mesh.material = material
	
	var quad_instance = RenderingServer.instance_create()
	RenderingServer.instance_set_base(quad_instance, quad_mesh)
	RenderingServer.instance_set_scenario(quad_instance, myworld3d.scenario)
	
	# Set the transform for the quad instance to be slightly above the box mesh
	var mytransform = Transform3D(Basis(Vector3(0, 1, 0), deg_to_rad(furniture_rotation)), furniture_position + Vector3(0, 0.51, 0))  # Adjust the Y position as needed
	RenderingServer.instance_set_transform(quad_instance, mytransform)


# Function to apply edge snapping if necessary
func apply_edge_snapping_if_needed(size: Vector3):
	if not dfurniture.edgesnapping == "None":
		furniture_position = apply_edge_snapping(
			furniture_position, dfurniture.edgesnapping, 
			size, furniture_rotation, furniture_position
		)


# If edge snapping has been set in the furniture editor, we will apply it here.
# The direction refers to the 'backside' of the furniture, which will be facing the edge of the block
# This is needed to put furniture against the wall, or get a fence at the right edge
func apply_edge_snapping(newpos: Vector3, direction: String, size: Vector3, newRot: int, furniturepos: Vector3) -> Vector3:
	# Block size, a block is 1x1 meters
	var blockSize = Vector3(1.0, 1.0, 1.0)
	
	# Adjust position based on edgesnapping direction and rotation
	match direction:
		"North":
			newpos.z -= blockSize.z / 2 - size.z / 2
		"South":
			newpos.z += blockSize.z / 2 - size.z / 2
		"East":
			newpos.x += blockSize.x / 2 - size.x / 2
		"West":
			newpos.x -= blockSize.x / 2 - size.x / 2
		# Add more cases if needed
	
	# Consider rotation if necessary
	newpos = rotate_position_around_block_center(newpos, newRot, furniturepos)
	
	return newpos


# Called when applying edge-snapping so it's put into the right position
func rotate_position_around_block_center(newpos: Vector3, newRot: int, block_center: Vector3) -> Vector3:
	# Convert rotation to radians for trigonometric functions
	var radians = deg_to_rad(newRot)
	
	# Calculate the offset from the block center
	var offset = newpos - block_center
	
	# Apply rotation matrix transformation
	var rotated_offset = Vector3(
		offset.x * cos(radians) - offset.z * sin(radians),
		offset.y,
		offset.x * sin(radians) + offset.z * cos(radians)
	)
	
	# Return the new position
	return block_center + rotated_offset


# Function to set the rotation for this furniture
func set_new_rotation(amount: int):
	var rotation_amount = amount
	if amount == 270:
		rotation_amount = amount - 180
	elif amount == 90:
		rotation_amount = amount + 180
	furniture_rotation = rotation_amount


# Function to get the current rotation of this furniture
func get_my_rotation() -> int:
	return furniture_rotation


# Helper function to determine if the furniture is new
func is_new_furniture() -> bool:
	return not furnitureJSON.has("global_position_x")
