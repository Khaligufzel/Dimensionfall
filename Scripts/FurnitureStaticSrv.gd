class_name FurnitureStaticSrv
extends Node3D # Has to be Node3D. Changing it to RefCounted doesn't work

# Variables to store furniture data
var furniture_transform: FurnitureTransform
var furniture_position: Vector3
var furniture_rotation: int
var furnitureJSON: Dictionary # The json that defines this furniture on the map
var dfurniture: DFurniture # The json that defines this furniture's basics in general
var collider: RID
var shape: RID
var mesh_instance: RID  # Variable to store the mesh instance RID
var quad_instance: RID # RID to the quadmesh that displays the sprite
var container_sprite_instance: RID # RID to the quadmesh that displays the containersprite
var myworld3d: World3D
var i_am_visible: bool = true # keep track of general visibility

# We have to keep a reference or it will be auto deleted
var support_mesh: PrimitiveMesh
var sprite_texture: Texture2D  # Variable to store the sprite texture
var sprite_material: StandardMaterial3D
var container_material: StandardMaterial3D
var quad_mesh: PlaneMesh
var container_sprite_mesh: PlaneMesh

# Variables to manage door functionality
var is_door: bool = false
var door_state: String = "Closed"  # Default state

# Variables to manage the container if this furniture is a container
var inventory: InventoryStacked
var itemgroup: String # The ID of an itemgroup that it creates loot from

# Variables to manage health and damage
var current_health: float = 100.0  # Default health
var is_animating_hit: bool = false  # Flag to prevent multiple hit animations
var original_material_color: Color = Color(1, 1, 1)  # Store the original material color

signal about_to_be_destroyed(me: FurnitureStaticSrv)


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
		


# Function to initialize the furniture object
func _init(furniturepos: Vector3, newFurnitureJSON: Dictionary, world3d: World3D):
	furniture_position = furniturepos
	furnitureJSON = newFurnitureJSON
	furniture_rotation = furnitureJSON.get("rotation", 0)
	dfurniture = Gamedata.furnitures.by_id(furnitureJSON.id)
	myworld3d = world3d

	sprite_texture = dfurniture.sprite
	var furniture_size: Vector3 = calculate_furniture_size()

	furniture_transform = FurnitureTransform.new(furniturepos, furniture_rotation, furniture_size)

	if is_new_furniture():
		furniture_transform.correct_new_position()
		apply_edge_snapping_if_needed()

	check_door_functionality()  # Check if this furniture is a door

	set_new_rotation(furniture_rotation) # Apply rotation after setting up the shape and visual instance
	if dfurniture.support_shape.shape == "Box":
		create_box_shape()
		create_visual_instance("Box")
	elif dfurniture.support_shape.shape == "Cylinder":
		create_cylinder_shape()
		create_visual_instance("Cylinder")

	create_sprite_instance()
	update_door_visuals()  # Set initial door visuals based on its state
	Helper.signal_broker.player_y_level_updated.connect(_on_player_y_level_updated)
	add_container()  # Adds container if the furniture is a container


# If this furniture is a container, it will add a container node to the furniture.
func add_container():
	if is_container():
		_create_inventory()
		container_material = StandardMaterial3D.new()
		if is_new_furniture():
			create_loot()
		else:
			deserialize_container_data()
		create_container_sprite_instance()

func is_container() -> bool:
	return dfurniture.function.is_container

# Creates a new InventoryStacked to hold items in it
func _create_inventory():
	inventory = InventoryStacked.new()
	inventory.capacity = 1000
	inventory.item_protoset = ItemManager.item_protosets
	inventory.item_removed.connect(_on_item_removed)
	inventory.item_added.connect(_on_item_added)


# If there is an itemgroup assigned to the furniture, it will be added to the container.
# It will check both furnitureJSON and dfurniture for itemgroup information.
# The function will return the id of the itemgroup so that the container may use it
func populate_container_from_itemgroup() -> String:
	# Check if furnitureJSON contains an itemgroups array
	if furnitureJSON.has("itemgroups"):
		var itemgroups_array = furnitureJSON["itemgroups"]
		if itemgroups_array.size() > 0:
			return itemgroups_array.pick_random()
		else:
			print_debug("itemgroups array is empty in furnitureJSON")
	
	# Fallback to using itemgroup from furnitureJSONData if furnitureJSON.itemgroups does not exist
	var myitemgroup = dfurniture.function.container_group
	if myitemgroup:
		return myitemgroup
	return ""

