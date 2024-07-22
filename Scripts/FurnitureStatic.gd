class_name FurnitureStatic
extends StaticBody3D

# This is a standalone script that is not attached to any node. 
# This is the static version of furniture. There is also FurniturePhysics.gd.
# This class is instanced by Chunk.gd when a map needs static furniture, like a bed or fridge


# Since we can't access the scene tree in a thread, we store the position in a variable and read that
var furniture_position: Vector3
var furniture_rotation: int
var furnitureJSON: Dictionary # The json that defines this furniture on the map
var dfurniture: DFurniture # The json that defines this furniture's basics in general
var sprite: Sprite3D = null
var mesh_instance: MeshInstance3D
var collider: CollisionShape3D = null
var is_door: bool = false
var door_state: String = "Closed"  # Default state
var container: ContainerItem = null # Reference to the container, if this furniture acts as one

var corpse_scene: PackedScene = preload("res://Defaults/Mobs/mob_corpse.tscn")
var current_health: float = 100.0

var is_animating_hit: bool = false # flag to prevent multiple blink actions
var original_position: Vector3 # To return to original position after blinking


# Function to make its own shape and texture based on an id and position
# This function is called by a Chunk to construct it's blocks
func _init(furniturepos: Vector3, newFurnitureJSON: Dictionary):
	furnitureJSON = newFurnitureJSON
	# Position furniture at the center of the block by default
	furniture_position = furniturepos
	furniture_rotation = furnitureJSON.get("rotation", 0)
	dfurniture = Gamedata.furnitures.by_id(furnitureJSON.id)
	
	# Previously saved furniture do not need to be raised
	if is_new_furniture():
		furniture_position.y += 0.025 # Move the furniture to slightly above the block 
	add_to_group("furniture")
	set_sprite(dfurniture.sprite)
	apply_edge_snapping_if_needed()
	set_collision_layers()


# Ready function to set initial position and rotation
func _ready():
	position = furniture_position
	set_new_rotation(furniture_rotation)
	check_door_functionality()
	update_door_visuals()
	adjust_sprite_and_mesh_height()
	add_container()
	original_position = sprite.global_transform.origin


# Adjust the sprite and mesh heights based on support shape
func adjust_sprite_and_mesh_height():
	var new_height = dfurniture.support_shape.height
	if new_height:
		sprite.position.y = 0.01 + new_height
		mesh_instance.position.y = new_height / 2
	else:
		# The default size is 0.5
		sprite.position.y = 0.51 # Slightly above the default size
		mesh_instance.position.y = 0.25 # Half the default size


# Apply edge snapping if necessary. Previously saved does not need to apply edge snapping again
func apply_edge_snapping_if_needed():
	if dfurniture.edgesnapping != "None" and is_new_furniture():
		# Calculate the size of the furniture based on the sprite dimensions
		var sprite_width = dfurniture.sprite.get_width() / 100.0 # Convert pixels to meters 
		var sprite_depth = dfurniture.sprite.get_height() / 100.0 # (assuming 100 pixels per meter)
		furniture_position = apply_edge_snapping(
			furniture_position, dfurniture.edgesnapping, 
			sprite_width, sprite_depth, furniture_rotation, furniture_position
		)


# Set collision layers and masks
func set_collision_layers():
	# Set collision layer to layer 3 (static obstacles layer)
	collision_layer = 1 << 2  # Layer 3 is 1 << 2

	# Set collision mask to include layers 1, 2, 3, 4, 5, and 6
	collision_mask = (1 << 0) | (1 << 1) | (1 << 2) | (1 << 3) | (1 << 4) | (1 << 5)
	# Explanation:
	# - 1 << 0: Layer 1 (player layer)
	# - 1 << 1: Layer 2 (enemy layer)
	# - 1 << 2: Layer 3 (movable obstacles layer)
	# - 1 << 3: Layer 4 (static obstacles layer)
	# - 1 << 4: Layer 5 (friendly projectiles layer)
	# - 1 << 5: Layer 6 (enemy projectiles layer)


# Check if this furniture acts as a door
# We check if the door data for this unique furniture has been set
# Otherwise we check the general json data for this furniture
func check_door_functionality():
	is_door = not dfurniture.function.door == "None"
	door_state = dfurniture.function.door


func interact():
	if is_door:
		toggle_door()


# We set the door property in furnitureJSON, which holds the data
# For this unique furniture
func toggle_door():
	door_state = "Open" if door_state == "Closed" else "Closed"
	furnitureJSON["Function"] = {"door": door_state}
	update_door_visuals()


