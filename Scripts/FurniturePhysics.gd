class_name FurniturePhysics
extends RigidBody3D

# id for the furniture json. this will be used to load the data when creating a furniture
# when saving a mob in between levels, we will use some static json defined by this id
# and some dynamic json like the furniture health
var furnitureposition: Vector3 = Vector3()
var furniturerotation: int
var furnitureJSON: Dictionary # The json that defines this furniture
var furnitureJSONData: Dictionary # The json that defines this furniture's basics in general
var sprite: Sprite3D = null
var last_rotation: int
var current_chunk: Chunk

var is_animating_hit: bool = false # flag to prevent multiple blink actions
var corpse_scene: PackedScene = preload("res://Defaults/Mobs/mob_corpse.tscn")
var current_health: float = 10.0
# Wait for the chunk to completely spawn. Otherwise the furniture will fall
# trough the floor. TODO: Replace with signal from the chunk to finish loading
var allow_move: bool = false 


func _ready():
	# Add a Timer node so we can wait for the chunk to pawn
	freeze = true
	var timer = Timer.new()
	timer.wait_time = 2
	timer.one_shot = true
	add_child(timer)
	timer.start()
	timer.timeout.connect(_on_timer_timeout)
	
	#set_position.call_deferred(furnitureposition)
	set_new_rotation(furniturerotation)
	last_rotation = furniturerotation

func _on_timer_timeout():
	# After the chunk is (hopefully) spawned, set the position
	set_position.call_deferred(furnitureposition)

# Keep track of the furniture's position and rotation. It starts at 0,0,0 and the moves to it's
# assigned position after a timer. Until that has happened, we don't need to keep track of it's position
func _physics_process(_delta):
	if global_transform.origin == furnitureposition and freeze:
		# This is a hacky way to keep the furniture in it's position after
		# _on_timer_timeout is called. All furniture will be at 0,0,0 until
		# _on_timer_timeout is called
		allow_move = true
		freeze = false
	elif allow_move:
		_moved(global_transform.origin)
	var current_rotation = int(rotation_degrees.y)
	if current_rotation != last_rotation:
		last_rotation = current_rotation


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
		sprite.shaded = true
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
	furnitureJSONData = Gamedata.get_data_by_id(Gamedata.data.furniture,furnitureJSON.id)
	# Position furniture at the center of the block by default
	furnitureposition = furniturepos
	# Only previously saved furniture will have the global_position_x key. They do not need to be raised
	if not newFurnitureJSON.has("global_position_x"):
		furnitureposition.y += 0.5 # Move the furniture to slightly above the block 
	add_to_group("furniture")

	var furnitureSprite: Texture = Gamedata.get_sprite_by_id(Gamedata.data.furniture,furnitureJSON.id)
	set_sprite(furnitureSprite)
	
	furniturerotation = furnitureJSON.get("rotation", 0)
	mass = furnitureJSONData.get("weight", 1)
	# Set the properties we need
	#linear_damp = 59
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


# The furniture will move 0.2 meters in a random direction to indicate that it's hit
# Then it will return to its original position
func animate_hit():
	is_animating_hit = true

	var directions = [Vector3(0.1, 0, 0), Vector3(-0.1, 0, 0), Vector3(0, 0, 0.1), Vector3(0, 0, -0.1)]
	var random_direction = directions[randi() % directions.size()]

	var tween = create_tween()
	tween.tween_property(sprite, "position", sprite.position + random_direction, 0.1).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(sprite, "position", Vector3(0,0,0), 0.1).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT).set_delay(0.1)

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
	current_chunk.remove_furniture_from_chunk(self)
	add_corpse.call_deferred(global_position)
	queue_free.call_deferred()
	

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
