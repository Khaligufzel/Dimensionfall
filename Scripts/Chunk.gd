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
var level_generator : Node3D

var level_width : int = 32
var level_height : int = 32
var _levels: Array[ChunkLevel] = [] # The level nodes that hold block nodes
var _mapleveldata: Array = [] # Holds the data for each level in this chunk
# This is a class variable to track block positions
var block_positions = {}
var chunk_data: Dictionary # The json data that defines this chunk
var processed_level_data: Dictionary = {}
var mutex: Mutex = Mutex.new()
var thread: Thread
#var navigationthread: Thread
var mypos: Vector3
var navigation_region: NavigationRegion3D
#var navigation_region: RID
var navigation_mesh: NavigationMesh = NavigationMesh.new()
var source_geometry_data: NavigationMeshSourceGeometryData3D
var initialized_block_count: int = 0
var generation_task: int

signal chunk_unloaded


func _ready():
	chunk_unloaded.connect(_finish_unload)
	source_geometry_data = NavigationMeshSourceGeometryData3D.new()
	setup_navigation.call_deferred()
	transform.origin = Vector3(mypos)
	add_to_group("chunks")
	initialize_chunk_data()


func initialize_chunk_data():
	initialized_block_count = 0
	if chunk_data.has("id"): # This chunk is created for the first time
		#This contains the data of one segment, loaded from maps.data, for example generichouse.json
		var mapsegmentData: Dictionary = Helper.json_helper.load_json_dictionary_file(\
			Gamedata.data.maps.dataPath + chunk_data.id)
		_mapleveldata = mapsegmentData.levels
		#generation_task = WorkerThreadPool.add_task(generate_new_chunk)
		#WorkerThreadPool.wait_for_task_completion(generation_task)
		generate_new_chunk()
	else: # This chunk is created from previously saved data
		_mapleveldata = chunk_data.maplevels
		#WorkerThreadPool.add_task(generate_saved_chunk)
		#generation_task = WorkerThreadPool.add_task(generate_saved_chunk)
		#WorkerThreadPool.wait_for_task_completion(generation_task)
		generate_saved_chunk()


func generate_new_chunk():
	#thread = Thread.new()
	#thread.start(create_block_position_dictionary_new)
	create_block_position_dictionary_new_finished()
	process_level_data_finished()


func generate_new_chunk2():
	if is_instance_valid(thread) and thread.is_started():
		# If a thread is already running, let it finish before we start another.
		thread.wait_to_finish()
		thread = null # Threads are reference counted, so this is how we free them.
	#thread = Thread.new()
	#thread.start(process_level_data)
	#process_level_data()


func process_level_data_finished():
	# Wait for the thread to complete, and get the returned value.
	#mutex.lock()
	#processed_level_data = thread.wait_to_finish()
	#thread = null # Threads are reference counted, so this is how we free them.
	##var processed_levels: Array = processed_level_data.lvl.duplicate()
	#mutex.unlock()
	processed_level_data = process_level_data()
	_spawn_levels_new()
	#thread = Thread.new()
	#thread.start(_spawn_levels_new)


func _spawn_levels_new():
	mutex.lock()
	var mylevels = processed_level_data.lvl.duplicate()
	mutex.unlock()
	for level in mylevels:
		add_child.call_deferred(level)
		OS.delay_msec(10)  # Optional: delay to reduce CPU usage
	_spawn_levels_new_finished.call_deferred()


func _spawn_levels_new_finished():
	if is_instance_valid(thread) and thread.is_started():
		if thread.is_alive():
			print_debug("The thread is still alive, blocking calling thread")
		# If a thread is already running, let it finish before we start another.
		thread.wait_to_finish()
		thread = null # Threads are reference counted, so this is how we free them.
	#thread = Thread.new()
	#thread.start(create_blocks_by_id1)
	create_blocks_by_id1()
	