# Will update the sprite of this furniture and set a collisionshape based on its size
func set_sprite(new_sprite: Texture):
	if not sprite:
		sprite = Sprite3D.new()
		sprite.shaded = true
		add_child.call_deferred(sprite)
	var uniqueTexture = new_sprite.duplicate(true) # Duplicate the texture
	sprite.texture = uniqueTexture

	# Calculate new dimensions for the collision shape
	var sprite_width = new_sprite.get_width()
	var sprite_height = new_sprite.get_height()

	var new_x = sprite_width / 100.0 # 0.1 units per 10 pixels in width
	var new_z = sprite_height / 100.0 # 0.1 units per 10 pixels in height

	# Set support shape
	var shape = dfurniture.support_shape.shape
	var height = dfurniture.support_shape.height
	var transparent = dfurniture.support_shape.transparent

	var color = Color.html(dfurniture.support_shape.color)  # Default to white

	if shape == "Box":
		var width_scale = dfurniture.support_shape.width_scale / 100.0
		var depth_scale = dfurniture.support_shape.depth_scale / 100.0
		var scaled_x = new_x * width_scale
		var scaled_z = new_z * depth_scale
		create_shape("Box", Vector3(scaled_x, height, scaled_z), color, transparent)
	elif shape == "Cylinder":
		var radius_scale = dfurniture.support_shape.radius_scale / 100.0
		var scaled_radius = (new_x * radius_scale)/2 # Since it's the radius we need half
		create_shape("Cylinder", Vector3(scaled_radius, height, scaled_radius), color, transparent)


# Function to create the shape based on the given parameters
func create_shape(shape_type: String, size: Vector3, color: Color, transparent: bool):
	if shape_type == "Box":
		# Create and add BoxCollider instance
		collider = create_collider(size)
		add_child.call_deferred(collider)

		# Create and add BoxMesh instance
		var box_mesh_instance = create_box_mesh(size, color, transparent)
		add_child.call_deferred(box_mesh_instance)
	elif shape_type == "Cylinder":
		# Update the collision shape
		var new_shape = CylinderShape3D.new()
		new_shape.height = size.y
		new_shape.radius = size.x

		collider = CollisionShape3D.new()
		collider.shape = new_shape
		add_child.call_deferred(collider)

		# Create and add CylinderMesh instance
		var cylinder_mesh_instance = create_cylinder_mesh(size.y, size.x, color, transparent)
		add_child.call_deferred(cylinder_mesh_instance)


# Function to create a BoxShape3D collider based on the given size
func create_collider(size: Vector3) -> CollisionShape3D:
	var new_shape = BoxShape3D.new()
	# If size.y is reduced to half extents, the raycast that collides with doors to interact
	# with them will no longer be able to hit them. That's why we don't reduce size.y
	new_shape.extents = Vector3(size.x / 2.0, size.y, size.z / 2.0) # Only x and z are half extents

	var mycollider = CollisionShape3D.new()
	mycollider.shape = new_shape
	return mycollider


func create_box_mesh(size: Vector3, albedo_color: Color, transparent: bool) -> MeshInstance3D:
	var box_mesh = BoxMesh.new()
	box_mesh.size = size
	var material = StandardMaterial3D.new()
	material.albedo_color = albedo_color
	if transparent:
		material.flags_transparent = true
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	box_mesh.material = material

	mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = box_mesh
	return mesh_instance


func create_cylinder_mesh(height: float, radius: float, albedo_color: Color, transparent: bool) -> MeshInstance3D:
	var cylinder_mesh = CylinderMesh.new()
	cylinder_mesh.height = height
	cylinder_mesh.top_radius = radius
	cylinder_mesh.bottom_radius = radius
	var material = StandardMaterial3D.new()
	material.albedo_color = albedo_color
	if transparent:
		material.flags_transparent = true
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cylinder_mesh.material = material

	mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = cylinder_mesh
	return mesh_instance


func get_sprite() -> Texture:
	return sprite.texture


# Set the rotation for this furniture. We have to do some minor calculations or it will end up wrong
func set_new_rotation(amount: int):
	var rotation_amount = amount
	if amount == 180:
		rotation_amount = amount - 180
	elif amount == 0:
		rotation_amount = amount + 180
	# Rotate the entire StaticBody3D node, including its children
	rotation_degrees.y = rotation_amount
	sprite.rotation_degrees.x = 90 # Static 90 degrees to point at camera