# Function to calculate the size of the furniture
func calculate_furniture_size() -> Vector3:
	if sprite_texture:
		var sprite_width = sprite_texture.get_width() / 100.0 # Convert pixels to meters
		var sprite_depth = sprite_texture.get_height() / 100.0 # Convert pixels to meters
		var height = dfurniture.support_shape.height
		return Vector3(sprite_width, height, sprite_depth)  # Use height from support shape
	return Vector3(0.5, dfurniture.support_shape.height, 0.5)  # Default size if texture is not set


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
func create_visual_instance(shape_type: String):
	var color = Color.html(dfurniture.support_shape.color)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	if dfurniture.support_shape.transparent:
		material.flags_transparent = true
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	if shape_type == "Box":
		support_mesh = BoxMesh.new()
		(support_mesh as BoxMesh).size = furniture_transform.get_sizeV3()
	elif shape_type == "Cylinder":
		support_mesh = CylinderMesh.new()
		(support_mesh as CylinderMesh).height = furniture_transform.height
		(support_mesh as CylinderMesh).top_radius = furniture_transform.width / 4.0
		(support_mesh as CylinderMesh).bottom_radius = furniture_transform.width / 4.0

	support_mesh.material = material

	mesh_instance = RenderingServer.instance_create()
	RenderingServer.instance_set_base(mesh_instance, support_mesh)
	
	RenderingServer.instance_set_scenario(mesh_instance, myworld3d.scenario)
	var mytransform = furniture_transform.get_visual_transform()
	RenderingServer.instance_set_transform(mesh_instance, mytransform)


# Function to create a QuadMesh to display the sprite texture on top of the furniture
func create_sprite_instance():
	quad_mesh = PlaneMesh.new()
	quad_mesh.size = furniture_transform.get_sizeV2()
	sprite_material = StandardMaterial3D.new()
	sprite_material.albedo_texture = sprite_texture
	sprite_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	#material.flags_unshaded = true  # Optional: make the sprite unshaded
	quad_mesh.material = sprite_material
	
	quad_instance = RenderingServer.instance_create()
	RenderingServer.instance_set_base(quad_instance, quad_mesh)
	RenderingServer.instance_set_scenario(quad_instance, myworld3d.scenario)
	
	# Set the transform for the quad instance to be slightly above the box mesh
	RenderingServer.instance_set_transform(quad_instance, furniture_transform.get_sprite_transform())


# Function to create an additional sprite to represent the container
func create_container_sprite_instance():
	# Calculate the size for the container sprite
	var furniture_size_v2 = furniture_transform.get_sizeV2()
	var smallest_dimension = min(furniture_size_v2.x, furniture_size_v2.y)
	var container_sprite_size = Vector2(smallest_dimension, smallest_dimension) * 0.8

	container_sprite_mesh = PlaneMesh.new()
	container_sprite_mesh.size = container_sprite_size

	container_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	container_sprite_mesh.material = container_material

	container_sprite_instance = RenderingServer.instance_create()
	RenderingServer.instance_set_base(container_sprite_instance, container_sprite_mesh)
	RenderingServer.instance_set_scenario(container_sprite_instance, myworld3d.scenario)

	# Position the container sprite slightly above the main sprite
	var container_sprite_transform = furniture_transform.get_sprite_transform()
	container_sprite_transform.origin.y += 0.2  # Adjust height as needed
	RenderingServer.instance_set_transform(container_sprite_instance, container_sprite_transform)