func _spawn_levels(processed_levels):
	for level in processed_levels:
		add_child.call_deferred(level)
		OS.delay_msec(10)  # Optional: delay to reduce CPU usage
	

func process_level_data():
	# Initialize the counter and expected count
	var level_number = 0
	var tileJSON: Dictionary = {}
	var proc_lvl_data: Dictionary = {"lvl": [],"blk": [],"furn": [],"mobs": []}

	for level in _mapleveldata:
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
							mutex.lock()
							level_node.blocklist.append({"lvl":level_node,"w":w,"h":h,"json":tileJSON})
							mutex.unlock()
							proc_lvl_data.blk.append({"lvl":level_node,"w":w,"h":h,"json":tileJSON})
							proc_lvl_data.mobs.append({"json":tileJSON, "pos":Vector3(w,y_position+1.5,h)})
							proc_lvl_data.furn.append({"json":tileJSON, "pos":Vector3(w,y_position,h)})
							blocks_created += 1
					current_block += 1
			# Sometimes a level might not be empty, but at the same time has no actual block data,
			# i.e. empty blocks like {}. In that case we need to remove the level again
			if !blocks_created > 0:
				mutex.lock()
				level_node.remove_from_group.call_deferred("maplevels")
				_levels.erase(level_node)
				level_node.queue_free()
				mutex.unlock()
			else:
				proc_lvl_data.lvl.append(level_node)
		level_number += 1
	#process_level_data_finished.call_deferred()
	return proc_lvl_data


# Creates a dictionary of all block positions with a local x,y and z position
# This function works with new mapdata
func create_block_position_dictionary_new() -> Dictionary:
	var new_block_positions:Dictionary = {}
	for level_index in range(len(_mapleveldata)):
		var level = _mapleveldata[level_index]
		if level != []:
			for h in range(level_height):
				for w in range(level_width):
					var current_block_index = h * level_width + w
					if level[current_block_index]:
						var tileJSON = level[current_block_index]
						if tileJSON.has("id") and tileJSON.id != "":
							var block_position_key = str(w) + "," + str(level_index-10) + "," + str(h)
							new_block_positions[block_position_key] = true
	#create_block_position_dictionary_new_finished.call_deferred()
	return new_block_positions


# Creates a dictionary of all block positions with a local x,y and z position
# This function works with previously saved chunk data
func create_block_position_dictionary_loaded() -> Dictionary:
	var new_block_positions:Dictionary = {}
	for level_index in range(len(_mapleveldata)):
		var level = _mapleveldata[level_index]
		if level.blocks != []:
			for blk in level.blocks:
				if blk.has("id") and not blk.id == "":
					var key = str(blk.block_x) + "," + str(level.map_y) + "," + str(blk.block_z)
					new_block_positions[key] = true
	#create_block_position_dictionary_loaded_finished.call_deferred()
	return new_block_positions


func create_block_position_dictionary_new_finished():
	#mutex.lock()
	## Wait for the thread to complete, and get the returned value.
	#block_positions = thread.wait_to_finish()
	#thread = null # Threads are reference counted, so this is how we free them.
	#mutex.unlock()
	
	block_positions = create_block_position_dictionary_new()
	generate_new_chunk2()
	

func create_block_position_dictionary_loaded_finished():
	#mutex.lock()
	## Wait for the thread to complete, and get the returned value.
	#block_positions = thread.wait_to_finish()
	#thread = null # Threads are reference counted, so this is how we free them.
	#mutex.unlock()
	block_positions = create_block_position_dictionary_loaded()
	generate_saved_chunk2()
	


# Creates one level of blocks, for example level 0 will be the ground floor
# Can contain a maximum of 32x32 or 1024 blocks
func create_level_node(ypos: int) -> ChunkLevel:
	var level_node = ChunkLevel.new()
	level_node.add_to_group("maplevels")
	_levels.append(level_node)
	level_node.levelposition = Vector3(0,ypos,0)
	return level_node


