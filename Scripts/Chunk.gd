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
var thread: Thread
#var navigationthread: Thread
var mypos: Vector3
var navigation_region: NavigationRegion3D
#var navigation_region: RID
var navigation_mesh: NavigationMesh = NavigationMesh.new()
var source_geometry_data: NavigationMeshSourceGeometryData3D
var initialized_blocks_count: int = 0


func _ready():
	source_geometry_data = NavigationMeshSourceGeometryData3D.new()
	setup_navigation.call_deferred()
	transform.origin = Vector3(mypos)
	add_to_group("chunks")
	initialize_chunk_data()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass


# Thread must be disposed (or "joined"), for portability.
func _exit_tree():
	print_debug("chunk is leaving the scene tree")
	#thread.wait_to_finish()


func initialize_chunk_data():
	#thread = Thread.new()
	if chunk_data.has("id"): # This chunk is created for the first time
		#This contains the data of one segment, loaded from maps.data, for example generichouse.json
		var mapsegmentData: Dictionary = Helper.json_helper.load_json_dictionary_file(\
			Gamedata.data.maps.dataPath + chunk_data.id)
		_mapleveldata = mapsegmentData.levels
		var task_id = WorkerThreadPool.add_task(create_block_position_dictionary_new)
		WorkerThreadPool.wait_for_task_completion(task_id)
		# Other code that depends on the enemy AI already being processed.
		#task_id = WorkerThreadPool.add_task(generate_new_chunk)
		generate_new_chunk()
	else: # This chunk is created from previously saved data
		_mapleveldata = chunk_data.maplevels
		var task_id = WorkerThreadPool.add_task(create_block_position_dictionary_loaded)
		WorkerThreadPool.wait_for_task_completion(task_id)
		#task_id = WorkerThreadPool.add_task(generate_saved_chunk)
		generate_saved_chunk()

func generate_new_chunk():
	var tileJSON: Dictionary = {}
	# Initialize the counter and expected count
	var level_number = 0
	initialized_blocks_count = 0

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
							create_block_by_id(level_node,w,h,tileJSON)
							add_block_mob(tileJSON, Vector3(w,y_position+1.5,h))
							add_furniture_to_block(tileJSON, Vector3(w,y_position,h))
							blocks_created += 1
					current_block += 1
			if !blocks_created > 0:
				level_node.remove_from_group.call_deferred("maplevels")
				_levels.erase(level_node)
				level_node.queue_free()
			
		level_number += 1


# Creates a dictionary of all block positions with a local x,y and z position
# This function works with new mapdata
func create_block_position_dictionary_new():
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
							block_positions[block_position_key] = true


# Creates a dictionary of all block positions with a local x,y and z position
# This function works with previously saved chunk data
func create_block_position_dictionary_loaded():
	for level_index in range(len(_mapleveldata)):
		var level = _mapleveldata[level_index]
		if level.blocks != []:
			for savedBlock in level.blocks:
				if savedBlock.has("id") and not savedBlock.id == "":
					var block_position_key = str(savedBlock.block_x) + "," + str(level.map_y) + "," + str(savedBlock.block_z)
					block_positions[block_position_key] = true


func setup_navigation():
	navigation_mesh.cell_size = 0.1
	navigation_mesh.agent_height = 0.5
	navigation_mesh.agent_radius = 0.1
	navigation_mesh.agent_max_slope = 46
	# Create a new navigation region and set its transform based on mypos
	navigation_region = NavigationRegion3D.new()
	add_child(navigation_region)
	NavigationServer3D.map_set_cell_size(get_world_3d().get_navigation_map(),0.1)


func update_navigation_mesh():
	NavigationMeshGenerator.bake_from_source_geometry_data(navigation_mesh, source_geometry_data)
	navigation_region.navigation_mesh = navigation_mesh


# Creates one level of blocks, for example level 0 will be the ground floor
# Can contain a maximum of 32x32 or 1024 blocks
func create_level_node(ypos: int) -> ChunkLevel:
	var level_node = ChunkLevel.new()
	level_node.add_to_group("maplevels")
	add_child.call_deferred(level_node)
	_levels.append(level_node)
	level_node.levelposition = Vector3(0,ypos,0)
	return level_node


# Creates a new block and adds it to the level node
# Also adds the top surface to the navigationmesh data
func create_block_by_id(level_node,w,h,tileJSON):
	var block = DefaultBlock.new()
	block.construct_self(Vector3(w,0,h), tileJSON) # Sets its own properties that can be set before spawn
	# Adds the top surface to the navigation data
	add_mesh_to_navigation_data(block, level_node.levelposition.y)
	block.ready.connect(_on_Block_ready) # Needed to know when all the blocks are created
	level_node.add_child.call_deferred(block)


# Called when a block is ready and added to the tree. We need to count them to be sure
# That all the blocks have been created before we proceed
func _on_Block_ready():
	initialized_blocks_count += 1
	if initialized_blocks_count == block_positions.size():
		print_debug("All blocks have been initialized.")
		# Since all the required block data has been added to the navigationmesh data previously,
		# We update the navigationmesh and region using this data
		update_navigation_mesh()


# Generate the map layer by layer
# For each layer, add all the blocks with proper rotation
# If a block has an mob, add it too
func generate_saved_chunk() -> void:
	initialized_blocks_count = 0
	#we need to generate level layer by layer starting from the bottom
	for level: Dictionary in chunk_data.maplevels:
		if level != {}:
			var level_node = create_level_node(level.map_y)
			generate_saved_level(level, level_node)

	for mob: Dictionary in chunk_data.mobs:
		add_mob_to_map.call_deferred(mob)

	for item: Dictionary in chunk_data.items:
		add_item_to_map.call_deferred(item)

	for furnitureData: Dictionary in chunk_data.furniture:
		add_furniture_to_map.call_deferred(furnitureData)


# Generates blocks on in the provided level. A level contains at most 32x32 blocks
func generate_saved_level(level: Dictionary, level_node: Node3D) -> void:
	for savedBlock in level.blocks:
		if savedBlock.has("id") and not savedBlock.id == "":
			create_block_by_id(level_node,savedBlock.block_x,savedBlock.block_z,savedBlock)
		else:
			print_debug("generate_saved_level: block has no id!")


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
	return {
			"chunk_x": global_position.x,
			"chunk_z": global_position.z,
			"maplevels": get_map_data(),
			"furniture": get_furniture_data(),
			"mobs": get_mob_data(),
			"items": get_item_data()
		}


# Adds triangles represented by 3 vertices to the navigation mesh data
# If a block is above another block, we make sure no plane is created in between
# For blocks we will create a square represented by 2 triangles
# The same goes for slopes, but 2 of the vertices are lowered to the ground
# keep in mind that after the navigationmesh is added to the navigationregion
# It will be shrunk by the navigation_mesh.agent_radius to prevent collisions
func add_mesh_to_navigation_data(block, level_y):
	var block_global_position: Vector3 = block.blockposition# + mypos
	block_global_position.y = level_y
	var blockrange: float = 0.5
	
	# Check if there's a block directly above the current block
	var above_key = str(block.blockposition.x) + "," + str(level_y + 1) + "," + str(block.blockposition.z)
	if block_positions.has(above_key):
		# There's a block directly above, so we don't add a face for the current block's top
		return

	if block.shape == "block":
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
		source_geometry_data.add_faces(top_face_vertices, Transform3D(Basis(), block_global_position))
	elif block.shape == "slope":
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
		var blockrot: int = block.get_block_rotation()
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
		source_geometry_data.add_faces(slope_faces, Transform3D(Basis(), block_global_position))


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
