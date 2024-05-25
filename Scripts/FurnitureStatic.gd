class_name FurnitureStatic
extends StaticBody3D

# This is a standalone script that is not attached to any node. 
# This is the static version of furniture. There is also FurniturePhysics.gd.
# This class is instanced by Chunk.gd when a map needs static furniture, like a bed or fridge


# Since we can't access the scene tree in a thread, we store the position in a variable and read that
var furnitureposition: Vector3
var furniturerotation: int
var furnitureJSON: Dictionary # The json that defines this furniture on the map
var furnitureJSONData: Dictionary # The json that defines this furniture's basics in general
var sprite: Sprite3D = null
var collider: CollisionShape3D = null
var is_door: bool = false
var door_state: String = "Closed"  # Default state
var container: ContainerItem = null # Reference to the container, if this furniture acts as one

var corpse_scene: PackedScene = preload("res://Defaults/Mobs/mob_corpse.tscn")
var current_health: float = 100.0

var is_animating_hit: bool = false # flag to prevent multiple blink actions
var original_position: Vector3 # To return to original position after blinking

func _ready():
	position = furnitureposition
	set_new_rotation(furniturerotation)
	var new_chunk = Helper.map_manager.get_chunk_from_position(furnitureposition)
	new_chunk.add_furniture_to_chunk(self)
	check_door_functionality()
	update_door_visuals()
	# Add the container as a child on the same position as this furniture
	add_container(Vector3(0,0,0))
	original_position = sprite.global_transform.origin

# Check if this furniture acts as a door
# We check if the door data for this unique furniture has been set
# Otherwise we check the general json data for this furniture
func check_door_functionality():
	if furnitureJSON.get("Function", {}).get("door") or furnitureJSONData.get("Function", {}).get("door"):
		is_door = true
		door_state = furnitureJSON.get("Function", {}).get("door", "Closed")

func interact():
	if is_door:
		toggle_door()

# We set the door property in furnitureJSON, which holds the data
# For this unique furniture
func toggle_door():
	door_state = "Open" if door_state == "Closed" else "Closed"
	furnitureJSON["Function"] = {"door": door_state}
	update_door_visuals()

# Will update the sprite of this furniture and set a collisionshape based on it's size
func set_sprite(newSprite: Texture):
	if not sprite:
		sprite = Sprite3D.new()
		add_child.call_deferred(sprite)
	var uniqueTexture = newSprite.duplicate(true) # Duplicate the texture
	sprite.texture = uniqueTexture

	# Calculate new dimensions for the collision shape
	var sprite_width = newSprite.get_width()
	var sprite_height = newSprite.get_height()

	var new_x = sprite_width / 100.0 # 0.1 units per 10 pixels in width
	var new_z = sprite_height / 100.0 # 0.1 units per 10 pixels in height
	var new_y = 0.8 # Any lower will make the player's bullet fly over it

	# Update the collision shape
	var new_shape = BoxShape3D.new()
	new_shape.extents = Vector3(new_x / 2.0, new_y / 1.0, new_z / 2.0) # BoxShape3D extents are half extents

	collider = CollisionShape3D.new()
	collider.shape = new_shape
	add_child.call_deferred(collider)


func get_sprite() -> Texture:
	return sprite.texture


func update_door_visuals():
	if not is_door: return
	
	var angle = 90 if door_state == "Open" else 0
	var position_offset = Vector3(-0.5, 0, -0.5) if door_state == "Open" else Vector3.ZERO
	apply_transform_to_sprite_and_collider(angle, position_offset)

func apply_transform_to_sprite_and_collider(rotationdegrees, position_offset):
	var doortransform = Transform3D().rotated(Vector3.UP, deg_to_rad(rotationdegrees))
	doortransform.origin = position_offset
	sprite.set_transform(doortransform)
	collider.set_transform(doortransform)
	sprite.rotation_degrees.x = 90

# Set the rotation for this furniture. We have to do some minor calculations or it will end up wrong
func set_new_rotation(amount: int):
	var rotation_amount = amount
	if amount == 180:
		rotation_amount = amount - 180
	elif amount == 0:
		rotation_amount = amount + 180
	else:
		rotation_amount = amount

	# Rotate the entire StaticBody3D node, including its children
	rotation_degrees.y = rotation_amount
	sprite.rotation_degrees.x = 90 # Static 90 degrees to point at camera

func get_my_rotation() -> int:
	return furniturerotation

