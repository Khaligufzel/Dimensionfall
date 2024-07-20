class_name FurniturePhysics
extends RigidBody3D

# id for the furniture json. this will be used to load the data when creating a furniture
# when saving a mob in between levels, we will use some static json defined by this id
# and some dynamic json like the furniture health
var furnitureposition: Vector3 = Vector3()
var furniturerotation: int
var furnitureJSON: Dictionary # The json that defines this furniture
var dfurniture: DFurniture # The json that defines this furniture's basics in general
var sprite: Sprite3D = null
var last_rotation: int
var current_chunk: Chunk
var container: ContainerItem = null # Reference to the container, if this furniture acts as one

var is_animating_hit: bool = false # flag to prevent multiple blink actions
var corpse_scene: PackedScene = preload("res://Defaults/Mobs/mob_corpse.tscn")
var current_health: float = 10.0


# Function to make it's own shape and texture based on an id and position
# This function is called by a Chunk to construct it's blocks
func _init(furniturepos: Vector3, newFurnitureJSON: Dictionary):
	freeze = true # Prevent physics from occurring before it's positioned
	furnitureJSON = newFurnitureJSON
	dfurniture = Gamedata.furnitures.by_id(furnitureJSON.id)
	# Position furniture at the center of the block by default
	furnitureposition = furniturepos
	# Only previously saved furniture will have the global_position_x key. They do not need to be raised
	if not newFurnitureJSON.has("global_position_x"):
		furnitureposition.y += 0.5 # Move the furniture to slightly above the block 
	add_to_group("furniture")

	set_sprite(dfurniture.sprite)
	
	furniturerotation = furnitureJSON.get("rotation", 0)
	mass = dfurniture.weight
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


func _ready() -> void:
	set_position(furnitureposition)
	set_new_rotation(furniturerotation)
	# Add the container as a child on the same position as this furniture
	add_container(Vector3(0,0,0))
	last_rotation = furniturerotation
	freeze = false # Now that it's positioned, unfreeze it


# Keep track of the furniture's position and rotation. It starts at 0,0,0 and the moves to it's
# assigned position after a timer. Until that has happened, we don't need to keep track of it's position
func _physics_process(_delta) -> void:
	if freeze: # Don't care about the position changing when it's frozen
		return
	# We only care about x and z. A changed y only means it's moving up or down.
	var x_changed = not global_transform.origin.x == furnitureposition.x 
	var z_changed = not global_transform.origin.z == furnitureposition.z
	# HACK Sometimes when it calls set_position in _ready() it will say it moved when it didn't,
	# or set_position is too late and it's differs from furnitureposition because it's still 0,0
	# So we add in extra checks to handle those edge cases. There's probably a better way
	var is_zero = global_transform.origin.x == 0 and global_transform.origin.z == 0
	if (x_changed or z_changed) and not is_in_current_chunk() and not is_zero:
		_moved(global_transform.origin)
	var current_rotation = int(rotation_degrees.y)
	if current_rotation != last_rotation:
		last_rotation = current_rotation


# Returns if the current position is inside the current chunk
func is_in_current_chunk() -> bool:
	var chunk_pos: Vector3 = current_chunk.mypos
	var chunk_range: Vector3 = chunk_pos + Vector3(32, 0, 32)

	var myposition: Vector3 = global_transform.origin

	# Check if position is within chunk bounds in the x and z axes
	var in_x_range: bool = (myposition.x >= chunk_pos.x) and (myposition.x <= chunk_range.x)
	var in_z_range: bool = (myposition.z >= chunk_pos.z) and (myposition.z <= chunk_range.z)

	return in_x_range and in_z_range


func set_new_rotation(amount: int) -> void:
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


func set_sprite(newSprite: Texture) -> void:
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



# Check if we crossed the chunk boundary and update our association with the chunks
func _moved(newpos:Vector3) -> void:
	furnitureposition = newpos
	var new_chunk = Helper.map_manager.get_chunk_from_position(furnitureposition)
	if not current_chunk == new_chunk:
		if current_chunk:
			current_chunk.remove_furniture_from_chunk(self)
		new_chunk.add_furniture_to_chunk(self)
		current_chunk = new_chunk


func get_data() -> Dictionary:
	var newfurniturejson = {
		"id": furnitureJSON.id,
		"moveable": true,
		"global_position_x": furnitureposition.x,
		"global_position_y": furnitureposition.y,
		"global_position_z": furnitureposition.z,
		"rotation": last_rotation
	}
	
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


