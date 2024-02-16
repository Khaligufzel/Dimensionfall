class_name Chunk
extends Node3D


# This script is supposed to work with the Chunk scene
# This script will manage the internals of a map chunk
# A chunk is made up of blocks, slopes, furniture and mobs
# The first time a chunk is loaded, it will be from a map definition
# Each time after that, it will load whatever whas saved when the player exited the map
# When the player exits the map, the chunk will get saved so it can be loaded later
# During the game chunks will be loaded and unloaded to improve performance
# A chunk is defined by 21 levels and each level can potentially hold 32x32 blocks
# On top of the blocks we spawn mobs and furniture
# Loading and unloading of chunks is managed by levelGenerator.gd




@export var defaultBlock: PackedScene = preload("res://Defaults/Blocks/default_block.tscn")
@export var defaultSlope: PackedScene = preload("res://Defaults/Blocks/default_slope.tscn")
@export var defaultMob: PackedScene
@export var defaultItem: PackedScene
@export var defaultFurniturePhysics: PackedScene
@export var defaultFurnitureStatic: PackedScene


var level_width : int = 32
var level_height : int = 32
var _levels: Array = []
var chunk_data: Dictionary
var thread: Thread
var mypos: Vector3

func _ready():
	transform.origin = Vector3(mypos)
	thread = Thread.new()
	# You can bind multiple arguments to a function Callable.
	thread.start(generate_new_chunk.bind(chunk_data))

# Called when the node enters the scene tree for the first time.
func generate():
	thread = Thread.new()
	# You can bind multiple arguments to a function Callable.
	thread.start(generate_new_chunk.bind(chunk_data))


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass

# Thread must be disposed (or "joined"), for portability.
func _exit_tree():
	thread.wait_to_finish()

func generate_new_chunk(mapsegment: Dictionary):
	#Thread.set_thread_safety_checks_enabled(false)
	#This contains the data of one segment, loaded from maps.data, for example generichouse.json
	var mapsegmentData: Dictionary = Helper.json_helper.load_json_dictionary_file(\
		Gamedata.data.maps.dataPath + mapsegment.id)
	var tileJSON: Dictionary = {}

	var level_number = 0
	for level in mapsegmentData.levels:
		if level != []:
			var level_node = create_level_node(level_number - 10)
			var blocks_created: int = 0

			var current_block = 0
			for h in range(level_height):
				for w in range(level_width):
					if level[current_block]:
						tileJSON = level[current_block]
						if tileJSON.has("id") and tileJSON.id != "":
							var block = DefaultBlock.new()
							block.construct_self(Vector3(w,0,h), tileJSON)
							level_node.add_child.call_deferred(block)
							#add_block_mob(tileJSON, block)
							#add_furniture_to_block(tileJSON, block)
							blocks_created += 1
					current_block += 1
			if !blocks_created > 0:
				level_node.remove_from_group.call_deferred("maplevels")
				_levels.erase(level_node)
				level_node.queue_free()
			
		level_number += 1


func create_level_node(ypos: int) -> ChunkLevel:
	var level_node = ChunkLevel.new()
	level_node.add_to_group("maplevels")
	add_child.call_deferred(level_node)
	_levels.append(level_node)
	level_node.levelposition = Vector3(0,ypos,0)
	return level_node
	

# Generate the map layer by layer
# For each layer, add all the blocks with proper rotation
# If a block has an mob, add it too
func generate_saved_chunk(tacticalMapJSON: Dictionary) -> void:
	#we need to generate level layer by layer starting from the bottom
	for level: Dictionary in tacticalMapJSON.maplevels:
		if level != {}:
			var level_node = create_level_node(level.map_y)
			generate_saved_level(level, level_node)

	#
	#for mob: Dictionary in tacticalMapJSON.mobs:
		#add_mob_to_map.call_deferred(mob)
	#
	#for item: Dictionary in tacticalMapJSON.items:
		#add_item_to_map.call_deferred(item)
	#
	#for furnitureData: Dictionary in tacticalMapJSON.furniture:
		#add_furniture_to_map.call_deferred(furnitureData)


# Generates blocks on in the provided level. A level contains at most 32x32 blocks
func generate_saved_level(level: Dictionary, level_node: Node3D) -> void:
	for savedBlock in level.blocks:
		if savedBlock.has("id") and not savedBlock.id == "":
			#var block: StaticBody3D = StaticBody3D.new()#create_block_with_id(savedBlock.id)
			var block = DefaultBlock.new()
			block.construct_self(Vector3(savedBlock.block_x,0,savedBlock.block_z), savedBlock)
			level_node.add_child.call_deferred(block)