# Function to make it's own shape and texture based on an id and position
# This function is called by a Chunk to construct it's blocks
func construct_self(furniturepos: Vector3, newFurnitureJSON: Dictionary):
	furnitureJSON = newFurnitureJSON
	# Position furniture at the center of the block by default
	furnitureposition = furniturepos
	# Previously saved furniture do not need to be raised
	if is_new_furniture():
		furnitureposition.y += 0.025 # Move the furniture to slightly above the block 
	add_to_group("furniture")

	# Find out if we need to apply edge snapping
	furnitureJSONData = Gamedata.get_data_by_id(Gamedata.data.furniture,furnitureJSON.id)
	var edgeSnappingDirection = furnitureJSONData.get("edgesnapping", "None")

	var furnitureSprite: Texture = Gamedata.get_sprite_by_id(Gamedata.data.furniture,furnitureJSON.id)
	set_sprite(furnitureSprite)
	
	# Calculate the size of the furniture based on the sprite dimensions
	var spriteWidth = furnitureSprite.get_width() / 100.0 # Convert pixels to meters (assuming 100 pixels per meter)
	var spriteDepth = furnitureSprite.get_height() / 100.0 # Convert pixels to meters
	
	var newRot = furnitureJSON.get("rotation", 0)

	# Apply edge snapping if necessary. Previously saved furniture have the global_position_x. 
	# They do not need to apply edge snapping again
	if edgeSnappingDirection != "None" and not newFurnitureJSON.has("global_position_x"):
		furnitureposition = apply_edge_snapping(furnitureposition, edgeSnappingDirection, \
		spriteWidth, spriteDepth, newRot, furniturepos)

	furniturerotation = newRot
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
		"global_position_x": furnitureposition.x,
		"global_position_y": furnitureposition.y,
		"global_position_z": furnitureposition.z,
		"rotation": get_my_rotation(),
	}
	
	if "Function" in furnitureJSONData and "door" in furnitureJSONData.Function:
		newfurniturejson["Function"] = {"door": door_state}
	
	# Check for container functionality and save item list if applicable
	if "Function" in furnitureJSONData and "container" in furnitureJSONData["Function"]:
		# Initialize the 'Function' sub-dictionary if not already present
		if "Function" not in newfurniturejson:
			newfurniturejson["Function"] = {}
		
		# Check if this furniture has a container attached and if it has items
		if container:
			var item_ids = container.get_item_ids()
			if item_ids.size() > 0:
				var containerdata = container.get_inventory().serialize()
				newfurniturejson["Function"]["container"] = {"items": containerdata}
			else:
				# No items in the container, store the container as empty
				newfurniturejson["Function"]["container"] = {}

	return newfurniturejson


# If this furniture is a container, it will add a container node to the furniture.
func add_container(pos: Vector3):
	if "Function" in furnitureJSONData and "container" in furnitureJSONData["Function"]:
		container = ContainerItem.new()
		container.construct_self(pos)
		handle_container_population()
		add_child(container)

# Check if this is a new furniture or if it is one that was previously saved.
func handle_container_population():
	if is_new_furniture():
		populate_container_from_itemgroup()
	else:
		deserialize_container_data()

# If there is an itemgroup assigned to the furniture, it will be added to the container.
# Which will fill up the container with items from the itemgroup.
func populate_container_from_itemgroup():
	var itemgroup = furnitureJSONData["Function"]["container"].get("itemgroup", "")
	if itemgroup:
		container.itemgroup = itemgroup
	else:
		print_debug("No itemgroup found for container in furniture ID: " + str(furnitureJSON.id))

# It will deserialize the container data if the furniture is not new.
func deserialize_container_data():
	if "items" in furnitureJSON["Function"]["container"]:
		container.get_inventory().deserialize(furnitureJSON["Function"]["container"]["items"])
	else:
		print_debug("No items to deserialize in container for furniture ID: " + str(furnitureJSON.id))

# Only previously saved furniture will have the global_position_x key.
# Returns true if this is a new furniture
# Returns false if this is a previously saved furniture
func is_new_furniture() -> bool:
	return not furnitureJSON.has("global_position_x")

# The furniture will move 0.2 meters in a random direction to indicate that it's hit
# Then it will return to its original position
func animate_hit():
	is_animating_hit = true

	var directions = [Vector3(0.1, 0, 0), Vector3(-0.1, 0, 0), Vector3(0, 0, 0.1), Vector3(0, 0, -0.1)]
	var random_direction = directions[randi() % directions.size()]

	var tween = create_tween()
	tween.tween_property(sprite, "global_transform:origin", sprite.global_transform.origin + random_direction, 0.1).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(sprite, "global_transform:origin", original_position, 0.1).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT).set_delay(0.1)

	tween.finished.connect(_on_tween_finished)

# The furniture is done blinking so we reset the relevant variables
func _on_tween_finished():
	is_animating_hit = false


func get_hit(damage):
	if can_be_destroyed():
		current_health -= damage
		if current_health <= 0:
			_die()
		else:
			if not is_animating_hit:
				animate_hit()

func _die():
	add_corpse.call_deferred(global_position)
	queue_free()
	

# When the furniture is destroyed, it leaves a wreck behind
func add_corpse(pos: Vector3):
	if can_be_destroyed():
		var newItem: ContainerItem = ContainerItem.new()
		
		var itemgroup = furnitureJSONData.get("destruction", {}).get("group", "")
		if itemgroup:
			newItem.itemgroup = itemgroup
		
		newItem.add_to_group("mapitems")
		newItem.construct_self(pos)
		
		var fursprite = furnitureJSONData.get("destruction", {}).get("sprite", null)
		if fursprite:
			newItem.set_texture(fursprite)
		
		# Finally add the new item with possibly set loot group to the tree
		get_tree().get_root().add_child.call_deferred(newItem)
		
		# Check if container has items and insert them into the new item
		if container:
			var items = container.get_items()
			for item in items:
				if newItem.insert_item(item):
					print("Item inserted successfully")


func _disassemble():
	add_wreck.call_deferred(global_position)
	queue_free()
	

# When the furniture is destroyed, it leaves a wreck behind
func add_wreck(pos: Vector3):
	if can_be_disassembled():
		var newItem: ContainerItem = ContainerItem.new()
		
		var itemgroup = furnitureJSONData.get("disassembly", {}).get("group", "")
		if itemgroup:
			newItem.itemgroup = itemgroup
		
		newItem.add_to_group("mapitems")
		newItem.construct_self(pos)
		
		var fursprite = furnitureJSONData.get("disassembly", {}).get("sprite", null)
		if fursprite:
			newItem.set_texture(fursprite)
		
		# Finally add the new item with possibly set loot group to the tree
		get_tree().get_root().add_child.call_deferred(newItem)

func can_be_destroyed() -> bool:
	return "destruction" in furnitureJSONData

func can_be_disassembled() -> bool:
	return "disassembly" in furnitureJSONData
