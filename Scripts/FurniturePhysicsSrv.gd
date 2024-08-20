class_name FurniturePhysicsSrv
extends Node3D

# Variables to store furniture data
var furniture_transform: FurnitureTransform
var furnitureJSON: Dictionary
var dfurniture: DFurniture
var collider: RID
var shape: RID
var mesh_instance: RID
var sprite_material: StandardMaterial3D
var sprite_mesh: PlaneMesh
var myworld3d: World3D
var current_chunk: Chunk
var in_starting_chunk: bool = false
var container: ContainerItem = null
var elapsed_time: float = 0.0
var is_animating_hit: bool = false
var current_health: float = 10.0
var original_material_color: Color = Color(1, 1, 1)  # Store the original material color
# Variables to manage the container if this furniture is a container
var inventory: InventoryStacked  # Holds the inventory for the container
var itemgroup: String  # The ID of an itemgroup that it creates loot from


signal about_to_be_destroyed(me: FurniturePhysicsSrv)

# Inner class to manage position, rotation, and size
# Inner class to manage position, rotation, and size
class FurnitureTransform:
	var posx: float
	var posy: float
	var posz: float
	var rot: int
	var width: float
	var depth: float
	var height: float
	var chunk_pos: Vector2 = Vector2(0,0)  # New variable to track the current chunk position

	signal chunk_changed(new_chunk_pos: Vector2)  # Signal to emit when chunk position updates

	func _init(myposition: Vector3, myrotation: int, size: Vector3):
		width = size.x
		depth = size.z
		height = size.y
		posx = myposition.x
		posy = myposition.y
		posz = myposition.z
		rot = myrotation
		chunk_pos = Helper.overmap_manager.get_cell_pos_from_global_pos(posx, posz)  # Initialize chunk_pos

	func get_position() -> Vector3:
		return Vector3(posx, posy, posz)

	func set_position(new_position: Vector3):
		posx = new_position.x
		posy = new_position.y
		posz = new_position.z
		
		# Calculate the new chunk position based on the updated position
		var new_chunk_pos: Vector2 = Helper.overmap_manager.get_cell_pos_from_global_pos(posx, posz)
		
		# Check if the chunk position has changed
		if new_chunk_pos != chunk_pos:
			chunk_pos = new_chunk_pos
			chunk_changed.emit(chunk_pos)  # Emit the signal if chunk position changes

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

	func get_sprite_transform() -> Transform3D:
		var adjusted_position = get_position() + Vector3(0, 0.01, 0)
		return Transform3D(Basis(Vector3(0, 1, 0), deg_to_rad(rot)), adjusted_position)

	func get_visual_transform() -> Transform3D:
		return Transform3D(Basis(Vector3(0, 1, 0), deg_to_rad(rot)), get_position())

	func correct_new_position():
		posy += 1



# Initialize the furniture object
func _init(furniturepos: Vector3, newFurnitureJSON: Dictionary, world3d: World3D):
	furnitureJSON = newFurnitureJSON
	dfurniture = Gamedata.furnitures.by_id(furnitureJSON.id)
	myworld3d = world3d

	# Size of the collider will be a uniform sphere
	var furniture_size: Vector3 = Vector3(0.3,0.3,0.3)

	# Initialize the furniture transform
	furniture_transform = FurnitureTransform.new(furniturepos, furnitureJSON.get("rotation", 0), furniture_size)

	if is_new_furniture():
		furniture_transform.correct_new_position()

	setup_physics_properties()
	create_visual_instance()
	set_new_rotation(furnitureJSON.get("rotation", 0))
	add_container()  # Adds container if the furniture is a container

	# Final debug statement to confirm the final position after all setups
	print("Final furniture position after setup: ", furniture_transform.get_position())


# Setup the physics properties of the furniture
func setup_physics_properties() -> void:
	# Create a spherical collision shape
	shape = PhysicsServer3D.sphere_shape_create()
	
	# Set the radius of the sphere to match the furniture's size
	var radius = furniture_transform.width
	PhysicsServer3D.shape_set_data(shape, radius)

	# Create and configure the physics body
	collider = PhysicsServer3D.body_create()
	PhysicsServer3D.body_set_mode(collider, PhysicsServer3D.BODY_MODE_RIGID)
	PhysicsServer3D.body_set_space(collider, myworld3d.space)
	PhysicsServer3D.body_add_shape(collider, shape)

	var mytransform = furniture_transform.get_visual_transform()
	PhysicsServer3D.body_set_state(collider, PhysicsServer3D.BODY_STATE_TRANSFORM, mytransform)

	# Set the physics parameters such as mass, linear damp, and angular damp
	PhysicsServer3D.body_set_param(collider, PhysicsServer3D.BODY_PARAM_MASS, dfurniture.weight)
	PhysicsServer3D.body_set_param(collider, PhysicsServer3D.BODY_PARAM_LINEAR_DAMP, 59)
	PhysicsServer3D.body_set_param(collider, PhysicsServer3D.BODY_PARAM_ANGULAR_DAMP, 59)

	# Set collision layers and masks
	set_collision_layers_and_masks()

	# Set the force integration callback to update the visual position
	PhysicsServer3D.body_set_force_integration_callback(collider, _moved)