func add_block_mob(tileJSON: Dictionary, block: StaticBody3D):
	if tileJSON.has("mob"):
		var newMob: CharacterBody3D = defaultMob.instantiate()
		newMob.add_to_group("mobs")
		get_tree().get_root().add_child(newMob)
		newMob.global_position.x = block.global_position.x
		newMob.global_position.y = block.global_position.y + 0.5
		newMob.global_position.z = block.global_position.z
		#if tileJSON.mob.has("rotation"):
			#newMob.rotation_degrees.y = tileJSON.mob.rotation
		newMob.apply_stats_from_json(Gamedata.get_data_by_id(\
		Gamedata.data.mobs, tileJSON.mob.id))


func add_furniture_to_block(tileJSON: Dictionary, block: StaticBody3D):
	if tileJSON.has("furniture"):
		var newFurniture: Node3D
		var furnitureJSON: Dictionary = Gamedata.get_data_by_id(\
		Gamedata.data.furniture, tileJSON.furniture.id)
		var furnitureSprite: Texture = Gamedata.data.furniture.sprites[furnitureJSON.sprite]
		
		# Calculate the size of the furniture based on the sprite dimensions
		var spriteWidth = furnitureSprite.get_width() / 100.0 # Convert pixels to meters (assuming 100 pixels per meter)
		var spriteDepth = furnitureSprite.get_height() / 100.0 # Convert pixels to meters
		
		var edgeSnappingDirection = furnitureJSON.get("edgesnapping", "None")
		var newRot = tileJSON.furniture.get("rotation", 0)
		
		if furnitureJSON.has("moveable") and furnitureJSON.moveable:
			newFurniture = defaultFurniturePhysics.instantiate()
		else:
			newFurniture = defaultFurnitureStatic.instantiate()
		
		newFurniture.add_to_group("furniture")
		
		# Set the sprite and adjust the collision shape
		newFurniture.set_sprite(furnitureSprite)
		
		add_child(newFurniture)
		
		# Position furniture at the center of the block by default
		var furniturePosition = block.global_position
		furniturePosition.y += 0.5 # Slightly above the block
		
		# Apply edge snapping if necessary
		if edgeSnappingDirection != "None":
			furniturePosition = apply_edge_snapping(furniturePosition, edgeSnappingDirection, spriteWidth, spriteDepth, newRot, block)
		
		newFurniture.global_position = furniturePosition
		
		if tileJSON.furniture.has("rotation"):
			newFurniture.set_new_rotation(tileJSON.furniture.rotation)
		else:
			newFurniture.set_new_rotation(0)
		
		newFurniture.id = furnitureJSON.id


func apply_edge_snapping(newpos, direction, width, depth, newRot, block):
	# Block size, assuming a block is 1x1 meters
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
	newpos = rotate_position_around_block_center(newpos, newRot, block.global_position)
	
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


# Saves all of the maplevels to disk
# A maplevel is one 32x32 layer at a certain x,y and z position
# This layer will contain 1024 blocks
func get_map_data() -> Array:
	var maplevels: Array = []

	# Loop over the levels in the map
	for level: Node3D in _levels:
		level.remove_from_group("maplevels")
		var level_node_data: Array = []
		var level_node_dict: Dictionary = {
			"map_y": level.global_position.y, 
			"blocks": level_node_data
		}

		# Loop over the blocks in the level
		for block in level.get_children():
			var block_data: Dictionary = {
				"id": block.tileJSON.id, 
				"rotation": int(block.rotation_degrees.y),
				"block_x": block.position.x,
				"block_z": block.position.z
			}
			level_node_data.append(block_data)
		maplevels.append(level_node_dict)
	return maplevels


func get_furniture_data() -> Array:
	var furnitureData: Array = []
	var mapFurniture = get_tree().get_nodes_in_group("furniture")
	var newFurnitureData: Dictionary
	var newRot: int
	for furniture in mapFurniture:
		# Check if furniture's position is within the desired range
		if _is_object_in_range(furniture):
			furniture.remove_from_group("furniture")
			if furniture is RigidBody3D:
				newRot = furniture.rotation_degrees.y
			else:
				newRot = furniture.get_my_rotation()
			newFurnitureData = {
				"id": furniture.id,
				"moveable": furniture is RigidBody3D,
				"global_position_x": furniture.global_position.x,
				"global_position_y": furniture.global_position.y,
				"global_position_z": furniture.global_position.z,
				"rotation": newRot,  # Save the Y-axis rotation
				"sprite_rotation": furniture.get_sprite_rotation()
			}
			furnitureData.append(newFurnitureData.duplicate())
			furniture.queue_free()
	return furnitureData


# We check if the furniture or mob or item's position is inside this chunk on the x and z axis
func _is_object_in_range(object: Node3D) -> bool:
		return object.global_position.x >= self.global_position.x and \
		object.global_position.x <= self.global_position.x + level_width and \
		object.global_position.z >= self.global_position.z and \
		object.global_position.z <= self.global_position.z + level_height