func get_my_rotation() -> int:
	return furniture_rotation


# If edge snapping has been set in the furniture editor, we will apply it here.
# The direction refers to the 'backside' of the furniture, which will be facing the edge of the block
# This is needed to put furniture against the wall, or get a fence at the right edge
func apply_edge_snapping(newpos, direction, width, depth, newRot, furniturepos) -> Vector3:
	# Block size, a block is 1x1 meters
	var blockSize = Vector3(1.0, 1.0, 1.0)
	
	# Adjust position based on edgesnapping direction and rotation
	match direction:
		"North":
			newpos.z -= blockSize.z / 2 - depth / 2
		"South":
			newpos.z += blockSize.z / 2 - depth / 2
		"East":
			newpos.x += blockSize.x / 2 - width / 2
		"West":
			newpos.x -= blockSize.x / 2 - width / 2
		# Add more cases if needed
	
	# Consider rotation if necessary
	newpos = rotate_position_around_block_center(newpos, newRot, furniturepos)
	
	return newpos


# Called when applying edge-snapping so it's put into the right position
func rotate_position_around_block_center(newpos, newRot, block_center) -> Vector3:
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


# Returns this furniture's data for saving
func get_data() -> Dictionary:
	var newfurniturejson = {
		"id": furnitureJSON.id,
		"moveable": false,
		"global_position_x": furniture_position.x,
		"global_position_y": furniture_position.y,
		"global_position_z": furniture_position.z,
		"rotation": get_my_rotation(),
	}
	
	if is_door:
		newfurniturejson["Function"] = {"door": door_state}
	
	# Check if this furniture has a container attached and if it has items
	if container:
		# Initialize the 'Function' sub-dictionary if not already present
		if "Function" not in newfurniturejson:
			newfurniturejson["Function"] = {}
		var item_ids = container.get_item_ids()
		if item_ids.size() > 0:
			var containerdata = container.get_inventory().serialize()
			newfurniturejson["Function"]["container"] = {"items": containerdata}
		else:
			# No items in the container, store the container as empty
			newfurniturejson["Function"]["container"] = {}

	return newfurniturejson


# If this furniture is a container, it will add a container node to the furniture.
func add_container():
	if dfurniture.function.is_container:
		var height = dfurniture.support_shape.height
		# Should be slightly above mesh so we add 0.01
		var pos: Vector3 = Vector3(0, height + 0.01, 0) if height > 0 else Vector3(0, 0.51, 0)
		var newcontainerjson: Dictionary = {
			"global_position_x": pos.x,
			"global_position_y": pos.y,
			"global_position_z": pos.z
		}
		var newfurniture: bool = is_new_furniture()
		if newfurniture:
			newcontainerjson["itemgroups"] = [populate_container_from_itemgroup()]
		container = ContainerItem.new(newcontainerjson)
		if not newfurniture:
			deserialize_container_data()
		add_child(container)


# If there is an itemgroup assigned to the furniture, it will be added to the container.
# It will check both furnitureJSON and furnitureJSONData for itemgroup information.
# The container will be filled with items from the itemgroup.
func populate_container_from_itemgroup() -> String:
	# Check if furnitureJSON contains an itemgroups array
	if furnitureJSON.has("itemgroups"):
		var itemgroups_array = furnitureJSON["itemgroups"]
		if itemgroups_array.size() > 0:
			var random_itemgroup = itemgroups_array[randi() % itemgroups_array.size()]
			return random_itemgroup
		else:
			print_debug("itemgroups array is empty in furnitureJSON")
	
	# Fallback to using itemgroup from furnitureJSONData if furnitureJSON.itemgroups does not exist
	var itemgroup = dfurniture.function.container_group
	if itemgroup:
		return itemgroup
	return ""


# It will deserialize the container data if the furniture is not new.
func deserialize_container_data():
	if "items" in furnitureJSON["Function"]["container"]:
		container.deserialize_and_apply_items(furnitureJSON["Function"]["container"]["items"])


# Only previously saved furniture will have the global_position_x key.
# Returns true if this is a new furniture
# Returns false if this is a previously saved furniture
func is_new_furniture() -> bool:
	return not furnitureJSON.has("global_position_x")


# Update the visuals of the door if it is a door
func update_door_visuals():
	if not is_door: return
	
	var angle = 90 if door_state == "Open" else 0
	var position_offset = Vector3(-0.5, 0, -0.5) if door_state == "Open" else Vector3.ZERO
	apply_transform_to_sprite_and_collider(angle, position_offset)


