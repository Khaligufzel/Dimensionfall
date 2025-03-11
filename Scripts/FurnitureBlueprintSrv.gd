class_name FurnitureBlueprintSrv
extends Node3D # Has to be Node3D. Changing it to RefCounted doesn't work


# This is a standalone script that is not attached to any node. 
# This is the static version of furniture. There is also FurniturePhysicsSrv.gd.
# This class is instanced by FurnitureStaticSpawner.gd when a map needs static 
# furniture, like a bed or fridge.

# Variables to store furniture data
var furniture_transform: FurnitureTransform
var furniture_position: Vector3
var furniture_rotation: int
var furnitureJSON: Dictionary # The json that defines this furniture on the map
var rfurniture: RFurniture # The json that defines this furniture's basics in general
var collider: RID
var shape: RID
var mesh_instance: RID  # Variable to store the mesh instance RID
var quad_instance: RID # RID to the quadmesh that displays the sprite
var myworld3d: World3D
var spawner: FurnitureBlueprintSpawner
var is_hidden: bool = false # If true, all visual elements are invisible

# We have to keep a reference or it will be auto deleted
var support_mesh: PrimitiveMesh # A mesh below the sprite for 3d effect
var sprite_texture: Texture2D  # Variable to store the sprite texture
var sprite_material: StandardMaterial3D # Material to display the furniture sprite
var quad_mesh: PlaneMesh # Shows the sprite of the furniture


# Variables to manage the container if this furniture is a container
var container: FurnitureContainer

# Variables to manage health and damage
var current_health: float = 100.0  # Default health
var is_animating_hit: bool = false  # Flag to prevent multiple hit animations
var original_material_color: Color = Color(1, 1, 1)  # Store the original material color

signal about_to_be_destroyed(me: FurnitureBlueprintSrv)


# Inner class to keep track of position, rotation and size and keep it central
class FurnitureTransform:
	var posx: float
	var posy: float
	var posz: float
	var rot: int
	var width: float
	var depth: float
	var height: float

	func _init(myposition: Vector3, myrotation: int, size: Vector3):
		width = size.x
		depth = size.z
		height = size.y
		posx = myposition.x
		posy = myposition.y
		posz = myposition.z
		rot = myrotation

	func get_position() -> Vector3:
		return Vector3(posx, posy, posz)

	func set_position(new_position: Vector3):
		posx = new_position.x
		posy = new_position.y
		posz = new_position.z

	func get_rotation() -> int:
		return rot

	func set_rotation(new_rotation: int):
		rot = new_rotation

	func get_sizeV3() -> Vector3:
		return Vector3(width, height, depth)

	func get_sizeV2() -> Vector2:
		return Vector2(width, depth)

	func set_size(new_size: Vector3):
		width = new_size.x
		height = new_size.y
		depth = new_size.z

	func update_transform(new_position: Vector3, new_rotation: int, new_size: Vector3):
		set_position(new_position)
		set_rotation(new_rotation)
		set_size(new_size)
	
	# New method to create a Transform3D
	func get_sprite_transform() -> Transform3D:
		var adjusted_position = get_position() + Vector3(0, 0.5*height+0.01, 0)
		return Transform3D(Basis(Vector3(0, 1, 0), deg_to_rad(rot)), adjusted_position)
	
	func get_cylinder_shape_data() -> Dictionary:
		return {"radius": width / 4.0, "height": height}
	
	# New method to create a Transform3D for visual instances
	func get_visual_transform() -> Transform3D:
		return Transform3D(Basis(Vector3(0, 1, 0), deg_to_rad(rot)), get_position())
	
	func get_box_shape_size() -> Vector3:
		return Vector3(width / 2.0, height / 2.0, depth / 2.0)
		
	func correct_new_position():
		# We have to compensate for the fact that the physicsserver and
		# renderingserver place the furniture lower then the intended height
		posy += 0.5+(0.5*height)