# Handle movement logic when the furniture changes position and rotation
func _moved(state: PhysicsDirectBodyState3D) -> void:
	# Get the new position and rotation from the physics state
	var new_position = state.transform.origin
	var new_rotation = state.transform.basis.get_euler().y

	# Safely convert rotation to degrees and round to the nearest integer
	var myrotation_degrees = rad_to_deg(new_rotation)
	var rounded_rotation = int(round(myrotation_degrees))

	# Update the internal furniture position and rotation
	furniture_transform.set_position(new_position)
	furniture_transform.set_rotation(rounded_rotation)

	# Update the visual instance's position and rotation to match the collider's state
	RenderingServer.instance_set_transform(mesh_instance, furniture_transform.get_visual_transform())


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

# Function to calculate the size of the sprite (2D)
func calculate_sprite_size() -> Vector2:
	if dfurniture.sprite:
		var sprite_width = dfurniture.sprite.get_width() / 100.0  # Convert pixels to meters
		var sprite_height = dfurniture.sprite.get_height() / 100.0  # Convert pixels to meters
		return Vector2(sprite_width, sprite_height)  # Return size as Vector2
	return Vector2(0.5, 0.5)  # Default size if texture is not set


# Create the visual instance using RenderingServer
func create_visual_instance() -> void:
	# Calculate the sprite size based on the texture dimensions
	var sprite_size = calculate_sprite_size()

	# Create a new PlaneMesh and set its size based on the sprite dimensions
	sprite_mesh = PlaneMesh.new()
	sprite_mesh.size = sprite_size

	# Initialize the sprite material with the sprite texture
	sprite_material = StandardMaterial3D.new()
	sprite_material.albedo_texture = dfurniture.sprite
	# Ensure transparency is correctly set (debugging transparency issues)
	sprite_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	sprite_mesh.material = sprite_material

	# Create a new instance in the RenderingServer
	mesh_instance = RenderingServer.instance_create()
	RenderingServer.instance_set_base(mesh_instance, sprite_mesh)
	RenderingServer.instance_set_scenario(mesh_instance, myworld3d.scenario)

	# Get the transform for the sprite
	var mytransform = furniture_transform.get_sprite_transform()

	# Set the transform for the mesh instance in the RenderingServer
	RenderingServer.instance_set_transform(mesh_instance, mytransform)

	# Ensure the sprite is visible and not being culled
	RenderingServer.instance_set_visible(mesh_instance, true)



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
	
	RenderingServer.instance_set_transform(mesh_instance, mytransform)


# Clean up and free resources
func free_resources() -> void:
	about_to_be_destroyed.emit(self)
	PhysicsServer3D.free_rid(collider)
	PhysicsServer3D.free_rid(shape)
	RenderingServer.free_rid(mesh_instance)
	sprite_mesh.queue_free()

	# Clear the reference to the DFurniture data if necessary
	dfurniture = null


# Only previously saved furniture will have the global_position_x key.
# Returns true if this is a new furniture
# Returns false if this is a previously saved furniture
func is_new_furniture() -> bool:
	return not furnitureJSON.has("global_position_x")

# When the furniture gets hit by an attack
# attack: a dictionary with the "damage" and "hit_chance" properties
func get_hit(attack: Dictionary):
	# Extract damage and hit_chance from the dictionary
	var damage = attack.damage
	var hit_chance = attack.hit_chance

	# Calculate actual hit chance considering moveable furniture bonus
	var actual_hit_chance = hit_chance + 0.20 # Boost hit chance by 20%

	# Determine if the attack hits
	if randf() <= actual_hit_chance:
		# Attack hits
		current_health -= damage
		if current_health <= 0:
			_die()
		else:
			if not is_animating_hit:
				animate_hit()
	else:
		# Attack misses, create a visual indicator
		show_miss_indicator()

# The furniture will move slightly in a random direction to indicate that it's hit
# Then it will return to its original position
func animate_hit() -> void:
	is_animating_hit = true
	original_material_color = sprite_material.albedo_color

	# Tween can only function inside the scene tree so we need a node inside the 
	# scene tree to instantiate the tween
	var tween = Helper.map_manager.level_generator.create_tween()
	
	tween.tween_property(sprite_material, "albedo_color", Color(1, 1, 1, 0.5), 0.1).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(sprite_material, "albedo_color", original_material_color, 0.1).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT).set_delay(0.1)

	tween.finished.connect(_on_tween_finished)


# The furniture is done animating the hit
func _on_tween_finished() -> void:
	is_animating_hit = false


# Function to show a miss indicator
func show_miss_indicator():
	var miss_label = Label3D.new()
	miss_label.text = "Miss!"
	miss_label.modulate = Color(1, 0, 0)
	miss_label.font_size = 64
	Helper.map_manager.level_generator.get_tree().get_root().add_child(miss_label)
	miss_label.position = furniture_transform.get_position()
	miss_label.position.y += 2
	miss_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		
	# Animate the miss indicator to disappear quickly
	var tween = Helper.map_manager.level_generator.create_tween()
	tween.tween_property(miss_label, "modulate:a", 0, 0.5).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	tween.finished.connect(func():
		miss_label.queue_free()  # Properly free the miss_label node
	)