# Constructs blocks and their navigationmesh and adds them to their level nodes
# Since this function is assumed to be run in a separate thread, we can add delays to
# make sure the game does not stutter too much. The numbers for the delay are arbitrary
# An important thing to keep in mind is that the stuttering will happen when to many blocks
# are added at once, making it difficult for the gpu to keep up. 
# This cannot be easily observed in the profiler
func create_blocks_by_id1():
	mutex.lock()
	var myblocks = processed_level_data.blk.duplicate()
	mutex.unlock()
	var total_blocks = myblocks.size()
	var delay_every_n_blocks = max(1, total_blocks / 15) # Ensure we at least get 1 to avoid division by zero

	for i in range(total_blocks):
		var blockdata = myblocks[i]
		var level_node: ChunkLevel = blockdata["lvl"]
		var w: int = blockdata["w"]
		var h: int = blockdata["h"]
		var tileJSON: Dictionary = blockdata["json"]
		
		var block = DefaultBlock.new()
		block.ready.connect(_on_block_ready.bind(total_blocks))
		block.construct_self(Vector3(w,0,h), tileJSON) # Sets its own properties that can be set before spawn
		# Adds the top surface to the navigation data
		var blockposition = Vector3(w,0,h)
		var blockrotation = block.get_block_rotation()
		var blockshape = block.shape
		var level_y = level_node.levelposition.y
		add_mesh_to_navigation_data(blockposition, blockrotation, blockshape, level_y)
		level_node.add_child.call_deferred(block)
		
		# Insert delay after every n blocks, evenly spreading the delay
		#if i % delay_every_n_blocks == 0 and i != 0: # Avoid delay at the very start
			#OS.delay_msec(100) # Adjust delay time as needed

	# Optional: One final delay after the last block if the total_blocks is not perfectly divisible by delay_every_n_blocks
	if total_blocks % delay_every_n_blocks != 0:
		OS.delay_msec(100)
	create_blocks_finished.call_deferred()


func create_blocks_finished():
	if is_instance_valid(thread) and thread.is_started():
		if thread.is_alive():
			print_debug("The thread is still alive, blocking calling thread")
		# If a thread is already running, let it finish before we start another.
		thread.wait_to_finish()
		thread = null # Threads are reference counted, so this is how we free them.
	#thread = Thread.new()
	#thread.start(add_furnitures_to_new_block)
	add_furnitures_to_new_block()


# Constructs blocks and their navigationmesh and adds them to their level nodes
# Since this function is assumed to be run in a separate thread, we can add delays to
# make sure the game does not stutter too much. The numbers for the delay are arbitrary
# An important thing to keep in mind is that the stuttering will happen when to many blocks
# are added at once, making it difficult for the gpu to keep up. 
# This cannot be easily observed in the profiler
func create_blocks_by_id(processed_blocks):
	var total_blocks = processed_blocks.size()
	var delay_every_n_blocks = max(1, total_blocks / 15) # Ensure we at least get 1 to avoid division by zero

	for i in range(total_blocks):
		var blockdata = processed_blocks[i]
		var level_node: ChunkLevel = blockdata["lvl"]
		var w: int = blockdata["w"]
		var h: int = blockdata["h"]
		var tileJSON: Dictionary = blockdata["json"]
		
		var block = DefaultBlock.new()
		block.ready.connect(_on_block_ready.bind(total_blocks))
		block.construct_self(Vector3(w,0,h), tileJSON) # Sets its own properties that can be set before spawn
		# Adds the top surface to the navigation data
		var blockposition = Vector3(w,0,h)
		var blockrotation = block.get_block_rotation()
		var blockshape = block.shape
		var level_y = level_node.levelposition.y
		add_mesh_to_navigation_data(blockposition, blockrotation, blockshape, level_y)
		level_node.add_child.call_deferred(block)
		
		# Insert delay after every n blocks, evenly spreading the delay
		#if i % delay_every_n_blocks == 0 and i != 0: # Avoid delay at the very start
			#OS.delay_msec(100) # Adjust delay time as needed

	# Optional: One final delay after the last block if the total_blocks is not perfectly divisible by delay_every_n_blocks
	if total_blocks % delay_every_n_blocks != 0:
		OS.delay_msec(100)