# Inner Container Class
class FurnitureContainer:
	var inventory: InventoryStacked
	var itemgroup: String # The ID of an itemgroup that it creates loot from
	var sprite_mesh: PlaneMesh
	var sprite_instance: RID # RID to the quadmesh that displays the containersprite
	var material: ShaderMaterial
	var furniture_transform: FurnitureTransform
	var world3d: World3D

	# Regeneration-related variables
	var regeneration_interval: float = -1.0  # Default to -1 (no regeneration)
	var last_time_checked: float = 0.0  # Tracks the last time regeneration was checked

	func _init(parent_furniture: FurnitureBlueprintSrv):
		furniture_transform = parent_furniture.furniture_transform
		world3d = parent_furniture.myworld3d
		_initialize_inventory()

	func _initialize_inventory():
		inventory = InventoryStacked.new()
		inventory.capacity = 1000
		inventory.item_protoset = ItemManager.item_protosets
	
	func get_inventory() -> InventoryStacked:
		return inventory

	# Function to create an additional sprite to represent the container
	func create_container_sprite_instance():
		# Calculate the size for the container sprite
		var furniture_size_v2 = furniture_transform.get_sizeV2()
		var smallest_dimension = min(furniture_size_v2.x, furniture_size_v2.y)
		var container_sprite_size = Vector2(smallest_dimension, smallest_dimension) * 0.8

		sprite_mesh = PlaneMesh.new()
		sprite_mesh.size = container_sprite_size

		sprite_mesh.material = material

		sprite_instance = RenderingServer.instance_create()
		RenderingServer.instance_set_base(sprite_instance, sprite_mesh)
		RenderingServer.instance_set_scenario(sprite_instance, world3d.scenario)

		# Position the container sprite slightly above the main sprite
		var container_sprite_transform = furniture_transform.get_sprite_transform()
		container_sprite_transform.origin.y += 0.2  # Adjust height as needed
		RenderingServer.instance_set_transform(sprite_instance, container_sprite_transform)

	# Deserialize container data if available
	func deserialize_container_data(container_json: Dictionary):
		if not container_json.has("Function"):
			return
		if not container_json.Function.has("container"):
			return
		if "items" in container_json["Function"]["container"]:
			inventory.deserialize(container_json["Function"]["container"]["items"])

	# Serialize the container data for saving
	func serialize() -> Dictionary:
		var container_data: Dictionary = {}
		var container_inventory_data = inventory.serialize()

		# Only include inventory data if it has items
		if not container_inventory_data.is_empty():
			container_data["items"] = container_inventory_data

		return container_data

	func update_sprite_for_mode():
		material = Gamedata.materials.under_construction  # Generic container material
		sprite_mesh.material = material


# Function to initialize the furniture object
# Initialize furniture in the correct mode during setup
func _init(furniturepos: Vector3, newFurnitureJSON: Dictionary, world3d: World3D):
	furniture_position = furniturepos
	furnitureJSON = newFurnitureJSON
	furniture_rotation = furnitureJSON.get("rotation", 0)
	rfurniture = Runtimedata.furnitures.by_id(furnitureJSON.id)
	myworld3d = world3d

	sprite_texture = rfurniture.sprite
	var furniture_size: Vector3 = calculate_furniture_size()

	furniture_transform = FurnitureTransform.new(furniturepos, furniture_rotation, furniture_size)

	if _is_new_furniture():
		furniture_transform.correct_new_position()
		_apply_edge_snapping_if_needed()
		set_new_rotation(furniture_rotation)  # Apply rotation after setting up the shape and visual instance
	

	if rfurniture.support_shape.shape == "Box":
		create_box_shape()
		create_visual_instance("Box")
	elif rfurniture.support_shape.shape == "Cylinder":
		create_cylinder_shape()
		create_visual_instance("Cylinder")

	create_sprite_instance()
	add_container()  # Adds container if the furniture is a container

	# Apply the mode-specific logic. Only constructed furniture will be BLUEPRINT
	set_mode()
	Helper.signal_broker.player_current_y_level.connect.call_deferred(_on_player_y_level_updated)


