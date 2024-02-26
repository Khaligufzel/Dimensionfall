class_name FurnitureStatic
extends StaticBody3D


# id for the furniture json. this will be used to load the data when creating a furniture
# when saving a mob in between levels, we will use some static json defined by this id
# and some dynamic json like the furniture health
var furnitureposition: Vector3
var furniturerotation: int
var furnitureJSON: Dictionary # The json that defines this furniture
var sprite: Sprite3D = null

var corpse_scene: PackedScene = preload("res://Defaults/Mobs/mob_corpse.tscn")
var current_health: float = 100.0



func _ready():
	position = furnitureposition
	set_new_rotation(furniturerotation)


func get_hit(damage):
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
	new_shape.extents = Vector3(new_x / 2.0, new_y / 2.0, new_z / 2.0) # BoxShape3D extents are half extents

	var collider = CollisionShape3D.new()
	collider.shape = new_shape
	add_child.call_deferred(collider)


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

	# Find out if we need to apply edge snapping
	var furnitureJSONData = Gamedata.get_data_by_id(Gamedata.data.furniture,furnitureJSON.id)
	var edgeSnappingDirection = furnitureJSONData.get("edgesnapping", "None")

	var furnitureSprite: Texture = Gamedata.get_sprite_by_id(Gamedata.data.furniture,furnitureJSON.id)
	set_sprite(furnitureSprite)
	
	# Calculate the size of the furniture based on the sprite dimensions
	var spriteWidth = furnitureSprite.get_width() / 100.0 # Convert pixels to meters (assuming 100 pixels per meter)
	var spriteDepth = furnitureSprite.get_height() / 100.0 # Convert pixels to meters
	
	var newRot = furnitureJSON.get("rotation", 0)

	# Apply edge snapping if necessary. Previously saved blocks have the global_position_x. They do not
	# need to apply edge snapping again
	if edgeSnappingDirection != "None" and not newFurnitureJSON.has("global_position_x"):
		furnitureposition = apply_edge_snapping(furnitureposition, edgeSnappingDirection, spriteWidth, spriteDepth, newRot, furniturepos)

	furniturerotation = newRot



func apply_edge_snapping(newpos, direction, width, depth, newRot, furniturepos):
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


func rotate_position_around_block_center(newpos, newRot, block_center):
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