# Called when a block is ready and added to the tree. We need to count them to be sure
# That all the blocks have been created before we proceed
func _on_block_ready(numblocks):
	initialized_block_count += 1
	if initialized_block_count == numblocks:
		# Since all the required block data has been added to the navigationmesh data previously,
		# We update the navigationmesh and region using this data
		update_navigation_mesh()


# Generate the map layer by layer
# For each layer, add all the blocks with proper rotation
# If a block has an mob, add it too
func generate_saved_chunk() -> void:
	#thread = Thread.new()
	#thread.start(create_block_position_dictionary_loaded)
	create_block_position_dictionary_loaded_finished()

# Generate the map layer by layer
# For each layer, add all the blocks with proper rotation
# If a block has an mob, add it too
func generate_saved_chunk2() -> void:
	var processed_levels: Array = []
	var processed_blocks: Array = []
	initialized_block_count = 0
	#we need to generate level layer by layer starting from the bottom
	for level: Dictionary in chunk_data.maplevels:
		if level != {}:
			var level_node = create_level_node(level.map_y)
			mutex.lock()
			processed_levels.append(level_node)
			mutex.unlock()
			generate_saved_level(level, level_node, processed_blocks)

	# We spawn the levels in a separate function now that we know how many actually spawn
	_spawn_levels(processed_levels)
	#generation_task = WorkerThreadPool.add_task(create_blocks_by_id.bind(processed_blocks))
	create_blocks_by_id(processed_blocks)

	for item: Dictionary in chunk_data.items:
		add_item_to_map(item)

	for furnitureData: Dictionary in chunk_data.furniture:
		add_furniture_to_map(furnitureData)

	thread = Thread.new()
	thread.start(add_mobs_to_map.bind(chunk_data.mobs.duplicate()))
	#add_mobs_to_map(chunk_data.mobs.duplicate())


# Generates blocks on in the provided level. A level contains at most 32x32 blocks
func generate_saved_level(level: Dictionary, level_node: Node3D, processed_blocks: Array) -> void:
	for blk in level.blocks:
		if blk.has("id") and not blk.id == "":
			mutex.lock()
			level_node.blocklist.append({"lvl":level_node,"w":blk.block_x,"h":blk.block_z,"json":blk})
			processed_blocks.append({"lvl":level_node,"w":blk.block_x,"h":blk.block_z,"json":blk})
			mutex.unlock()
			#create_block_by_id({"lvl":level_node,"w":blk.block_x,"h":blk.block_z,"json":blk})
		else:
			print_debug("generate_saved_level: block has no id!")


# When a map is loaded for the first time we spawn the mob on the block
func add_block_mobs():
	mutex.lock()
	var mobdatalist = processed_level_data.mobs.duplicate()
	mutex.unlock()
	for mobdata: Dictionary in mobdatalist:
		var tileJSON: Dictionary = mobdata.json
		var mobpos: Vector3 = mobdata.pos
		if tileJSON.has("mob"):
			var newMob: CharacterBody3D = Mob.new()
			# Pass the position and the mob json to the newmob and have it construct itself
			newMob.construct_self(mypos+mobpos, tileJSON.mob)
			level_manager.add_child.call_deferred(newMob)
	add_block_mobs_finished.call_deferred()


func add_block_mobs_finished():
	if is_instance_valid(thread) and thread.is_started():
		# If a thread is already running, let it finish before we start another.
		thread.wait_to_finish()
		thread = null # Threads are reference counted, so this is how we free them.