# If this furniture is a container, it will add a container node to the furniture.
func add_container():
	container = FurnitureContainer.new(self)
	container.create_container_sprite_instance()
	if not _is_new_furniture():
		container.deserialize_container_data(furnitureJSON)


# Function to calculate the size of the furniture
func calculate_furniture_size() -> Vector3:
	if sprite_texture:
		var sprite_width = sprite_texture.get_width() / 100.0 # Convert pixels to meters
		var sprite_depth = sprite_texture.get_height() / 100.0 # Convert pixels to meters
		var height = rfurniture.support_shape.height
		return Vector3(sprite_width, height, sprite_depth)  # Use height from support shape
	return Vector3(0.5, rfurniture.support_shape.height, 0.5)  # Default size if texture is not set


# Function to create a BoxShape3D collider based on the given size
func create_box_shape():
	shape = PhysicsServer3D.box_shape_create()
	PhysicsServer3D.shape_set_data(shape, furniture_transform.get_box_shape_size())
	
	collider = PhysicsServer3D.body_create()
	PhysicsServer3D.body_set_mode(collider, PhysicsServer3D.BODY_MODE_STATIC)
	# Set space, so it collides in the same space as current scene.
	PhysicsServer3D.body_set_space(collider, myworld3d.space)
	PhysicsServer3D.body_add_shape(collider, shape)

	var mytransform = furniture_transform.get_visual_transform()
	PhysicsServer3D.body_set_state(collider, PhysicsServer3D.BODY_STATE_TRANSFORM, mytransform)
	set_collision_layers_and_masks()


# Function to create a visual instance with a mesh to represent the shape
# Apply the hide_above_player_shader to the MeshInstance
func create_visual_instance(shape_type: String):
	var material: StandardMaterial3D = Runtimedata.furnitures.get_shape_material_by_id(rfurniture.id)

	if shape_type == "Box":
		support_mesh = BoxMesh.new()
		(support_mesh as BoxMesh).size = furniture_transform.get_sizeV3()
	elif shape_type == "Cylinder":
		support_mesh = CylinderMesh.new()
		(support_mesh as CylinderMesh).height = furniture_transform.height
		(support_mesh as CylinderMesh).top_radius = furniture_transform.width / 4.0
		(support_mesh as CylinderMesh).bottom_radius = furniture_transform.width / 4.0

	support_mesh.material = material  # Set the shader material

	mesh_instance = RenderingServer.instance_create()
	RenderingServer.instance_set_base(mesh_instance, support_mesh)
	RenderingServer.instance_set_scenario(mesh_instance, myworld3d.scenario)
	var mytransform = furniture_transform.get_visual_transform()
	RenderingServer.instance_set_transform(mesh_instance, mytransform)


# Function to create a QuadMesh to display the sprite texture on top of the furniture
func create_sprite_instance():
	# Create a PlaneMesh to hold the sprite
	quad_mesh = PlaneMesh.new()
	quad_mesh.size = furniture_transform.get_sizeV2()

	# Get the shader material from Runtimedata.furnitures
	sprite_material = Runtimedata.furnitures.get_standard_material_by_id(furnitureJSON.id)

	quad_mesh.material = sprite_material

	# Create the quad instance
	quad_instance = RenderingServer.instance_create()
	RenderingServer.instance_set_base(quad_instance, quad_mesh)
	RenderingServer.instance_set_scenario(quad_instance, myworld3d.scenario)

	# Set the transform for the quad instance slightly above the box mesh
	RenderingServer.instance_set_transform(quad_instance, furniture_transform.get_sprite_transform())


# Now, update methods that involve position, rotation, and size
func _apply_edge_snapping_if_needed():
	if not rfurniture.edgesnapping == "None":
		var new_position = _apply_edge_snapping(
			rfurniture.edgesnapping
		)
		furniture_transform.set_position(new_position)