# Now, update methods that involve position, rotation, and size
func apply_edge_snapping_if_needed():
	if not dfurniture.edgesnapping == "None":
		var new_position = apply_edge_snapping(
			dfurniture.edgesnapping
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
	# - 1 << 2: Layer 3 (movable obstacles layer)
	# - 1 << 3: Layer 4 (static obstacles layer)
	# - 1 << 4: Layer 5 (friendly projectiles layer)
	# - 1 << 5: Layer 6 (enemy projectiles layer)
	
	PhysicsServer3D.body_set_collision_layer(collider, collision_layer)
	PhysicsServer3D.body_set_collision_mask(collider, collision_mask)


# If edge snapping has been set in the furniture editor, we will apply it here.
# The direction refers to the 'backside' of the furniture, which will be facing the edge of the block
# This is needed to put furniture against the wall, or get a fence at the right edge
func apply_edge_snapping(direction: String) -> Vector3:
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
func is_new_furniture() -> bool:
	return not furnitureJSON.has("global_position_x")


# Function to free all resources like the RIDs
func free_resources():
	about_to_be_destroyed.emit(self)
	# Free the mesh instance RID if it exists
	RenderingServer.free_rid(mesh_instance)
	RenderingServer.free_rid(quad_instance)
	RenderingServer.free_rid(container_sprite_instance)

	# Free the collider shape and body RIDs if they exist
	PhysicsServer3D.free_rid(shape)
	PhysicsServer3D.free_rid(collider)

	# Clear the reference to the DFurniture data if necessary
	dfurniture = null


# Function to check if this furniture acts as a door
func check_door_functionality():
	is_door = not dfurniture.function.door == "None"
	door_state = dfurniture.function.door

# Function to interact with the furniture (e.g., toggling door state)
func interact():
	if is_door:
		toggle_door()

# Function to toggle the door state
func toggle_door():
	door_state = "Open" if door_state == "Closed" else "Closed"
	furnitureJSON["Function"] = {"door": door_state}
	update_door_visuals()

# Update the visuals and physics of the door
func update_door_visuals():
	if not is_door:
		return

	# Adjust rotation based on door state
	var base_rotation = furniture_transform.get_rotation()
	var rotation_angle: int
	var position_offset: Vector3

	# Adjust rotation direction and position offset based on base_rotation
	if base_rotation == 0:
		rotation_angle = base_rotation + (-90 if door_state == "Open" else 0)
		position_offset = Vector3(0.5, 0, 0.5) if door_state == "Open" else Vector3.ZERO  # Move to the right
	elif base_rotation == 90:
		rotation_angle = base_rotation + (-90 if door_state == "Open" else 0)
		position_offset = Vector3(0.5, 0, 0.5) if door_state == "Open" else Vector3.ZERO  # Move backward
	else:
		rotation_angle = base_rotation + (90 if door_state == "Open" else 0)
		position_offset = Vector3(-0.5, 0, -0.5) if door_state == "Open" else Vector3.ZERO  # Standard offset

	apply_transform_to_instance(rotation_angle, position_offset)

# Function to apply the door's transformation
func apply_transform_to_instance(rotation_angle: int, position_offset: Vector3):
	var door_transform = Transform3D(Basis(Vector3(0, 1, 0), deg_to_rad(rotation_angle)), furniture_transform.get_position() + position_offset)
	RenderingServer.instance_set_transform(mesh_instance, door_transform)
	RenderingServer.instance_set_transform(quad_instance, door_transform)
	PhysicsServer3D.body_set_state(collider, PhysicsServer3D.BODY_STATE_TRANSFORM, door_transform)


# Returns this furniture's data for saving, including door state if applicable
func get_data() -> Dictionary:
	var newfurniturejson = {
		"id": furnitureJSON.id,
		"moveable": false,
		"global_position_x": furniture_transform.posx,
		"global_position_y": furniture_transform.posy,
		"global_position_z": furniture_transform.posz,
		"rotation": get_my_rotation(),
	}

	if is_door:
		newfurniturejson["Function"] = {"door": door_state}
	
	# Check if this furniture has a container attached and if it has items
	if inventory:
		# Initialize the 'Function' sub-dictionary if not already present
		if "Function" not in newfurniturejson:
			newfurniturejson["Function"] = {}
		var containerdata = inventory.serialize()
		# If there are no items in the inventory, keep an empty object. Else,
		# keep an object with the items key and the serialized items
		var containerobject = {} if containerdata.is_empty() else {"items": containerdata}
		newfurniturejson["Function"]["container"] = containerobject

	return newfurniturejson


# It will deserialize the container data if the furniture is not new.
func deserialize_container_data():
	if "items" in furnitureJSON["Function"]["container"]:
		deserialize_and_apply_items(furnitureJSON["Function"]["container"]["items"])


# Function to deserialize inventory and apply the correct sprite
func deserialize_and_apply_items(items_data: Dictionary):
	inventory.deserialize(items_data)
	
	#var default_texture: Texture = Gamedata.textures.container
	
	#if inventory.get_items().size() > 0:
		#if sprite_3d.texture == default_texture:
			#sprite_3d.texture = Gamedata.textures.container_filled
		## Else, some other texture has been set so we keep that
	#else:
		#sprite_3d.texture = default_texture
		#_on_item_removed(null)


# Function to hide visual elements
func hide_visual_elements():
	if not i_am_visible:
		return # I am already inivisble
	# Check if instances exist before hiding
	if mesh_instance:
		RenderingServer.instance_set_visible(mesh_instance, false)
	if quad_instance:
		RenderingServer.instance_set_visible(quad_instance, false)
	if container_sprite_instance:
		RenderingServer.instance_set_visible(container_sprite_instance, false)
	i_am_visible = false


# Function to show visual elements
func show_visual_elements():
	if i_am_visible:
		return # I am already visible
	# Check if instances exist before showing
	if mesh_instance:
		RenderingServer.instance_set_visible(mesh_instance, true)
	if quad_instance:
		RenderingServer.instance_set_visible(quad_instance, true)
	if container_sprite_instance:
		RenderingServer.instance_set_visible(container_sprite_instance, true)
	i_am_visible = true


# Function to handle the player's Y level change
func _on_player_y_level_updated(new_y: float):
	# Check if the furniture is above the player's new Y level
	if furniture_transform.posy > new_y:
		# Hide the furniture if it is above the player's level
		hide_visual_elements()
	else:
		# Show the furniture if it is at or below the player's level
		show_visual_elements()


# When the furniture is destroyed, it leaves a wreck behind
func add_corpse(pos: Vector3):
	if can_be_destroyed():
		var newitemjson: Dictionary = {
			"global_position_x": pos.x,
			"global_position_y": pos.y,
			"global_position_z": pos.z
		}
		
		var myitemgroup = dfurniture.destruction.group
		if myitemgroup:
			newitemjson["itemgroups"] = [myitemgroup]
		
		var newItem: ContainerItem = ContainerItem.new(newitemjson)
		newItem.add_to_group("mapitems")
		
		var fursprite = dfurniture.destruction.sprite
		if fursprite:
			newItem.set_texture(fursprite)
		
		# Finally add the new item with possibly set loot group to the tree
		Helper.map_manager.level_generator.get_tree().get_root().add_child.call_deferred(newItem)
		
		# Check if inventory has items and insert them into the new item
		if inventory:
			for item in inventory.get_items():
				newItem.insert_item(item)


# Check if the furniture can be destroyed
func can_be_destroyed() -> bool:
	return not dfurniture.destruction.get_data().is_empty()


# Check if the furniture can be disassembled
func can_be_disassembled() -> bool:
	return not dfurniture.disassembly.get_data().is_empty()


# Will add item to the inventory based on the assigned itemgroup
# Only new furniture will have an itemgroup assigned, not previously saved furniture.
func create_loot():
	itemgroup = populate_container_from_itemgroup()
	if not itemgroup or itemgroup == "":
		return
	# A flag to track whether items were added
	var item_added: bool = false
	# Attempt to retrieve the itemgroup data from Gamedata
	var ditemgroup: DItemgroup = Gamedata.itemgroups.by_id(itemgroup)
	
	# Check if the itemgroup data exists and has items
	if ditemgroup:
		var groupmode: String = ditemgroup.mode # can be "Collection" or "Distribution".
		if groupmode == "Collection":
			item_added = _add_items_to_inventory_collection_mode(ditemgroup.items)
		elif groupmode == "Distribution":
			item_added = _add_items_to_inventory_distribution_mode(ditemgroup.items)

	# Set the texture if an item was successfully added and if it hasn't been set by set_texture
	if item_added:
		container_material.albedo_texture = Gamedata.textures.container_filled
	elif not item_added:
		 # If no item was added we delete the container if it's not a child of some furniture
		_on_item_removed(null)


# Takes a list of items and adds them to the inventory in Collection mode.
func _add_items_to_inventory_collection_mode(items: Array[DItemgroup.Item]) -> bool:
	var item_added: bool = false
	# Loop over each item object in the itemgroup's 'items' property
	for item_object: DItemgroup.Item in items:
		# Each item_object is expected to be a dictionary with id, probability, min, max
		var item_id = item_object.id
		var item_probability = item_object.probability
		if randi_range(0, 100) <= item_probability:
			item_added = true # An item is about to be added
			# Determine quantity to add based on min and max
			var quantity = randi_range(item_object.minc, item_object.maxc)
			_add_item_to_inventory(item_id, quantity)
	return item_added


# Takes a list of items and adds one to the inventory based on probabilities in Distribution mode.
func _add_items_to_inventory_distribution_mode(items: Array[DItemgroup.Item]) -> bool:
	var total_probability = 0
	# Calculate the total probability
	for item_object in items:
		total_probability += item_object.probability

	# Generate a random value between 0 and total_probability - 1
	var random_value = randi_range(0, total_probability - 1)
	var cumulative_probability = 0

	# Iterate through items to select one based on the random value
	for item_object: DItemgroup.Item in items:
		cumulative_probability += item_object.probability
		# Check if the random value falls within the current item's range
		if random_value < cumulative_probability:
			var item_id = item_object.id
			var quantity = randi_range(item_object.minc, item_object.maxc)
			_add_item_to_inventory(item_id, quantity)
			return true  # One item is added, return immediately

	return false  # In case no item is added, though this is highly unlikely


# Takes an item_id and quantity and adds it to the inventory
func _add_item_to_inventory(item_id: String, quantity: int):
	# Fetch the individual item data for verification
	var ditem: DItem = Gamedata.items.by_id(item_id)
	# Check if the item data is valid before adding
	if ditem and quantity > 0:
		while quantity > 0:
			# Calculate the stack size for this iteration, limited by max_stack_size
			var stack_size = min(quantity, ditem.max_stack_size)
			# Create and add the item to the inventory
			var item = inventory.create_and_add_item(item_id)
			# Set the item stack size
			InventoryStacked.set_item_stack_size(item, stack_size)
			# Decrease the remaining quantity
			quantity -= stack_size


# Signal handler for item removed
# We don't want empty containers on the map, but we do want them as children of furniture
# So we delete empty containers if they are a child of the tree root.
func _on_item_removed(_item: InventoryItem):
	# Check if there are any items left in the inventory
	if inventory.get_items().size() == 0:
		container_material.albedo_texture = Gamedata.textures.container
	else: # There are still items in the container
		set_random_inventory_item_texture() # Update to a new sprite


func _on_item_added(_item: InventoryItem):
	set_random_inventory_item_texture() # Update to a new sprite

# Returns the inventorystacked that this container holds
func get_inventory() -> InventoryStacked:
	return inventory


func get_sprite() -> Texture:
	return dfurniture.sprite


# Sets the sprite_3d texture to a texture of a random item in the container's inventory
func set_random_inventory_item_texture():
	var items: Array[InventoryItem] = inventory.get_items()
	if items.size() == 0:
		return
	
	# Pick a random item from the inventory
	var random_item: InventoryItem = items.pick_random()
	var item_id = random_item.prototype_id
	
	# Set the sprite_3d texture to the item's sprite
	container_material.albedo_texture = Gamedata.items.sprite_by_id(item_id)


# Function to handle damage when the furniture gets hit
# attack: a dictionary with the "damage" and "hit_chance" properties
func get_hit(attack: Dictionary):
	var damage = attack.damage
	var hit_chance = attack.hit_chance

	# Calculate actual hit chance considering static furniture bonus
	var actual_hit_chance = hit_chance + 0.25  # Boost hit chance by 25%

	# Determine if the attack hits
	if randf() <= actual_hit_chance:
		# Attack hits
		if can_be_destroyed():
			current_health -= damage
			if current_health <= 0:
				_die()  # Destroy the furniture if health is depleted
			else:
				if not is_animating_hit:
					animate_hit()
	else:
		# Attack misses, create a visual indicator
		show_miss_indicator()


# Function to animate the hit effect
func animate_hit():
	is_animating_hit = true
	original_material_color = sprite_material.albedo_color

	# Tween can only function inside the scene tree so we need a node inside the 
	# scene tree to instantiate the tween
	var tween = Helper.map_manager.level_generator.create_tween()
	
	tween.tween_property(sprite_material, "albedo_color", Color(1, 1, 1, 0.5), 0.1).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(sprite_material, "albedo_color", original_material_color, 0.1).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT).set_delay(0.1)

	tween.finished.connect(_on_tween_finished)


# Function to reset animation state after hit animation
func _on_tween_finished():
	is_animating_hit = false


# Function to handle furniture destruction
func _die():
	add_corpse(furniture_transform.get_position())  # Add wreck or corpse
	if is_container():
		Helper.signal_broker.container_exited_proximity.emit(self)
	free_resources()  # Free resources
	queue_free()  # Remove the node from the scene tree


# Function to show a miss indicator
func show_miss_indicator():
	var miss_label = Label3D.new()
	miss_label.text = "Miss!"
	miss_label.modulate = Color(1, 0, 0)  # Red color
	miss_label.font_size = 64
	Helper.map_manager.level_generator.get_tree().get_root().add_child(miss_label)
	miss_label.position = furniture_transform.get_position() + Vector3(0, 2, 0)  # Slightly above the furniture
	miss_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED

	# Animate the miss indicator to disappear quickly
	# Tween can only function inside the scene tree so we need a node inside the 
	# scene tree to instantiate the tween
	var tween = Helper.map_manager.level_generator.create_tween()

	tween.tween_property(miss_label, "modulate:a", 0, 0.5).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	tween.finished.connect(func():
		miss_label.queue_free()  # Properly free the miss_label node
	)