# When a map is loaded for the first time we spawn the furniture on the block
func add_furnitures_to_new_block():
	mutex.lock()
	var furnituredata = processed_level_data.furn.duplicate()
	mutex.unlock()
	var total_furniture = furnituredata.size()
	 # Ensure we at least get 1 to avoid division by zero
	var delay_every_n_furniture = max(1, total_furniture / 15)

	for i in range(total_furniture):
		var furniture = furnituredata[i]
		var tileJSON: Dictionary = furniture.json
		var furniturepos: Vector3 = furniture.pos
		if tileJSON.has("furniture"):
			var newFurniture: Node3D
			var furnitureJSON: Dictionary = Gamedata.get_data_by_id(\
			Gamedata.data.furniture, tileJSON.furniture.id)
			if furnitureJSON.has("moveable") and furnitureJSON.moveable:
				newFurniture = FurniturePhysics.new()
				furniturepos.y += 0.2 # Make sure it's not in a block and let it fall
			else:
				newFurniture = FurnitureStatic.new()

			newFurniture.construct_self(mypos+furniturepos, tileJSON.furniture)
			level_manager.add_child.call_deferred(newFurniture)
		
		# Insert delay after every n blocks, evenly spreading the delay
		#if i % delay_every_n_furniture == 0 and i != 0: # Avoid delay at the very start
			#OS.delay_msec(100) # Adjust delay time as needed

	# Optional: One final delay after the last block if the total_blocks is not perfectly divisible by delay_every_n_blocks
	if total_furniture % delay_every_n_furniture != 0:
		OS.delay_msec(100)
	add_furnitures_to_new_block_finished.call_deferred()


func add_furnitures_to_new_block_finished():
	if is_instance_valid(thread) and thread.is_started():
		# If a thread is already running, let it finish before we start another.
		thread.wait_to_finish()
		thread = null # Threads are reference counted, so this is how we free them.
	thread = Thread.new()
	thread.start(add_block_mobs)
	#add_block_mobs()


# When a map is loaded for the first time we spawn the furniture on the block
func add_furnitures_to_block():
	mutex.lock()
	var furnituredata = processed_level_data.furn.duplicate()
	var total_furniture = furnituredata.size()
	mutex.unlock()
	 # Ensure we at least get 1 to avoid division by zero
	var delay_every_n_furniture = max(1, total_furniture / 15)

	for i in range(total_furniture):
		var furniture = furnituredata[i]
		var tileJSON: Dictionary = furniture.json
		var furniturepos: Vector3 = furniture.pos
		if tileJSON.has("furniture"):
			var newFurniture: Node3D
			var furnitureJSON: Dictionary = Gamedata.get_data_by_id(\
			Gamedata.data.furniture, tileJSON.furniture.id)
			if furnitureJSON.has("moveable") and furnitureJSON.moveable:
				newFurniture = FurniturePhysics.new()
				furniturepos.y += 0.2 # Make sure it's not in a block and let it fall
			else:
				newFurniture = FurnitureStatic.new()

			newFurniture.construct_self(mypos+furniturepos, tileJSON.furniture)
			level_manager.add_child.call_deferred(newFurniture)
		
		# Insert delay after every n blocks, evenly spreading the delay
		#if i % delay_every_n_furniture == 0 and i != 0: # Avoid delay at the very start
			#OS.delay_msec(100) # Adjust delay time as needed

	# Optional: One final delay after the last block if the total_blocks is not perfectly divisible by delay_every_n_blocks
	if total_furniture % delay_every_n_furniture != 0:
		OS.delay_msec(100)


