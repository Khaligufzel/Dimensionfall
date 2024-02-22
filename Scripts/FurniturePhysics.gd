class_name FurniturePhysics
extends RigidBody3D

# id for the furniture json. this will be used to load the data when creating a furniture
# when saving a mob in between levels, we will use some static json defined by this id
# and some dynamic json like the furniture health
var furnitureposition: Vector3
var furniturerotation: int
var furnitureJSON: Dictionary # The json that defines this furniture
var sprite: Sprite3D = null

var corpse_scene: PackedScene = preload("res://Defaults/Mobs/mob_corpse.tscn")
var current_health: float = 10.0


func _ready():
	position = furnitureposition
	set_new_rotation(furniturerotation)


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
	var corpse = corpse_scene.instantiate()
	get_tree().get_root().add_child(corpse)
	corpse.global_position = pos
	corpse.add_to_group("mapitems")





func set_new_rotation(amount: int):
	print_debug("set_new_rotation() - amount:", amount)
	var rotation_amount = amount
	if amount == 180:
		rotation_amount = amount - 180
	elif amount == 0:
		rotation_amount = amount + 180
	else:
		rotation_amount = amount
	print_debug("set_new_rotation() - rotation_amount:", rotation_amount)

	rotation_degrees.y = rotation_amount
	print_debug("set_new_rotation() - sprite.rotation_degrees.y:", sprite.rotation_degrees.y)
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
	# Set the collision object to layer 3 (which is actually the 2^2 bit)
	collision_layer = 1 << 2
	# Set the collision mask to include layers 1, 2, and 3
	collision_mask = (1 << 0) | (1 << 1) | (1 << 2)