# Function to create a CylinderShape3D collider based on the given size
func create_cylinder_shape():
	shape = PhysicsServer3D.cylinder_shape_create()
	PhysicsServer3D.shape_set_data(shape, furniture_transform.get_cylinder_shape_data())
	
	collider = PhysicsServer3D.body_create()
	PhysicsServer3D.body_set_mode(collider, PhysicsServer3D.BODY_MODE_STATIC)
	# Set space, so it collides in the same space as current scene.
	PhysicsServer3D.body_set_space(collider, myworld3d.space)
	PhysicsServer3D.body_add_shape(collider, shape)
	var mytransform = furniture_transform.get_visual_transform()
	PhysicsServer3D.body_set_state(collider, PhysicsServer3D.BODY_STATE_TRANSFORM, mytransform)
	set_collision_layers_and_masks()


# Function to set collision layers and masks
func set_collision_layers_and_masks():
	# Set collision layer to layers 3 (static obstacles layer) and 7 (containers layer)
	var collision_layer = (1 << 2) | (1 << 6)  # Layer 3 is 1 << 2, Layer 7 is 1 << 6

	# Set collision mask to include layers 1, 2, 3, 4, 5, and 6
	var collision_mask = (1 << 0) | (1 << 1) | (1 << 2) | (1 << 3) | (1 << 4) | (1 << 5)
	# Explanation:
	# - 1 << 0: Layer 1 (player layer)
	# - 1 << 1: Layer 2 (enemy layer)
	# - 1 << 2: Layer 3 (static obstacles layer)
	# - 1 << 3: Layer 4 (movable obstacles layer)
	# - 1 << 4: Layer 5 (friendly projectiles layer)
	# - 1 << 5: Layer 6 (enemy projectiles layer)
	
	PhysicsServer3D.body_set_collision_layer(collider, collision_layer)
	PhysicsServer3D.body_set_collision_mask(collider, collision_mask)


# If edge snapping has been set in the furniture editor, we will apply it here.
# The direction refers to the 'backside' of the furniture, which will be facing the edge of the block
# This is needed to put furniture against the wall, or get a fence at the right edge
func _apply_edge_snapping(direction: String) -> Vector3:
	# Block size, a block is 1x1 meters
	var blockSize = Vector3(1.0, 1.0, 1.0)
	var newpos = furniture_transform.get_position()
	var size: Vector3 = furniture_transform.get_sizeV3()
	
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
	newpos = rotate_position_around_block_center(newpos, furniture_transform.get_position())
	
	return newpos


# Called when applying edge-snapping so it's put into the right position
func rotate_position_around_block_center(newpos: Vector3, block_center: Vector3) -> Vector3:
	# Convert rotation to radians for trigonometric functions
	var radians = deg_to_rad(furniture_transform.get_rotation())
	
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
	furniture_transform.set_rotation(rotation_amount)


# Function to get the current rotation of this furniture
func get_my_rotation() -> int:
	return furniture_transform.get_rotation()


# Helper function to determine if the furniture is new
func _is_new_furniture() -> bool:
	return not furnitureJSON.has("global_position_x")


# Function to free all resources like the RIDs
func free_resources():
	about_to_be_destroyed.emit(self)
	# Free the mesh instance RID if it exists
	RenderingServer.free_rid(mesh_instance)
	RenderingServer.free_rid(quad_instance)
	if container:
		RenderingServer.free_rid(container.sprite_instance)

	# Free the collider shape and body RIDs if they exist
	PhysicsServer3D.free_rid(shape)
	PhysicsServer3D.free_rid(collider)

	# Clear the reference to the DFurniture data if necessary
	rfurniture = null


# Function to interact with the furniture (e.g., toggling door state)
func interact():
	Helper.signal_broker.furniture_interacted.emit(self)