# The furniture will move 0.2 meters in a random direction to indicate that it's hit
# Then it will return to its original position
func animate_hit() -> void:
	is_animating_hit = true

	var directions = [Vector3(0.1, 0, 0), Vector3(-0.1, 0, 0), Vector3(0, 0, 0.1), Vector3(0, 0, -0.1)]
	var random_direction = directions[randi() % directions.size()]

	var tween = create_tween()
	tween.tween_property(sprite, "position", sprite.position + random_direction, 0.1).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(sprite, "position", Vector3(0,0,0), 0.1).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT).set_delay(0.1)

	tween.finished.connect(_on_tween_finished)


# The furniture is done blinking so we reset the relevant variables
func _on_tween_finished() -> void:
	is_animating_hit = false


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
	miss_label.position = furnitureposition
	miss_label.position.y += 2
	miss_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		

	# Animate the miss indicator to disappear quickly
	var tween = create_tween()
	tween.tween_property(miss_label, "modulate:a", 0, 0.5).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	tween.finished.connect(func():
		miss_label.queue_free()  # Properly free the miss_label node
	)


func _die() -> void:
	current_chunk.remove_furniture_from_chunk(self)
	add_corpse.call_deferred(global_position)
	queue_free.call_deferred()


# When the furniture is destroyed, it leaves a wreck behind
func add_corpse(pos: Vector3) -> void:
	if can_be_destroyed():
		var itemdata: Dictionary = {}
		itemdata["global_position_x"] = pos.x
		itemdata["global_position_y"] = pos.y
		itemdata["global_position_z"] = pos.z
		
		var itemgroup = dfurniture.destruction.group
		if itemgroup:
			itemdata["itemgroups"] = [itemgroup]
		
		var fursprite = dfurniture.destruction.sprite
		if fursprite:
			itemdata["texture_id"] = fursprite
		
		var newItem: ContainerItem = ContainerItem.new(itemdata)
		newItem.add_to_group("mapitems")
		# Finally add the new item with possibly set loot group to the tree
		get_tree().get_root().add_child.call_deferred(newItem)
		
		# Check if container has items and insert them into the new item
		if container:
			var items = container.get_items()
			for item in items:
				if newItem.insert_item(item):
					print("Item inserted successfully")


func _disassemble() -> void:
	add_wreck.call_deferred(global_position)
	queue_free()
	

# When the furniture is disassembled, it leaves a wreck behind
func add_wreck(pos: Vector3) -> void:
	if can_be_disassembled():
		var itemdata: Dictionary = {}
		itemdata["global_position_x"] = pos.x
		itemdata["global_position_y"] = pos.y
		itemdata["global_position_z"] = pos.z
		
		var itemgroup = dfurniture.disassembly.group
		if itemgroup:
			itemdata["itemgroups"] = [itemgroup]
		
		var fursprite = dfurniture.disassembly.sprite
		if fursprite:
			itemdata["texture_id"] = fursprite
		
		var newItem: ContainerItem = ContainerItem.new(itemdata)
		newItem.add_to_group("mapitems")
		
		# Finally add the new item with possibly set loot group to the tree
		get_tree().get_root().add_child.call_deferred(newItem)

func can_be_destroyed() -> bool:
	return dfurniture.destruction.get_data().is_empty()

func can_be_disassembled() -> bool:
	return dfurniture.disassembly.get_data().is_empty()


# If this furniture is a container, it will add a container node to the furniture.
func add_container(pos: Vector3):
	if dfurniture.function.is_container:
		var containerdata: Dictionary = {}
		containerdata["global_position_x"] = pos.x
		containerdata["global_position_y"] = pos.y
		containerdata["global_position_z"] = pos.z
		var isnew: bool = is_new_furniture()
		if isnew:
			containerdata["itemgroups"] = [populate_container_from_itemgroup()]
		container = ContainerItem.new(containerdata)
		if not isnew:
			deserialize_container_data()
		container.sprite_3d.visible = false # The sprite blocks the furniture sprite
		add_child(container)


# If there is an itemgroup assigned to the furniture, it will be added to the container.
# Which will fill up the container with items from the itemgroup.
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


func get_sprite() -> Texture:
	return sprite.texture