# Saves all of the maplevels to disk
# A maplevel is one 32x32 layer at a certain x,y and z position
# This layer will contain 1024 blocks
func get_map_data() -> Array:
	var maplevels: Array = []
	mutex.lock()
	var mylevels = _levels.duplicate()
	mutex.unlock()

	# Loop over the levels in the map
	for level: Node3D in mylevels:
		level.remove_from_group.call_deferred("maplevels")
		var level_node_data: Array = []
		var level_node_dict: Dictionary = {}
		mutex.lock()
		level_node_dict["map_y"] = level.levelposition.y
		var blocklevellist: Array = level.blocklist.duplicate()
		mutex.unlock()
		level_node_dict["blocks"] = level_node_data

		# Loop over the blocks in the level
		for block in blocklevellist:
			var block_data: Dictionary = {}
			block_data["id"] = block.json.id
			block_data["rotation"] = int(block.json.blockrotation)
			block_data["block_x"] = block.w
			block_data["block_z"] = block.h
			level_node_data.append(block_data)
		maplevels.append(level_node_dict)
	return maplevels


func get_furniture_data() -> Array:
	var furnitureData: Array = []
	var mapFurniture = get_tree().get_nodes_in_group("furniture")
	var newFurnitureData: Dictionary
	var newRot: int
	var furniturepos: Vector3
	for furniture in mapFurniture:
		# We check if the furniture is a valid instance. Sometimes it isn't
		# This might be because two chunks try to unload the furniture?
		# We might need more work on _is_object_in_range
		if is_instance_valid(furniture):
			if furniture is FurniturePhysics:
				newRot = furniture.last_rotation
				furniturepos = furniture.last_position
			else: # It's FurnitureStatic
				newRot = furniture.get_my_rotation()
				furniturepos = furniture.furnitureposition
			# Check if furniture's position is within the desired range
			if _is_object_in_range(furniturepos):
				furniture.remove_from_group.call_deferred("furniture")
				#print_debug("removing furniture with posdition: ", furniturepos)
				newFurnitureData = {
					"id": furniture.furnitureJSON.id,
					"moveable": furniture is FurniturePhysics,
					"global_position_x": furniturepos.x,
					"global_position_y": furniturepos.y,
					"global_position_z": furniturepos.z,
					"rotation": newRot,  # Save the Y-axis rotation
				}
				furnitureData.append(newFurnitureData.duplicate())
				furniture.queue_free.call_deferred()
	return furnitureData


# We check if the furniture or mob or item's position is inside this chunk on the x and z axis
func _is_object_in_range(objectposition: Vector3) -> bool:
		return objectposition.x >= mypos.x and \
		objectposition.x <= mypos.x + level_width and \
		objectposition.z >= mypos.z and \
		objectposition.z <= mypos.z + level_height