# Save all the mobs and their current stats to the mobs file for this map
func get_mob_data() -> Array:
	var mobData: Array = []
	var mapMobs = get_tree().get_nodes_in_group("mobs")
	var newMobData: Dictionary
	for mob in mapMobs:
		# Check if furniture's position is within the desired range
		if _is_object_in_range(mob):
			mob.remove_from_group("mobs")
			newMobData = {
				"id": mob.id,
				"global_position_x": mob.global_position.x,
				"global_position_y": mob.global_position.y,
				"global_position_z": mob.global_position.z,
				"rotation": mob.rotation_degrees.y,
				"melee_damage": mob.melee_damage,
				"melee_range": mob.melee_range,
				"health": mob.health,
				"current_health": mob.current_health,
				"move_speed": mob.moveSpeed,
				"current_move_speed": mob.current_move_speed,
				"idle_move_speed": mob.idle_move_speed,
				"current_idle_move_speed": mob.current_idle_move_speed,
				"sight_range": mob.sightRange,
				"sense_range": mob.senseRange,
				"hearing_range": mob.hearingRange
			}
			mobData.append(newMobData.duplicate())
			mob.queue_free()
	return mobData


#Save the type and position of all mobs on the map
func get_item_data() -> Array:
	var itemData: Array = []
	var myItem: Dictionary = {"itemid": "item1", \
	"global_position_x": 0, "global_position_y": 0, "global_position_z": 0, "inventory": []}
	var mapitems = get_tree().get_nodes_in_group("mapitems")
	var newitemData: Dictionary
	for item in mapitems:
		if _is_object_in_range(item):
			item.remove_from_group("mapitems")
			newitemData = myItem.duplicate()
			newitemData["global_position_x"] = item.global_position.x
			newitemData["global_position_y"] = item.global_position.y
			newitemData["global_position_z"] = item.global_position.z
			newitemData["inventory"] = item.get_node(item.inventory).serialize()
			itemData.append(newitemData.duplicate())
			item.queue_free()
	return itemData


# Called by generate_mobs function when a save is loaded
func add_mob_to_map(mob: Dictionary) -> void:
	var newMob: CharacterBody3D = defaultMob.instantiate()
	newMob.add_to_group("mobs")
	get_tree().get_root().add_child(newMob)
	newMob.global_position.x = mob.global_position_x
	newMob.global_position.y = mob.global_position_y
	newMob.global_position.z = mob.global_position_z
	# Check if rotation data is available and apply it
	if mob.has("rotation"):
		newMob.rotation_degrees.y = mob.rotation
	newMob.apply_stats_from_json(mob)


# Called by generate_items function when a save is loaded
func add_item_to_map(item: Dictionary):
	var newItem: Node3D = defaultItem.instantiate()
	newItem.add_to_group("mapitems")
	get_tree().get_root().add_child(newItem)
	newItem.global_position.x = item.global_position_x
	newItem.global_position.y = item.global_position_y
	newItem.global_position.z = item.global_position_z
	# Check if rotation data is available and apply it
	if item.has("rotation"):
		newItem.rotation_degrees.y = item.rotation
	newItem.get_node(newItem.inventory).deserialize(item.inventory)


# Called by generate_furniture function when a save is loaded
func add_furniture_to_map(furnitureData: Dictionary) -> void:
	var newFurniture: Node3D
	var isMoveable = furnitureData.has("moveable") and furnitureData.moveable
	if isMoveable:
		newFurniture = defaultFurniturePhysics.instantiate()
	else:
		newFurniture = defaultFurnitureStatic.instantiate()
	newFurniture.add_to_group("furniture")
	newFurniture.set_sprite(Gamedata.get_sprite_by_id(Gamedata.data.furniture, furnitureData.id))
	get_tree().get_root().add_child(newFurniture)
	newFurniture.global_position.x = furnitureData.global_position_x
	newFurniture.global_position.y = furnitureData.global_position_y
	newFurniture.global_position.z = furnitureData.global_position_z
	# Check if rotation data is available and apply it
	if furnitureData.has("rotation"):
		if isMoveable:
			newFurniture.rotation_degrees.y = furnitureData.rotation
		else:
			newFurniture.set_new_rotation(furnitureData.rotation)
	
	# Check if sprite rotation data is available and apply it
	if furnitureData.has("sprite_rotation") and isMoveable:
		newFurniture.set_new_rotation(furnitureData.sprite_rotation)
	newFurniture.id = furnitureData.id


func get_chunk_data() -> Dictionary:
	return {
			"chunk_x": global_position.x,
			"chunk_z": global_position.z,
			"maplevels": get_map_data(),
			"furniture": get_furniture_data(),
			"mobs": get_mob_data(),
			"items": get_item_data()
		}