# Handle furniture death
func _die() -> void:
	current_chunk.remove_furniture_from_chunk(self)
	add_corpse(furniture_transform.get_position())
	queue_free()  # Remove the furniture from the scene


# When the furniture is destroyed, it leaves a wreck behind
# When the furniture is destroyed, it leaves a wreck behind
func add_corpse(pos: Vector3) -> void:
	if dfurniture.destruction.get_data().is_empty():
		return # No destruction data, so no corpse

	var itemdata: Dictionary = {}
	itemdata["global_position_x"] = pos.x
	itemdata["global_position_y"] = pos.y
	itemdata["global_position_z"] = pos.z
	
	var fursprite = dfurniture.destruction.sprite
	if fursprite:
		itemdata["texture_id"] = fursprite

	var myitemgroup = dfurniture.destruction.group
	if myitemgroup:
		itemdata["itemgroups"] = [myitemgroup]

	var newItem: ContainerItem = ContainerItem.new(itemdata)
	newItem.add_to_group("mapitems")
	Helper.map_manager.level_generator.get_tree().get_root().add_child(newItem)

	# Transfer items from this container to the corpse
	if container:
		for item in container.get_items():
			newItem.insert_item(item)


# Add a container to the furniture if it is defined as a container
func add_container() -> void:
	if is_container():
		_create_inventory()  # Initialize the inventory
		if is_new_furniture():
			create_loot()  # Populate the container if it's a new furniture
		else:
			deserialize_container_data()  # Load existing data for a saved furniture

# Create and initialize the inventory
func _create_inventory() -> void:
	inventory = InventoryStacked.new()
	inventory.capacity = 1000
	inventory.item_protoset = ItemManager.item_protosets
	inventory.item_removed.connect(_on_item_removed)
	inventory.item_added.connect(_on_item_added)

# Populate the container with items from an itemgroup
func create_loot() -> void:
	itemgroup = populate_container_from_itemgroup()
	if not itemgroup or itemgroup == "":
		return  # No itemgroup to populate from
	
	var ditemgroup: DItemgroup = Gamedata.itemgroups.by_id(itemgroup)
	if ditemgroup:
		if ditemgroup.mode == "Collection":
			_add_items_to_inventory_collection_mode(ditemgroup.items)
		elif ditemgroup.mode == "Distribution":
			_add_items_to_inventory_distribution_mode(ditemgroup.items)

# Populate the container with items based on the itemgroup's collection mode
func _add_items_to_inventory_collection_mode(items: Array[DItemgroup.Item]) -> void:
	for item_object in items:
		if randi_range(0, 100) <= item_object.probability:
			var quantity = randi_range(item_object.minc, item_object.maxc)
			_add_item_to_inventory(item_object.id, quantity)

# Populate the container with a randomly selected item based on distribution mode
func _add_items_to_inventory_distribution_mode(items: Array[DItemgroup.Item]) -> void:
	var total_probability = 0
	for item_object in items:
		total_probability += item_object.probability

	var random_value = randi_range(0, total_probability - 1)
	var cumulative_probability = 0

	for item_object in items:
		cumulative_probability += item_object.probability
		if random_value < cumulative_probability:
			var quantity = randi_range(item_object.minc, item_object.maxc)
			_add_item_to_inventory(item_object.id, quantity)
			return  # Item added, stop processing

# Add an item to the inventory with the specified quantity
func _add_item_to_inventory(item_id: String, quantity: int) -> void:
	var ditem: DItem = Gamedata.items.by_id(item_id)
	if ditem and quantity > 0:
		while quantity > 0:
			var stack_size = min(quantity, ditem.max_stack_size)
			var item = inventory.create_and_add_item(item_id)
			InventoryStacked.set_item_stack_size(item, stack_size)
			quantity -= stack_size

# Deserialize and apply saved container data
func deserialize_container_data() -> void:
	if "items" in furnitureJSON["Function"]["container"]:
		deserialize_and_apply_items(furnitureJSON["Function"]["container"]["items"])

# Deserialize the container's items and apply them to the inventory
func deserialize_and_apply_items(items_data: Dictionary) -> void:
	inventory.deserialize(items_data)

# Handle the event when an item is removed from the inventory
func _on_item_removed(_item: InventoryItem) -> void:
	if inventory.get_items().size() == 0:
		_on_item_removed(null)

# Handle the event when an item is added to the inventory
func _on_item_added(_item: InventoryItem) -> void:
	# Update the container's state based on the new item
	pass

# Check if this furniture acts as a container
func is_container() -> bool:
	return dfurniture.function.is_container


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


# Returns the inventorystacked that this furniture holds
func get_inventory() -> InventoryStacked:
	return inventory


func get_sprite() -> Texture:
	return dfurniture.sprite
