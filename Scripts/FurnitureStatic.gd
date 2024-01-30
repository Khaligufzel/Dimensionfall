extends StaticBody3D


# id for the furniture json. this will be used to load the data when creating a furniture
# when saving a mob in between levels, we will use some static json defined by this id
# and some dynamic json like the furniture health
var id: String

@export var corpse_scene: PackedScene
var current_health: float = 10.0

	
func _get_hit(damage):
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

func get_sprite_rotation() -> int:
	return $Sprite3D.rotation_degrees.y

func set_sprite(newSprite: Texture):
	$Sprite3D.texture = newSprite

	# Calculate new dimensions for the collision shape
	var sprite_width = newSprite.get_width()
	var sprite_height = newSprite.get_height()

	var new_x = sprite_width / 100.0 # 0.1 units per 10 pixels in width
	var new_z = sprite_height / 100.0 # 0.1 units per 10 pixels in height
	var new_y = 0.8 # Any lower will make the player's bullet fly over it

	# Update the collision shape
	var new_shape = BoxShape3D.new()
	new_shape.extents = Vector3(new_x / 2.0, new_y / 2.0, new_z / 2.0) # BoxShape3D extents are half extents

	var collision_shape_node = $CollisionShape3D
	collision_shape_node.shape = new_shape

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
	
	
func get_my_rotation() -> int:
	var rot: int = int(rotation_degrees.y)
	if rot == 180:
		return rot-180
	elif rot == 0:
		return rot+180
	else:
		return rot-0