# Rotates the door while keeping the furniture's position. Only the sprite and collider move
func apply_transform_to_sprite_and_collider(rotationdegrees, position_offset):
	var doortransform = Transform3D().rotated(Vector3.UP, deg_to_rad(rotationdegrees))
	doortransform.origin = position_offset
	sprite.set_transform(doortransform)
	collider.set_transform(doortransform)
	mesh_instance.set_transform(doortransform)
	sprite.rotation_degrees.x = 90


# Animate the furniture color when it is hit
func animate_hit():
	is_animating_hit = true

	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(1, 1, 1, 0.5), 0.1).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.1).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT).set_delay(0.1)

	tween.finished.connect(_on_tween_finished)


# The furniture is done blinking so we reset the relevant variables
func _on_tween_finished():
	is_animating_hit = false


# When the furniture gets hit by an attack
# attack: a dictionary with the "damage" and "hit_chance" properties
func get_hit(attack: Dictionary):
	# Extract damage and hit_chance from the dictionary
	var damage = attack.damage
	var hit_chance = attack.hit_chance

	# Calculate actual hit chance considering static furniture bonus
	var actual_hit_chance = hit_chance + 0.25 # Boost hit chance by 25%

	# Determine if the attack hits
	if randf() <= actual_hit_chance:
		# Attack hits
		if can_be_destroyed():
			current_health -= damage
			if current_health <= 0:
				_die()
			else:
				if not is_animating_hit:
					animate_hit()
	else:
		# Attack misses, create a visual indicator
		show_miss_indicator()


# Function to show a miss indicator
func show_miss_indicator():
	var miss_label = Label3D.new()
	miss_label.text = "Miss!"
	miss_label.modulate = Color(1, 0, 0)
	miss_label.font_size = 64
	get_tree().get_root().add_child(miss_label)
	miss_label.position = original_position
	miss_label.position.y += 2
	miss_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		

	# Animate the miss indicator to disappear quickly
	var tween = create_tween()
	tween.tween_property(miss_label, "modulate:a", 0, 0.5).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	tween.finished.connect(func():
		miss_label.queue_free()  # Properly free the miss_label node
	)


# Handle furniture death
func _die():
	add_corpse.call_deferred(global_position)
	queue_free()
	

# When the furniture is destroyed, it leaves a wreck behind
func add_corpse(pos: Vector3):
	if can_be_destroyed():
		
		var newitemjson: Dictionary = {
			"global_position_x": pos.x,
			"global_position_y": pos.y,
			"global_position_z": pos.z
		}
		
		var itemgroup = dfurniture.destruction.group
		if itemgroup:
			newitemjson["itemgroups"] = [itemgroup]
		
		var newItem: ContainerItem = ContainerItem.new(newitemjson)
		newItem.add_to_group("mapitems")
		
		var fursprite = dfurniture.destruction.sprite
		if fursprite:
			newItem.set_texture(fursprite)
		
		# Finally add the new item with possibly set loot group to the tree
		get_tree().get_root().add_child.call_deferred(newItem)
		
		# Check if container has items and insert them into the new item
		if container:
			for item in container.get_items():
				newItem.insert_item(item)


func _disassemble():
	add_wreck.call_deferred(global_position)
	queue_free()
	

# When the furniture is destroyed, it leaves a wreck behind
func add_wreck(pos: Vector3):
	if can_be_disassembled():
		
		var newfurniturejson: Dictionary = {
			"global_position_x": pos.x,
			"global_position_y": pos.y,
			"global_position_z": pos.z
		}
		
		var itemgroup = dfurniture.disassembly.group
		if itemgroup:
			newfurniturejson["itemgroups"] = [itemgroup]
		
		var newItem: ContainerItem = ContainerItem.new(newfurniturejson)
		newItem.add_to_group("mapitems")
		
		var fursprite = dfurniture.disassembly.sprite
		if fursprite:
			newItem.set_texture(fursprite)
		
		# Finally add the new item with possibly set loot group to the tree
		get_tree().get_root().add_child.call_deferred(newItem)


# Check if the furniture can be destroyed
func can_be_destroyed() -> bool:
	return not dfurniture.destruction.get_data().is_empty()


# Check if the furniture can be disassembled
func can_be_disassembled() -> bool:
	return not dfurniture.disassembly.get_data().is_empty()