# Save all the mobs and their current stats to the mobs file for this map
func get_mob_data() -> Array:
	var mobData: Array = []
	var mapMobs = get_tree().get_nodes_in_group("mobs")
	var newMobData: Dictionary
	for mob in mapMobs:
		# Check if furniture's position is within the desired range
		if _is_object_in_range(mob.last_position):
			mob.remove_from_group.call_deferred("mobs")
			newMobData = {
				"id": mob.mobJSON.id,
				"global_position_x": mob.last_position.x,
				"global_position_y": mob.last_position.y,
				"global_position_z": mob.last_position.z,
				"rotation": mob.last_rotation,
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
			mob.queue_free.call_deferred()
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
		if _is_object_in_range(item.containerpos):
			item.remove_from_group("mapitems")
			newitemData = myItem.duplicate()
			newitemData["global_position_x"] = item.containerpos.x
			newitemData["global_position_y"] = item.containerpos.y
			newitemData["global_position_z"] = item.containerpos.z
			newitemData["inventory"] = item.inventory.serialize()
			itemData.append(newitemData.duplicate())
			item.queue_free.call_deferred()
	return itemData


# Called when a save is loaded
func add_mobs_to_map(mobdata: Array) -> void:
	for mob: Dictionary in mobdata:
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


# Adds furniture that has been loaded from previously saved data
func add_furniture_to_map(furnitureData: Dictionary):
	var newFurniture: Node3D
	var furnitureJSON: Dictionary = Gamedata.get_data_by_id(
	Gamedata.data.furniture, furnitureData.id)

	if furnitureJSON.has("moveable") and furnitureJSON.moveable:
		newFurniture = FurniturePhysics.new()
	else:
		newFurniture = FurnitureStatic.new()

	# We can't set it's position until after it's in the scene tree 
	# so we only save the position to a variable and pass it to the furniture
	var furniturepos: Vector3 =  Vector3(furnitureData.global_position_x,furnitureData.global_position_y,furnitureData.global_position_z)
	newFurniture.construct_self(furniturepos,furnitureData)
	level_manager.add_child.call_deferred(newFurniture)


# Returns all the chunk data used for saving and loading
func get_chunk_data() -> Dictionary:
	var chunkdata: Dictionary = {}
	mutex.lock()
	chunkdata.chunk_x = mypos.x
	chunkdata.chunk_z = mypos.z
	mutex.unlock()
	chunkdata.maplevels = get_map_data()
	chunkdata.furniture = get_furniture_data()
	chunkdata.mobs = get_mob_data()
	chunkdata.items = get_item_data()
	finish_unload_chunk.call_deferred()
	return chunkdata



func unload_chunk():
	if is_instance_valid(thread) and thread.is_started():
	# Wait for the thread to complete, and get the returned value.
		mutex.lock()
		thread.wait_to_finish()
		thread = null # Threads are reference counted, so this is how we free them.
		#var processed_levels: Array = processed_level_data.lvl.duplicate()
		mutex.unlock()
	thread = Thread.new()
	thread.start(get_chunk_data)
	

func finish_unload_chunk():
	var chunkdata: Dictionary
	mutex.lock()
	chunkdata = thread.wait_to_finish()
	thread = null # Threads are reference counted, so this is how we free them.
	var chunkposition: Vector2 = Vector2(int(chunkdata.chunk_x/32),int(chunkdata.chunk_z/32))
	Helper.loaded_chunk_data.chunks[chunkposition] = chunkdata
	mutex.unlock()

	# Queue all levels for deletion.
	for level in _levels:
		level.queue_free()

	# Clear the _levels array since all levels are now queued for deletion.
	mutex.lock()
	_levels.clear()
	mutex.unlock()
	chunk_unloaded.emit()


# Adds triangles represented by 3 vertices to the navigation mesh data
# If a block is above another block, we make sure no plane is created in between
# For blocks we will create a square represented by 2 triangles
# The same goes for slopes, but 2 of the vertices are lowered to the ground
# keep in mind that after the navigationmesh is added to the navigationregion
# It will be shrunk by the navigation_mesh.agent_radius to prevent collisions
func add_mesh_to_navigation_data(blockposition, blockrotation, blockshape, level_y):
	var block_global_position: Vector3 = blockposition# + mypos
	block_global_position.y = level_y
	var blockrange: float = 0.5
	
	# Check if there's a block directly above the current block
	var above_key = str(blockposition.x) + "," + str(level_y + 1) + "," + str(blockposition.z)
	if block_positions.has(above_key):
		# There's a block directly above, so we don't add a face for the current block's top
		return

	if blockshape == "cube":
		# Top face of a block, the block size is 1x1x1 for simplicity.
		var top_face_vertices = PackedVector3Array([
			# First triangle
			Vector3(-blockrange, 0.5, -blockrange), # Top-left
			Vector3(blockrange, 0.5, -blockrange), # Top-right
			Vector3(blockrange, 0.5, blockrange), # Bottom-right
			# Second triangle
			Vector3(-blockrange, 0.5, -blockrange), # Top-left (repeated for the second triangle)
			Vector3(blockrange, 0.5, blockrange), # Bottom-right (repeated for the second triangle)
			Vector3(-blockrange, 0.5, blockrange)  # Bottom-left
		])
		# Add the top face as two triangles.
		mutex.lock()
		source_geometry_data.add_faces(top_face_vertices, Transform3D(Basis(), block_global_position))
		mutex.unlock()
	elif blockshape == "slope":
		# Define the initial slope vertices here. We define a set for each direction
		var vertices_north = PackedVector3Array([ #Facing north
			Vector3(-blockrange, 0.5, -blockrange), # Top front left
			Vector3(blockrange, 0.5, -blockrange), # Top front right
			Vector3(blockrange, -0.5, blockrange), # Bottom back right
			Vector3(-blockrange, -0.5, blockrange) # Bottom back left
		])
		var vertices_east = PackedVector3Array([
			Vector3(blockrange, 0.5, -blockrange), # Top back right
			Vector3(blockrange, 0.5, blockrange), # Top front right
			Vector3(-blockrange, -0.5, blockrange), # Bottom front left
			Vector3(-blockrange, -0.5, -blockrange) # Bottom back left
		])
		var vertices_south = PackedVector3Array([
			Vector3(blockrange, 0.5, blockrange), # Top front right
			Vector3(-blockrange, 0.5, blockrange), # Top front left
			Vector3(-blockrange, -0.5, -blockrange), # Bottom back left
			Vector3(blockrange, -0.5, -blockrange) # Bottom back right
		])
		var vertices_west = PackedVector3Array([
			Vector3(-blockrange, 0.5, blockrange), # Top front left
			Vector3(-blockrange, 0.5, -blockrange), # Top back left
			Vector3(blockrange, -0.5, -blockrange), # Bottom back right
			Vector3(blockrange, -0.5, blockrange) # Bottom front right
		])

		# We pick a direction based on the block rotation
		var blockrot: int = blockrotation
		var vertices
		match blockrot:
			90:
				vertices = vertices_north
			180:
				vertices = vertices_west
			270:
				vertices = vertices_south
			_:
				vertices = vertices_east

		# Define triangles for the slope
		var slope_faces = PackedVector3Array([
			vertices[0], vertices[1], vertices[2],  # Triangle 1: TFL, TFR, BBR
			vertices[0], vertices[2], vertices[3]   # Triangle 2: TFL, BBR, BBL
		])
		mutex.lock()
		source_geometry_data.add_faces(slope_faces, Transform3D(Basis(), block_global_position))
		mutex.unlock()


# Rotates the vertex passed in the parameter. Used to rotate slope data for the navigationmesh
func rotate_vertex(vertex: Vector3, degrees: int) -> Vector3:
	match degrees:
		90:
			return Vector3(-vertex.z, vertex.y, vertex.x)
		180:
			return Vector3(-vertex.x, vertex.y, -vertex.z)
		270:
			return Vector3(vertex.z, vertex.y, -vertex.x)
		_:
			return vertex


func _finish_unload():
	# Finally, queue the chunk itself for deletion.
	queue_free.call_deferred()
	


# We update the navigationmesh for this chunk with data generated from the blocks
func update_navigation_mesh():
	NavigationMeshGenerator.bake_from_source_geometry_data(navigation_mesh, source_geometry_data)
	navigation_region.navigation_mesh = navigation_mesh



# Each chunk will have it's own navigationmesh, which will be joined automatically on the global map
func setup_navigation():
	navigation_mesh.cell_size = 0.1
	navigation_mesh.agent_height = 0.5
	# Remember that the navigation mesh will shrink if you increase the agent_radius
	# This will happen to prevent the agent from hugging obstacles a lot
	navigation_mesh.agent_radius = 0.1
	navigation_mesh.agent_max_slope = 46
	# Create a new navigation region and set its transform based on mypos
	navigation_region = NavigationRegion3D.new()
	add_child(navigation_region)
	NavigationServer3D.map_set_cell_size(get_world_3d().get_navigation_map(),0.1)
