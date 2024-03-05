class_name Chunk
extends Node3D


# This script is it's own class and is not assigned to any particular node
# You can call Chunk.new() to create a new instance of this class
# This script will manage the internals of a map chunk
# A chunk is made up of blocks, slopes, furniture and mobs
# The first time a chunk is loaded, it will be from a map definition
# Each time after that, it will load whatever whas saved when the player exited the map
# When the player exits the map, the chunk will get saved so it can be loaded later
# During the game chunks will be loaded and unloaded to improve performance
# A chunk is defined by 21 levels and each level can potentially hold 32x32 blocks
# On top of the blocks we spawn mobs and furniture
# Loading and unloading of chunks is managed by levelGenerator.gd

# Reference to the level manager. Some nodes that could be moved to other chunks should be parented to this
var level_manager : Node3D

var level_width : int = 32
var level_height : int = 32
var _levels: Array = []
var chunk_data: Dictionary # The json data that defines this chunk
var thread: Thread
var mypos: Vector3


# Signals to let the levelgenerator update the navigationmesh
signal chunk_created(chunkposition)
signal chunk_destroyed(chunkposition)


func _ready():
	transform.origin = Vector3(mypos)
	add_to_group("chunks")
	thread = Thread.new()
	if chunk_data.has("id"):
		thread.start(generate_new_chunk.bind(chunk_data))
	else:
		thread.start(generate_saved_chunk.bind(chunk_data))


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass


# Thread must be disposed (or "joined"), for portability.
func _exit_tree():
	chunk_destroyed.emit(mypos)
	thread.wait_to_finish()


func generate_new_chunk(mapsegment: Dictionary):
	#This contains the data of one segment, loaded from maps.data, for example generichouse.json
	var mapsegmentData: Dictionary = Helper.json_helper.load_json_dictionary_file(\
		Gamedata.data.maps.dataPath + mapsegment.id)
	var tileJSON: Dictionary = {}

	var level_number = 0
	for level in mapsegmentData.levels:
		if level != []:
			var y_position: int = level_number - 10
			var level_node = create_level_node(y_position)
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
							add_block_mob(tileJSON, Vector3(w,y_position+1.1,h))
							add_furniture_to_block(tileJSON, Vector3(w,y_position,h))
							blocks_created += 1
					current_block += 1
			if !blocks_created > 0:
				level_node.remove_from_group.call_deferred("maplevels")
				_levels.erase(level_node)
				level_node.queue_free()
			
		level_number += 1
	call_deferred("emit_signal", "chunk_created", mypos)


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

	for mob: Dictionary in tacticalMapJSON.mobs:
		add_mob_to_map.call_deferred(mob)

	for item: Dictionary in tacticalMapJSON.items:
		add_item_to_map.call_deferred(item)

	for furnitureData: Dictionary in tacticalMapJSON.furniture:
		add_furniture_to_map.call_deferred(furnitureData)
	
	call_deferred("emit_signal", "chunk_created", mypos)


# Generates blocks on in the provided level. A level contains at most 32x32 blocks
func generate_saved_level(level: Dictionary, level_node: Node3D) -> void:
	for savedBlock in level.blocks:
		if savedBlock.has("id") and not savedBlock.id == "":
			var block = DefaultBlock.new()
			block.construct_self(Vector3(savedBlock.block_x,0,savedBlock.block_z), savedBlock)
			level_node.add_child.call_deferred(block)


# When a map is loaded for the first time we spawn the mob on the block
func add_block_mob(tileJSON: Dictionary, mobpos: Vector3):
	if tileJSON.has("mob"):
		var newMob: CharacterBody3D = Mob.new()
		# Pass the position and the mob json to the newmob and have it construct itself
		newMob.construct_self(mypos+mobpos, tileJSON.mob)
		level_manager.add_child.call_deferred(newMob)


# When a map is loaded for the first time we spawn the furniture on the block
func add_furniture_to_block(tileJSON: Dictionary, furniturepos: Vector3):
	if tileJSON.has("furniture"):
		var newFurniture: Node3D
		var furnitureJSON: Dictionary = Gamedata.get_data_by_id(\
		Gamedata.data.furniture, tileJSON.furniture.id)
		if furnitureJSON.has("moveable") and furnitureJSON.moveable:
			newFurniture = FurniturePhysics.new()
		else:
			newFurniture = FurnitureStatic.new()

		newFurniture.construct_self(mypos+furniturepos, tileJSON.furniture)
		level_manager.add_child.call_deferred(newFurniture)


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
			if furniture is FurniturePhysics:
				newRot = furniture.rotation_degrees.y
			else: # It's FurnitureStatic
				newRot = furniture.get_my_rotation()
			newFurnitureData = {
				"id": furniture.furnitureJSON.id,
				"moveable": furniture is FurniturePhysics,
				"global_position_x": furniture.global_position.x,
				"global_position_y": furniture.global_position.y,
				"global_position_z": furniture.global_position.z,
				"rotation": newRot,  # Save the Y-axis rotation
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
				"id": mob.mobJSON.id,
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
	var myItem: Dictionary = {
		"itemid": "item1", 
		"global_position_x": 0, 
		"global_position_y": 0, 
		"global_position_z": 0, 
		"inventory": []
	}
	var mapitems = get_tree().get_nodes_in_group("mapitems")
	var newitemData: Dictionary
	for item in mapitems:
		if _is_object_in_range(item):
			item.remove_from_group("mapitems")
			newitemData = myItem.duplicate()
			newitemData["global_position_x"] = item.global_position.x
			newitemData["global_position_y"] = item.global_position.y
			newitemData["global_position_z"] = item.global_position.z
			newitemData["inventory"] = item.inventory.serialize()
			itemData.append(newitemData.duplicate())
			item.queue_free()
	return itemData


# Called when a save is loaded
func add_mob_to_map(mob: Dictionary) -> void:
	var newMob: CharacterBody3D = Mob.new()
	# Put the mob back where it was when the map was unloaded
	var mobpos: Vector3 = Vector3(mob.global_position_x,mob.global_position_y,mob.global_position_z)
	newMob.construct_self(mobpos, mob)
	level_manager.add_child.call_deferred(newMob)


# Called by generate_items function when a save is loaded
func add_item_to_map(item: Dictionary):
	var newItem: ContainerItem = ContainerItem.new()
	newItem.add_to_group("mapitems")
	var pos: Vector3 = Vector3(item.global_position_x,item.global_position_y,item.global_position_z)
	newItem.construct_self(pos)
	level_manager.add_child.call_deferred(newItem)
	newItem.inventory.deserialize(item.inventory)


func add_furniture_to_map(furnitureData: Dictionary):
	var newFurniture: Node3D
	var furnitureJSON: Dictionary = Gamedata.get_data_by_id(
	Gamedata.data.furniture, furnitureData.id)

	if furnitureJSON.has("moveable") and furnitureJSON.moveable:
		newFurniture = FurniturePhysics.new()
	else:
		newFurniture = FurnitureStatic.new()

	var furniturepos: Vector3 =  Vector3(furnitureData.global_position_x,furnitureData.global_position_y,furnitureData.global_position_z)
	newFurniture.construct_self(furniturepos,furnitureData)
	level_manager.add_child.call_deferred(newFurniture)


func get_chunk_data() -> Dictionary:
	return {
			"chunk_x": global_position.x,
			"chunk_z": global_position.z,
			"maplevels": get_map_data(),
			"furniture": get_furniture_data(),
			"mobs": get_mob_data(),
			"items": get_item_data()
		}