# Function to apply the door's transformation
func apply_transform_to_instance(rotation_angle: int, position_offset: Vector3):
	# Apply transformation for mesh_instance (main visual mesh)
	var mesh_transform = Transform3D(
		Basis(Vector3(0, 1, 0), deg_to_rad(rotation_angle)),  # Apply rotation
		furniture_transform.get_position() + position_offset  # Apply position offset
	)
	RenderingServer.instance_set_transform(mesh_instance, mesh_transform)
	
	# Apply transformation for quad_instance (sprite) with rotation and sprite-specific offset
	var sprite_transform = Transform3D(
		Basis(Vector3(0, 1, 0), deg_to_rad(rotation_angle)),  # Apply rotation
		furniture_transform.get_sprite_transform().origin + position_offset  # Apply position and sprite offset
	)
	RenderingServer.instance_set_transform(quad_instance, sprite_transform)

	# Apply the same transform for collider if needed (only using mesh_transform logic here)
	PhysicsServer3D.body_set_state(collider, PhysicsServer3D.BODY_STATE_TRANSFORM, mesh_transform)


# Returns this furniture's data for saving, including door state, container state, and last checked time
func get_data() -> Dictionary:
	var newfurniturejson = {
		"id": furnitureJSON.id,
		"moveable": false,
		"mode": "blueprint",
		"global_position_x": furniture_transform.posx,
		"global_position_y": furniture_transform.posy,
		"global_position_z": furniture_transform.posz,
		"rotation": get_my_rotation(),
	}

	# Container functionality
	if container:
		if "Function" not in newfurniturejson:
			newfurniturejson["Function"] = {}
		newfurniturejson["Function"]["container"] = container.serialize()

	return newfurniturejson


# Check if the furniture can be destroyed
func can_be_destroyed() -> bool:
	return not rfurniture.destruction.get_data().is_empty()


# Check if the furniture can be disassembled
func can_be_disassembled() -> bool:
	return not rfurniture.disassembly.get_data().is_empty()


# Returns the inventorystacked that this container holds
func get_inventory() -> InventoryStacked:
	return container.get_inventory()


func get_sprite() -> Texture:
	return rfurniture.sprite


# Function to handle furniture destruction
func die():
	Helper.signal_broker.container_exited_proximity.emit(self)
	free_resources()  # Free resources
	queue_free()  # Remove the node from the scene tree


# Function to check for the presence of an item in a container
func has_item_in_container(mycontainer: Object, item_id: String) -> bool:
	if mycontainer and mycontainer.has_method("get_inventory"):
		var target_inventory = mycontainer.get_inventory()
		return target_inventory.has_item_by_id(item_id) if target_inventory else false
	return false


# Function to count the amount of an item in a container
func get_item_count_in_container(mycontainer: Object, item_id: String) -> int:
	if mycontainer and mycontainer.has_method("get_inventory"):
		var target_inventory = mycontainer.get_inventory()
		if target_inventory:
			var items = target_inventory.get_items_by_id(item_id)
			var total_count = 0
			for item in items:
				total_count += InventoryStacked.get_item_stack_size(item)
			return total_count
	return 0


func get_furniture_name() -> String:
	return rfurniture.name


# Get the available amount of the ingredient in the FurnitureContainer inventory.
func get_available_ingredient_amount(ingredient_id: String) -> int:
	var inventory = container.get_inventory()
	var available_amount: int = 0
	if inventory.has_item_by_id(ingredient_id):
		var items: Array = inventory.get_items_by_id(ingredient_id)
		for item in items:
			available_amount += InventoryStacked.get_item_stack_size(item)
	return available_amount


# Update to manage `current_mode` behavior
func set_mode():
	if collider:
		PhysicsServer3D.body_set_collision_layer(collider, (1 << 6))  # Layer 7 is 1 << 6
		_adjust_visuals_for_blueprint_mode()

	# Update the container sprite visuals depending on the mode
	if container:
		container.update_sprite_for_mode()


# Adjust visuals for blueprint mode (e.g., semi-transparent appearance or hide sprite)
func _adjust_visuals_for_blueprint_mode():
	if support_mesh:
		# Set the support mesh material to under construction shader material
		support_mesh.material = Runtimedata.furnitures.under_construction_material

	if sprite_material:
		sprite_material = Runtimedata.furnitures.under_construction_material
		quad_mesh.material = sprite_material


