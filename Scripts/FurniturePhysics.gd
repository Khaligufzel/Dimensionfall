class_name FurniturePhysics
extends RigidBody3D

# id for the furniture json. this will be used to load the data when creating a furniture
# when saving a mob in between levels, we will use some static json defined by this id
# and some dynamic json like the furniture health
var furnitureposition: Vector3 = Vector3()
var furniturerotation: int
var furnitureJSON: Dictionary # The json that defines this furniture
var sprite: Sprite3D = null
var last_rotation: int
var current_chunk: Chunk


var corpse_scene: PackedScene = preload("res://Defaults/Mobs/mob_corpse.tscn")
var current_health: float = 10.0


func _ready():
	set_position.call_deferred(furnitureposition)
	set_new_rotation(furniturerotation)
	last_rotation = furniturerotation


# Keep track of the furniture's position and rotation. It starts at 0,0,0 and the moves to it's
# assigned position after a timer. Until that has happened, we don't need to keep track of it's position
func _physics_process(_delta):
	if global_transform.origin != furnitureposition and \
	not global_transform.origin.x == 0 and not global_transform.origin.y == 0:
		_moved(global_transform.origin)
	var current_rotation = int(rotation_degrees.y)
	if current_rotation != last_rotation:
		last_rotation = current_rotation


func get_hit(damage):
	#3d
#	tween = create_tween()
#	tween.tween_property(get_node(sprite), "scale", get_node(sprite).scale * 1.35, 0.1)
#	tween.tween_property(get_node(sprite), "scale", original_scale, 0.1)
	
	current_health -= damage
	if current_health <= 0:
		_die()


func _die():
	add_corpse.call_deferred(global_position)
	queue_free()


func add_corpse(pos: Vector3):
	var newItem: ContainerItem = ContainerItem.new()
	newItem.add_to_group("mapitems")
	newItem.construct_self(pos)
	get_tree().get_root().add_child.call_deferred(newItem)


func set_new_rotation(amount: int):
	var rotation_amount = amount
	# Only previously saved furniture will have the global_position_x key. Rotation does not need adjustment
	if not furnitureJSON.has("global_position_x"):
		if amount == 180:
			rotation_amount = amount - 180
		elif amount == 0:
			rotation_amount = amount + 180
		else:
			rotation_amount = amount

	rotation_degrees.y = rotation_amount
	sprite.rotation_degrees.x = 90 # Static 90 degrees to point at camera


func set_sprite(newSprite: Texture):
	if not sprite:
		sprite = Sprite3D.new()
		add_child.call_deferred(sprite)
	var uniqueTexture = newSprite.duplicate(true) # Duplicate the texture
	sprite.texture = uniqueTexture

	# Create a new SphereShape3D for the collision shape
	var new_shape = SphereShape3D.new()
	new_shape.radius = 0.3
	new_shape.margin = 0.04

	# Update the collision shape
	var collider = CollisionShape3D.new()
	collider.shape = new_shape
	add_child.call_deferred(collider)


func get_my_rotation() -> int:
	var rot: int = int(rotation_degrees.y)
	if rot == 180:
		return rot-180
	elif rot == 0:
		return rot+180
	else:
		return rot-0


# Function to make it's own shape and texture based on an id and position
# This function is called by a Chunk to construct it's blocks
func construct_self(furniturepos: Vector3, newFurnitureJSON: Dictionary):
	furnitureJSON = newFurnitureJSON
	# Position furniture at the center of the block by default
	furnitureposition = furniturepos
	# Only previously saved furniture will have the global_position_x key. They do not need to be raised
	if not newFurnitureJSON.has("global_position_x"):
		furnitureposition.y += 0.5 # Move the furniture to slightly above the block 
	add_to_group("furniture")

	var furnitureSprite: Texture = Gamedata.get_sprite_by_id(Gamedata.data.furniture,furnitureJSON.id)
	set_sprite(furnitureSprite)
	
	furniturerotation = furnitureJSON.get("rotation", 0)
	# Set the properties we need
	linear_damp = 59
	angular_damp = 59
	axis_lock_angular_x = true
	axis_lock_angular_z = true
	# Set collision layer to layer 4 (moveable obstacles layer)
	collision_layer = 1 << 3  # Layer 4 is 1 << 3

	# Set collision mask to include layers 1, 2, 3, 4, 5, and 6
	collision_mask = (1 << 0) | (1 << 1) | (1 << 2) | (1 << 3) | (1 << 4) | (1 << 5)
	# Explanation:
	# - 1 << 0: Layer 1 (player layer)
	# - 1 << 1: Layer 2 (enemy layer)
	# - 1 << 2: Layer 3 (movable obstacles layer)
	# - 1 << 3: Layer 4 (static obstacles layer)
	# - 1 << 4: Layer 5 (friendly projectiles layer)
	# - 1 << 5: Layer 6 (enemy projectiles layer)


# Check if we crossed the chunk boundary and update our association with the chunks
func _moved(newpos:Vector3):
	furnitureposition = newpos
	var new_chunk = Helper.map_manager.get_chunk_from_position(furnitureposition)
	if not current_chunk == new_chunk:
		if current_chunk:
			current_chunk.remove_furniture_from_chunk(self)
		new_chunk.add_furniture_to_chunk(self)
		current_chunk = new_chunk


func get_data() -> Dictionary:
	return {
		"id": furnitureJSON.id,
		"moveable": true,
		"global_position_x": furnitureposition.x,
		"global_position_y": furnitureposition.y,
		"global_position_z": furnitureposition.z,
		"rotation": last_rotation
	}