# Adjust visuals for default mode (e.g., normal appearance)
func _adjust_visuals_for_default_mode():
	if support_mesh:
		# Revert support mesh material to normal material
		support_mesh.material = Runtimedata.furnitures.get_shape_material_by_id(rfurniture.id)

	if sprite_material:
		sprite_material = Runtimedata.furnitures.get_standard_material_by_id(furnitureJSON.id)
		quad_mesh.material = sprite_material


# Function to check if all items required for construction are present in the container inventory
func has_all_construction_items() -> bool:
	if not rfurniture or not rfurniture.construction or rfurniture.construction.items.is_empty():
		return false  # Exit if construction data is missing or invalid

	var construction_items: Dictionary = rfurniture.construction.items

	# Loop through each item in the construction requirements
	for item_id in construction_items.keys():
		var required_amount: int = construction_items[item_id]
		var available_amount: int = get_available_ingredient_amount(item_id)

		# If any required item is not available in sufficient quantity, return false
		if available_amount < required_amount:
			return false

	return true  # All items are available in sufficient quantity


# When the furniture is destroyed, it leaves a wreck behind
func add_corpse(pos: Vector3):
	var newitemjson: Dictionary = {
		"global_position_x": pos.x,
		"global_position_y": pos.y,
		"global_position_z": pos.z
	}
	
	var newItem: ContainerItem = ContainerItem.new(newitemjson)
	newItem.add_to_group("mapitems")
	
	var fursprite = rfurniture.destruction.sprite
	if fursprite:
		newItem.set_texture(fursprite)
	
	# Add the new item with possibly set loot group to the tree
	Helper.map_manager.level_generator.get_tree().get_root().add_child.call_deferred(newItem)
	
	# Check if the inventory has items and insert them into the new item
	if container.get_inventory():
		# Create a duplicate of the items array to avoid modifying it during iteration
		var items_copy = container.get_inventory().get_items().duplicate()
		for item in items_copy:
			newItem.insert_item(item)  # Safely insert items without disrupting the loop


# Removes all construction items required for this furniture from the container's inventory.
# Returns true if all items are successfully removed, false otherwise.
func remove_construction_items() -> bool:
	if not rfurniture or not rfurniture.construction or rfurniture.construction.items.is_empty():
		return false  # Exit if construction data is missing or invalid

	var construction_items: Dictionary = rfurniture.construction.items
	var items_source: Array = container.get_inventory().get_items()  # Source of items to remove

	# Loop through each item in the construction requirements
	for item_id in construction_items.keys():
		var required_amount: int = construction_items[item_id]

		# Use ItemManager to remove the required items
		if not ItemManager.remove_resource(item_id, required_amount, items_source):
			return false  # If any item cannot be removed, return false

	return true  # All required items were successfully removed


# Returns the y position of the furniture.
# If 'snapped' is true, it returns the y position snapped to the nearest integer.
func get_y_position(is_snapped: bool = false) -> float:
	var y_pos = furniture_transform.posy
	return round(y_pos) if is_snapped else y_pos

# ✅ Function to hide the furniture visuals
func hide_visuals():
	if mesh_instance:
		RenderingServer.instance_set_visible(mesh_instance, false)
	if quad_instance:
		RenderingServer.instance_set_visible(quad_instance, false)
	if container and container.sprite_instance:
		RenderingServer.instance_set_visible(container.sprite_instance, false)
	is_hidden = true

# ✅ Function to show the furniture visuals
func show_visuals():
	if mesh_instance:
		RenderingServer.instance_set_visible(mesh_instance, true)
	if quad_instance:
		RenderingServer.instance_set_visible(quad_instance, true)
	if container and container.sprite_instance:
		RenderingServer.instance_set_visible(container.sprite_instance, true)
	is_hidden = false


# ✅ Handles player Y level update and updates furniture visibility
func _on_player_y_level_updated(_old_y_level: float, new_y_level: float):
	var furniture_y = get_y_position(true)  # Get snapped Y level

	# Hide furniture above player, show furniture below
	if furniture_y > new_y_level:
		if not is_hidden:
			hide_visuals()
	else:
		if is_hidden:
			show_visuals()
