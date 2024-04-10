class_name Chunk
extends Node3D


# This script is it's own class and is not assigned to any particular node
# You can call Chunk.new() to create a new instance of this class
# This script will manage the internals of a map chunk
# A chunk is made up of blocks, slopes, furniture, mobs and items
# The first time a chunk is loaded, it will be from a map definition
# Each time after that, it will load whatever whas saved when the player exited the map
# When the player exits the map, the chunk will get saved so it can be loaded later
# During the game chunks will be loaded and unloaded to improve performance
# A chunk is defined by 21 levels and each level can potentially hold 32x32 blocks
# On top of the blocks we spawn mobs and furniture
# Loading and unloading of chunks is managed by levelGenerator.gd

# Reference to the level manager. Some nodes that could be moved to other chunks 
# should be parented to this (like moveable furniture and mobs)
var level_manager : Node3D
var level_generator : Node3D

# Constants
const MAX_LEVELS = 21
const LEVEL_WIDTH = 32
const LEVEL_HEIGHT = 32
var _mapleveldata: Array = [] # Holds the data for each level in this chunk
# Each chunk has it's own navigationmap because merging many navigationregions inside one general map
# will cause the game to stutter. The map for this chunk has one region and one navigationmesh
var navigation_map_id: RID
# This is a class variable to track block positions and data. It will contain:
# The position represented by a Vector3 in local coordinates
# The rotation represented by an int in degrees (0-360)
# The tilejson represented by a dictionary. This contains the id of the tile
var block_positions = {}
var chunk_data: Dictionary # The json data that defines this chunk
# A map is defined by the mapeditor. This variable holds the data that is processed from the map
# editor format into something usable for this chunk's generation
var processed_level_data: Dictionary = {}
var mutex: Mutex = Mutex.new() # Used to ensure thread safety
var mypos: Vector3 # The position in 3d space. Expect y to be 0
# Variables to enable navigation.
var navigation_region: NavigationRegion3D
var navigation_mesh: NavigationMesh = NavigationMesh.new()
var source_geometry_data: NavigationMeshSourceGeometryData3D
var chunk_mesh_body: StaticBody3D # The staticbody that will visualize the chunk mesh
var atlas_output: Dictionary # An atlas texture that combines all textures of this chunk's blocks
var level_nodes: Dictionary = {} # Keeps track of level nodes by their y_level


signal chunk_unloaded(chunkdata: Dictionary) # The chunk is fully unloaded
# Signals that the chunk is partly loaded and the next chunk can start loading
signal chunk_part_loaded()


func _ready():
	chunk_unloaded.connect(_finish_unload)
	source_geometry_data = NavigationMeshSourceGeometryData3D.new()
	setup_navigation()
	# The Helper keeps track of which navigationmap belogns to which chunk. When a navigationagent
	# crosses the chunk boundary, it will get the current chunk's navigationmap id to work with
	chunk_part_loaded.connect(Helper.on_chunk_loaded.bind({"mypos": mypos, "map": navigation_map_id}))
	chunk_unloaded.connect(Helper.on_chunk_unloaded.bind({"mypos": mypos}))
	transform.origin = Vector3(mypos)
	add_to_group("chunks")
	# Even though the chunk is not completely generated, we emit the signal now to prevent further
	# delays in generating or unloading the next chunk. Might remove this or move it to another place.
	chunk_part_loaded.emit()
	initialize_chunk_data()


func initialize_chunk_data():
	if is_new_chunk(): # This chunk is created for the first time
		#This contains the data of one segment, loaded from maps.data, for example generichouse.json
		var mapsegmentData: Dictionary = Helper.json_helper.load_json_dictionary_file(\
			Gamedata.data.maps.dataPath + chunk_data.id)
		if mapsegmentData.has("rotation") and not mapsegmentData.rotation == 0:
			rotate_map(mapsegmentData)
		_mapleveldata = mapsegmentData.levels
		generate_new_chunk()
	else: # This chunk is created from previously saved data
		generate_saved_chunk()


func generate_new_chunk():
	block_positions = create_block_position_dictionary_new_arraymesh()
	await Helper.task_manager.create_task(generate_chunk_mesh).completed
	await Helper.task_manager.create_task(update_all_navigation_data).completed
	processed_level_data = process_level_data()
	await Helper.task_manager.create_task(add_furnitures_to_new_block).completed
	await Helper.task_manager.create_task(add_block_mobs).completed


# Collects the furniture and mob data from the mapdata to be spawned later
func process_level_data():
	var level_number = 0
	var tileJSON: Dictionary = {}
	var proc_lvl_data: Dictionary = {"furn": [],"mobs": []}

	for level in _mapleveldata:
		if level != []:
			var y: int = level_number - 10
			var current_block = 0
			for h in range(LEVEL_HEIGHT):
				for w in range(LEVEL_WIDTH):
					if level[current_block]:
						tileJSON = level[current_block]
						if tileJSON.has("id") and tileJSON.id != "":
							if tileJSON.has("mob"):
								# We spawn it slightly above the block and let it fall. Might want to 
								# fiddle with the Y coordinate for optimalization
								proc_lvl_data.mobs.append({"json":tileJSON.mob, "pos":Vector3(w,y+1.5,h)})
							if tileJSON.has("furniture"):
								# We spawn it slightly above the block. Might want to 
								# fiddle with the Y coordinate for optimalization
								var furniturjson = tileJSON.furniture
								proc_lvl_data.furn.append({"json":furniturjson, "pos":Vector3(w,y+0.5,h)})
					current_block += 1
		level_number += 1
	return proc_lvl_data


# Creates a dictionary of all block positions with a local x,y and z position
# This function works with new mapdata
func create_block_position_dictionary_new_arraymesh() -> Dictionary:
	var new_block_positions:Dictionary = {}
	for level_index in range(len(_mapleveldata)):
		var level = _mapleveldata[level_index]
		if level != []:
			for h in range(LEVEL_HEIGHT):
				for w in range(LEVEL_WIDTH):
					var current_block_index = h * LEVEL_WIDTH + w
					if level[current_block_index]:
						var tileJSON = level[current_block_index]
						if tileJSON.has("id") and tileJSON.id != "":
							var block_position_key = str(w) + "," + str(level_index-10) + "," + str(h)
							# We only save the data we need, exluding mob and furniture data
							new_block_positions[block_position_key] = {
								"id": tileJSON.id,
								"rotation": tileJSON.get("rotation", 0)
							}
	return new_block_positions


# Generate a chunk that was previously saved
# After generating the mesh we add the items, furniture and mobs
func generate_saved_chunk() -> void:
	block_positions = chunk_data.block_positions
	await Helper.task_manager.create_task(generate_chunk_mesh).completed
	await Helper.task_manager.create_task(update_all_navigation_data).completed
	for item: Dictionary in chunk_data.items:
		add_item_to_map(item)
	
	# We duplicate the furnituredata for thread safety
	var furnituredata: Array = chunk_data.furniture.duplicate()
	await Helper.task_manager.create_task(add_furnitures_to_map.bind(furnituredata)).completed
	await Helper.task_manager.create_task(add_mobs_to_map).completed


# When a map is loaded for the first time we spawn the mob on the block
func add_block_mobs():
	if not processed_level_data.has("mobs"):
		return
	mutex.lock()
	var mobdatalist = processed_level_data.mobs.duplicate()
	mutex.unlock()
	for mobdata: Dictionary in mobdatalist:
		var newMob: CharacterBody3D = Mob.new()
		# Pass the position and the mob json to the newmob and have it construct itself
		newMob.construct_self(mypos+mobdata.pos, mobdata.json)
		level_manager.add_child.call_deferred(newMob)


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
		var furnituremapjson: Dictionary = furniture.json
		var furniturepos: Vector3 = furniture.pos
		var newFurniture: Node3D
		var furnitureJSON: Dictionary = Gamedata.get_data_by_id(\
			Gamedata.data.furniture, furnituremapjson.id)
		if furnitureJSON.has("moveable") and furnitureJSON.moveable:
			newFurniture = FurniturePhysics.new()
			furniturepos.y += 0.2 # Make sure it's not in a block and let it fall
		else:
			newFurniture = FurnitureStatic.new()

		newFurniture.construct_self(mypos+furniturepos, furnituremapjson)
		level_manager.add_child.call_deferred(newFurniture)
		
		# Insert delay after every n blocks, evenly spreading the delay
		if i % delay_every_n_furniture == 0 and i != 0: # Avoid delay at the very start
			OS.delay_msec(10) # Adjust delay time as needed

	# Optional: One final delay after the last block if the total_blocks is not perfectly divisible by delay_every_n_blocks
	if total_furniture % delay_every_n_furniture != 0:
		OS.delay_msec(10)


# Returns an array of furniture data that will be saved for this chunk
# Furniture that has it's x and z position in the boundary of the chunk's position and size
# will be included in the chunk data. So basically if the furniture is 'in' or 'on' the chunk.
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
				mutex.lock()
				newRot = furniture.last_rotation
				furniturepos = furniture.last_position
				#print_debug("removing furniture with posdition: ", furniturepos)
				mutex.unlock()
			else: # It's FurnitureStatic
				mutex.lock()
				newRot = furniture.get_my_rotation()
				furniturepos = furniture.furnitureposition
				mutex.unlock()
			# Check if furniture's position is within the desired range
			# It's possible some furniture is still spawning and have their position be 0,0,0
			# We do not want to save that furniture, just the ones at the other positions
			if _is_object_in_range(furniturepos) and not furniturepos == Vector3(0,0,0):
				furniture.remove_from_group.call_deferred("furniture")
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
		else:
			print_debug("Tried to get data from furniture, but it's null!")
	return furnitureData


# We check if the furniture or mob or item's position is inside this chunk on the x and z axis
func _is_object_in_range(objectposition: Vector3) -> bool:
		return objectposition.x >= mypos.x and \
		objectposition.x <= mypos.x + LEVEL_WIDTH and \
		objectposition.z >= mypos.z and \
		objectposition.z <= mypos.z + LEVEL_HEIGHT


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
			item.remove_from_group.call_deferred("mapitems")
			newitemData = myItem.duplicate()
			newitemData["global_position_x"] = item.containerpos.x
			newitemData["global_position_y"] = item.containerpos.y
			newitemData["global_position_z"] = item.containerpos.z
			newitemData["inventory"] = item.inventory.serialize()
			itemData.append(newitemData.duplicate())
			item.queue_free.call_deferred()
	return itemData


# Called when a save is loaded
func add_mobs_to_map() -> void:
	mutex.lock()
	var mobdata: Array = chunk_data.mobs.duplicate()
	mutex.unlock()
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
func add_furnitures_to_map(furnitureDataArray: Array):
	var newFurniture: Node3D
	
	var total_furniture = furnitureDataArray.size()
	 # Ensure we at least get 1 to avoid division by zero
	var delay_every_n_furniture = max(1, int(float(total_furniture) / 15.0))

	for i in range(total_furniture):
		var furnitureData = furnitureDataArray[i]
		mutex.lock()
		var furnitureJSON: Dictionary = Gamedata.get_data_by_id(
		Gamedata.data.furniture, furnitureData.id)
		mutex.unlock()

		if furnitureJSON.has("moveable") and furnitureJSON.moveable:
			newFurniture = FurniturePhysics.new()
		else:
			newFurniture = FurnitureStatic.new()

		# We can't set it's position until after it's in the scene tree 
		# so we only save the position to a variable and pass it to the furniture
		var furniturepos: Vector3 =  Vector3(furnitureData.global_position_x,furnitureData.global_position_y,furnitureData.global_position_z)
		newFurniture.construct_self(furniturepos,furnitureData)
		level_manager.add_child.call_deferred(newFurniture)
		
		# Insert delay after every n furniture, evenly spreading the delay
		if i % delay_every_n_furniture == 0 and i != 0: # Avoid delay at the very start
			OS.delay_msec(10) # Adjust delay time as needed

	# Optional: One final delay after the last furniture if the total_furniture is not perfectly divisible by delay_every_n_furniture
	if total_furniture % delay_every_n_furniture != 0:
		OS.delay_msec(10)


# Returns all the chunk data used for saving and loading
func get_chunk_data(chunkdata: Dictionary) -> void:
	mutex.lock()
	chunkdata.chunk_x = mypos.x
	chunkdata.chunk_z = mypos.z
	mutex.unlock()
	# The chunk is made from the block_positions data so we save this
	chunkdata.block_positions = block_positions.duplicate()
	chunkdata.furniture = get_furniture_data()
	chunkdata.mobs = get_mob_data()
	chunkdata.items = get_item_data()
	
	# Free the mesh and navigation elements
	chunk_mesh_body.queue_free()
	navigation_region.queue_free()
	NavigationServer3D.free_rid(navigation_map_id)


# Called by LevelGenerator.gd which manages the chunks and also by Helper.save_helper when
# switching to a different map. We start a new thread to collect map data and save it in
# the helper variable. First we wait until the current thread is finished.
func unload_chunk():
	var chunkdata: Dictionary = {}
	await Helper.task_manager.create_task(get_chunk_data.bind(chunkdata)).completed
	var chunkposition: Vector2 = Vector2(int(chunkdata.chunk_x/32),int(chunkdata.chunk_z/32))
	Helper.loaded_chunk_data.chunks[chunkposition] = chunkdata
	chunk_unloaded.emit()


# Adds triangles represented by 3 vertices to the navigation mesh data
# If a block is above another block, we make sure no plane is created in between
# For blocks we will create a square represented by 2 triangles
# The same goes for slopes, but 2 of the vertices are lowered to the ground
# keep in mind that after the navigationmesh is added to the navigationregion
# It will be shrunk by the navigation_mesh.agent_radius to prevent collisions
func add_mesh_to_navigation_data(blockposition: Vector3, blockrotation: int, blockshape: String):
	var block_global_position: Vector3 = blockposition# + mypos
	var blockrange: float = 0.5
	var extend: float = 1.0 # Amount to extend for edge blocks
	
	# Check if there's a block directly above the current block
	var above_key = str(blockposition.x) + "," + str(block_global_position.y + 1) + "," + str(blockposition.z)
	if block_positions.has(above_key):
		# There's a block directly above, so we don't add a face for the current block's top
		return
	
	# Determine if the block is at the edge of the chunk
	var is_edge_x = blockposition.x == 0 || blockposition.x == LEVEL_WIDTH - 1
	var is_edge_z = blockposition.z == 0 || blockposition.z == LEVEL_HEIGHT - 1

	# Adjust vertices for edge blocks
	var adjustment_x
	var adjustment_z
	if is_edge_x:
		adjustment_x = extend
	else:
		adjustment_x = 0
	if is_edge_z:
		adjustment_z = extend
	else:
		adjustment_z = 0

	if blockshape == "cube":
		# Top face of a block, the block size is 1x1x1 for simplicity.
		var top_face_vertices = PackedVector3Array([
			# First triangle
			Vector3(-blockrange - adjustment_x, 0.5, -blockrange - adjustment_z), # Top-left
			Vector3(blockrange + adjustment_x, 0.5, -blockrange - adjustment_z), # Top-right
			Vector3(blockrange + adjustment_x, 0.5, blockrange + adjustment_z), # Bottom-right
			# Second triangle
			Vector3(-blockrange - adjustment_x, 0.5, -blockrange - adjustment_z), # Top-left (repeated for the second triangle)
			Vector3(blockrange + adjustment_x, 0.5, blockrange + adjustment_z), # Bottom-right (repeated for the second triangle)
			Vector3(-blockrange - adjustment_x, 0.5, blockrange + adjustment_z)  # Bottom-left
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


# Finally, queue the chunk itself for deletion.
func _finish_unload():
	queue_free.call_deferred()


# We update the navigationmesh for this chunk with data generated from the blocks
func update_navigation_mesh():
	NavigationServer3D.bake_from_source_geometry_data_async(navigation_mesh, source_geometry_data, _on_finish_baking)


# When the navigationserver is done baking, we update the navigationmesh. Since each chunk has it's
# own navigationmap, this does not cause a stutter in the gameplay. However, if you change it so that all
# chunks share the same navigationmap, calling this will cause a stutter because the navigation
# synchronisation happens on the main thread.
func _on_finish_baking():
	navigation_region.set_navigation_mesh(navigation_mesh)


# Setup the navigation for this chunk. It gets a new map and a new region
# You can fiddle with the numbers to improve agent navigation
func setup_navigation():
	# Adjust the navigation mesh settings as before
	navigation_mesh.cell_size = 0.1
	navigation_mesh.agent_height = 0.5
	# Changint the agent_radius will also make the navigationmesh grow or shrink. This is because 
	# there is a margin around the navigationmesh to prevent agents from colliding with the wall.
	navigation_mesh.agent_radius = 0.2
	navigation_mesh.agent_max_slope = 46

	# Create a new navigation region for this chunk
	navigation_region = NavigationRegion3D.new()
	add_child(navigation_region)

	# Create a new navigation map specifically for this chunk
	navigation_map_id = NavigationServer3D.map_create()
	NavigationServer3D.map_set_active(navigation_map_id, true)

	# The navigation region of this chunk is associated with its own navigation map
	# The cell size should be the same as the navigation_mesh.cell_size
	NavigationServer3D.map_set_cell_size(navigation_map_id, 0.1)

	# Set the new navigation map to the navigation region
	navigation_region.set_navigation_map(navigation_map_id)


# This function creates a atlas texture which is a combination of the textures that we need
# for the blocks in this chunk. When there are more different blocks in the chunk, the atlas will
# be bigger. The atlas texture will be used by the rendering engine to render the right texture
# This function will also create a mapping of the texture and the coordinates in the atlas
# This will help to determine which block needs which coordinate on the atlas to display the right texture
func create_atlas() -> Dictionary:
	var material_to_blocks: Dictionary = {} # Dictionary to hold blocks organized by material
	var block_uv_map: Dictionary = {} # Dictionary to map block IDs to their UV coordinates in the atlas
	
	# Organize the materials we need into a dictionary
	for key: String in block_positions.keys():
		var block_data: Dictionary = block_positions[key]
		var material_id: String = str(block_data["id"]) # Key for material ID
		if not material_to_blocks.has(material_id):
			var sprite = Gamedata.get_sprite_by_id(Gamedata.data.tiles, material_id)
			if sprite:
				material_to_blocks[material_id] = sprite.albedo_texture

	# Calculate the atlas size needed
	var num_textures: int = material_to_blocks.keys().size()
	var atlas_dimension = int(ceil(sqrt(num_textures))) # Convert to int to ensure modulus operation works
	var texture_size = 128 # Assuming each texture is 128x128 pixels
	var atlas_pixel_size = atlas_dimension * texture_size

	# Create a large blank Image for the atlas
	var atlas_image = Image.create(atlas_pixel_size, atlas_pixel_size, false, Image.FORMAT_RGBA8)
	atlas_image.fill(Color(0, 0, 0, 0)) # Transparent background

	# Step 3: Blit each texture onto the atlas and update block_uv_map
	var texposition = Vector2.ZERO
	var index = 0
	for material_id in material_to_blocks.keys():
		
		var texture: Image = material_to_blocks[material_id].get_image()
		
		var img: Image = texture.duplicate()
		if img.is_compressed():
			img.decompress() # Decompress if the image is compressed
		img.convert(Image.FORMAT_RGBA8) # Convert texture to RGBA8 format
		var dest_rect = Rect2(texposition, img.get_size())
		var used_rect: Rect2i = img.get_used_rect()
		
		if img.is_empty(): # Check if the image data is empty
			continue # Skip this texture as it's not loaded properly
		atlas_image.blit_rect(img, used_rect, dest_rect.position)

		# Calculate and store the UV offset and scale for this material
		var uv_offset = texposition / atlas_pixel_size
		var uv_scale = img.get_size() / float(atlas_pixel_size)
		block_uv_map[material_id] = {"offset": uv_offset, "scale": uv_scale}

		# Update position for the next texture
		index += 1
		if index % atlas_dimension == 0:
			texposition.x = 0
			texposition.y += texture_size
		else:
			texposition.x = (index % atlas_dimension) * texture_size

	# Convert the atlas Image to a Texture
	var atlas_texture = ImageTexture.create_from_image(atlas_image)
	return {"atlas_texture": atlas_texture, "block_uv_map": block_uv_map}


# This will add the following to the "arrays" parameter:
# arrays[ArrayMesh.ARRAY_VERTEX] = verts
# arrays[ArrayMesh.ARRAY_NORMAL] = normals
# arrays[ArrayMesh.ARRAY_TEX_UV] = uvs
# arrays[ArrayMesh.ARRAY_INDEX] = indices
# This represents the data that will be used to create an arraymesh, which visualizes the blocks
# The block_uv_map is used to map the block id to the right uv coordinates on the atlas texture
# This function will now take a 'blocks_at_same_y' array instead of using 'block_positions.keys()'.
func prepare_mesh_data(arrays: Array, blocks_at_same_y: Array, block_uv_map: Dictionary) -> void:
	# Define a small margin to prevent seams
	var margin: float = 0.01

	var verts = PackedVector3Array()
	var uvs = PackedVector2Array()
	var normals = PackedVector3Array()
	var indices = PackedInt32Array()

	# Assume a block size for the calculations
	var block_size: float = 1.0

	# Iterate over the passed 'blocks_at_same_y' array instead of 'block_positions.keys()'.
	for block_info in blocks_at_same_y:
		var key = block_info["position_key"]
		var block_data = block_info["block_data"]
		
		var pos_array = key.split(",")
		var poslocal = Vector3(float(pos_array[0]), float(pos_array[1]), float(pos_array[2]))
		
		# Adjust position based on the block size
		var pos = poslocal * block_size
		var material_id = str(block_data["id"])
		
		# Get the shape of the block
		var tileJSONData = Gamedata.get_data_by_id(Gamedata.data.tiles,block_data.id)
		var blockshape = tileJSONData.get("shape", "cube")
		block_data["shape"] = blockshape # store for later use
		
		# Calculate UV coordinates based on the atlas
		var uv_info = block_uv_map[material_id] if block_uv_map.has(material_id) else {"offset": Vector2(0, 0), "scale": Vector2(1, 1)}
		var uv_offset = Vector2(uv_info["offset"])#.to_vector2() # Convert to Vector2 if needed
		var uv_scale = Vector2(uv_info["scale"])#.to_vector2() # Convert to Vector2 if needed

		# Adjust the UVs to include the margin uniformly
		var top_face_uv = PackedVector2Array([
			(Vector2(0, 0) * uv_scale + Vector2(margin, margin)) + uv_offset,
			(Vector2(1, 0) * uv_scale + Vector2(-margin, margin)) + uv_offset,
			(Vector2(1, 1) * uv_scale + Vector2(-margin, -margin)) + uv_offset,
			(Vector2(0, 1) * uv_scale + Vector2(margin, -margin)) + uv_offset
		])
		var blockrotation: int = 0
		if is_new_chunk(): # This chunk is created for the first time, so we need to save 
			# the rotation to the block json dictionary
			blockrotation = get_block_rotation(blockshape, block_data.rotation)
			block_data["rotation"] = blockrotation
		else: # Rotation has been previously saved so we can use that
			blockrotation = block_data.rotation
		
		if blockshape == "cube":
			setup_cube(pos, blockrotation, verts, uvs, normals, indices, top_face_uv)
		elif blockshape == "slope":
			setup_slope(blockrotation, pos, verts, uvs, normals, indices, top_face_uv)

	# Assign the generated mesh data to the 'arrays' parameter
	arrays[ArrayMesh.ARRAY_VERTEX] = verts
	arrays[ArrayMesh.ARRAY_NORMAL] = normals
	arrays[ArrayMesh.ARRAY_TEX_UV] = uvs
	arrays[ArrayMesh.ARRAY_INDEX] = indices


# Creates the entire chunk including:
# - Mesh shape
# - Mesh texture
# - Navigation map
# - Colliders
func generate_chunk_mesh():
	# Create the atlas and get the atlas texture
	atlas_output = create_atlas()

	for level_index in range(MAX_LEVELS):
		var y_level = level_index - 10  # Calculate the y-level offset if needed
		generate_chunk_mesh_for_level(y_level)

	# Create the static body for collision
	chunk_mesh_body = StaticBody3D.new()
	chunk_mesh_body.disable_mode = CollisionObject3D.DISABLE_MODE_MAKE_STATIC
	# Set collision layer to layer 1 and 5
	chunk_mesh_body.collision_layer = 1 | (1 << 4) # Layer 1 is 1, Layer 5 is 1 << 4 (16), combined with bitwise OR
	# Set collision mask to layer 1
	chunk_mesh_body.collision_mask = 1 # Layer 1 is 1
	add_child.call_deferred(chunk_mesh_body)
	create_colliders()



# Function to find all blocks on the same y level
func find_blocks_at_y_level(y_level: int) -> Array:
	var blocks_at_same_y = []
	for key in block_positions.keys():
		var pos_array = key.split(",")
		if int(pos_array[1]) == y_level:
			blocks_at_same_y.append({
				"position_key": key,
				"block_data": block_positions[key]
			})
	return blocks_at_same_y


func setup_slope(blockrotation: int, pos: Vector3, verts, uvs, normals, indices, top_face_uv):
	# Slope-specific vertices and UV mapping
	# Determine slope orientation and vertices based on blockrotation
	var slope_vertices: PackedVector3Array
	# Assume a block size for the calculations
	var half_block = 0.5
	match blockrotation:
		90:
			# Slope facing Facing north
			slope_vertices = PackedVector3Array([
				Vector3(-half_block, half_block, -half_block) + pos, # Top front left
				Vector3(half_block, half_block, -half_block) + pos,   # Top front right
				Vector3(half_block, -half_block, half_block) + pos,  # Bottom back right
				Vector3(-half_block, -half_block, half_block) + pos  # Bottom back left
			])
		180:
			# Slope facing Facing west
			slope_vertices = PackedVector3Array([
				Vector3(-half_block, half_block, half_block) + pos, # Top front left
				Vector3(-half_block, half_block, -half_block) + pos,   # Top front right
				Vector3(half_block, -half_block, -half_block) + pos,  # Bottom back right
				Vector3(half_block, -half_block, half_block) + pos  # Bottom back left
			])
		270:
			# Slope facing Facing south
			slope_vertices = PackedVector3Array([
				Vector3(half_block, half_block, half_block) + pos, # Top front left
				Vector3(-half_block, half_block, half_block) + pos,   # Top front right
				Vector3(-half_block, -half_block, -half_block) + pos,  # Bottom back right
				Vector3(half_block, -half_block, -half_block) + pos  # Bottom back left
			])
		_:
			# Slope facing Facing east
			slope_vertices = PackedVector3Array([
				Vector3(half_block, half_block, -half_block) + pos, # Top front left
				Vector3(half_block, half_block, half_block) + pos,   # Top front right
				Vector3(-half_block, -half_block, half_block) + pos,  # Bottom back right
				Vector3(-half_block, -half_block, -half_block) + pos  # Bottom back left
			])

	# Assuming the top_face_uv calculated for cubes applies here as well
	verts.append_array(slope_vertices)
	uvs.append_array(top_face_uv)  # Reuse the UV mapping for simplicity in this example
	
	# Normals for the slope's top face, assuming flat shading for simplicity
	var normal = Vector3(0, 1, 0)  # Adjust if your slope's top face orientation varies
	for _i in range(4):
		normals.append(normal)
	
	# Indices for the slope, similar to the cube but only for one triangular face
	var base_index = verts.size() - 4
	indices.append_array([
		base_index, base_index + 1, base_index + 2,
		base_index, base_index + 2, base_index + 3
	])


# Coroutine for creating colliders with non-blocking delays
func create_colliders() -> void:
	var total_blocks = block_positions.size()
	# Ensure we at least get 1 to avoid division by zero. Aim for a maximum of 15 steps.
	var delay_every_n_blocks = max(1, total_blocks / 15)
	var block_counter = 0

	for key in block_positions.keys():
		var pos_array = key.split(",")
		var block_pos = Vector3(float(pos_array[0]), float(pos_array[1]), float(pos_array[2]))
		var block_data = block_positions[key]
		var block_shape = block_data.get("shape", "cube")
		var block_rotation = block_data.get("rotation", 0)
		chunk_mesh_body.add_child.call_deferred(_create_block_collider(block_pos, block_shape, block_rotation))

		block_counter += 1
		# Check if it's time to delay
		if block_counter % delay_every_n_blocks == 0 and block_counter < total_blocks:
			await get_tree().create_timer(0.1).timeout


# Creates a collider for either a slope or a cube and puts it at the right place and rotation
func _create_block_collider(block_sub_position, shape: String, block_rotation: int) -> CollisionShape3D:
	var collider = CollisionShape3D.new()
	if shape == "cube":
		collider.shape = BoxShape3D.new()
		collider.set_transform.call_deferred(Transform3D(Basis(), block_sub_position))
	else: # It's a slope
		collider.shape = ConvexPolygonShape3D.new()
		collider.shape.points = [
			Vector3(0.5, 0.5, 0.5),
			Vector3(0.5, 0.5, -0.5),
			Vector3(-0.5, -0.5, 0.5),
			Vector3(0.5, -0.5, 0.5),
			Vector3(0.5, -0.5, -0.5),
			Vector3(-0.5, -0.5, -0.5)
		]
		# Apply rotation only for slopes
		# Set the rotation part of the Transform3D
		var rotation_transform = Transform3D(Basis().rotated(Vector3.UP, deg_to_rad(block_rotation)), Vector3.ZERO)
		# Now combine rotation and translation in the transform
		collider.set_transform.call_deferred(rotation_transform.translated(block_sub_position))
	return collider


# Rotates a 3D vertex around the Y-axis
func rotate_vertex_y(vertex: Vector3, degrees: float) -> Vector3:
	var rad = deg_to_rad(degrees)
	var cos_rad = cos(rad)
	var sin_rad = sin(rad)
	return Vector3(
		cos_rad * vertex.x + sin_rad * vertex.z,
		vertex.y,
		-sin_rad * vertex.x + cos_rad * vertex.z
	)


# Only newly created blocks will need this calculation
# Previously saved blocks do not.
func get_block_rotation(shape: String, tilerotation: int = 0) -> int:
	var defaultRotation: int = 0
	if shape == "slope":
		defaultRotation = 90
	# The slope has a default rotation of 90
	# The block has a default rotation of 0
	var myRotation: int = tilerotation + defaultRotation
	if myRotation == 0:
		# Only the block will match this case, not the slope. The block points north
		return myRotation+180
	elif myRotation == 90:
		# A block will point east
		# A slope will point north
		return myRotation+0
	elif myRotation == 180:
		# A block will point south
		# A slope will point east
		return myRotation-180
	elif myRotation == 270:
		# A block will point west
		# A slope will point south
		return myRotation+0
	elif myRotation == 360:
		# Only a slope can match this case if it's rotation is 270 and it gets 90 rotation by default
		return myRotation-180
	return myRotation

# New chunks will have the id in the chunk data. In that case it returns true
# Previously saved chunks will not have id in the data and it returns false
func is_new_chunk() -> bool:
	return chunk_data.has("id")


# Called when the player builds a new block on the map
# We update the block_positions to include the new block
# We have to update te chunk mesh and the navigationmesh
# We also need to add a collider for the new block
func add_block(block_id: String, block_position: Vector3):
	# Generate a key for the new block position
	var block_key = "%s,%s,%s" % [block_position.x, block_position.y, block_position.z]
	
	# Check if the block already exists
	if block_positions.has(block_key):
		print_debug("Block at position ", block_key, " already exists.")
		return # Exit the function if the block already exists
	
	# Update block_positions with the new block data
	block_positions[block_key] = {
		"id": block_id,
		"rotation": 0,  # Assume default rotation; adjust if necessary
	}
	
	# We have to refresh the atlas because the player may introduce a new block ID
	# TODO: Optimization potential: we can check if the atlas needs an update by checking
	# if the block id is present in the material_to_blocks variable in the create_atlas function.
	# Obviously we need access to the material_to_blocks variable and keep it's value persistent.
	atlas_output = create_atlas()
	# Regenerate mesh for the affected level
	generate_chunk_mesh_for_level(int(block_position.y))
	# Update the navigation data based on all blocks
	# We can't do this for a specific level, since we have 1 navigationmesh
	# If we had multiple navigationmeshes, we could create one per level
	await Helper.task_manager.create_task(update_all_navigation_data).completed

	# Create and add a new collider for the block
	var new_collider = _create_block_collider(block_position, "cube", 0)  # Cube shape; rotation 0
	chunk_mesh_body.add_child.call_deferred(new_collider)


# Adjusted to accept atlas data directly
func generate_chunk_mesh_for_level(y_level: int):
	var blocks_at_same_y = find_blocks_at_y_level(y_level)
	if blocks_at_same_y.size() > 0:
		# Use the passed atlas data
		var atlas_texture = atlas_output["atlas_texture"]
		var block_uv_map = atlas_output["block_uv_map"]
		var arrays = []
		arrays.resize(ArrayMesh.ARRAY_MAX)
		prepare_mesh_data(arrays, blocks_at_same_y, block_uv_map)

		# Create a MeshInstance3D for each level with the prepared mesh data
		var mesh = ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

		# Apply the shared atlas texture to a StandardMaterial3D
		var material = StandardMaterial3D.new()
		material.albedo_texture = atlas_texture

		# Create and configure the mesh instance for the level
		var mesh_instance = MeshInstance3D.new()
		mesh_instance.mesh = mesh
		mesh.surface_set_material(0, material)

		# Check if a level node exists for this y_level
		if level_nodes.has(y_level):
			var existing_level_node = level_nodes[y_level]
			# Replace the old mesh instance with the new one
			existing_level_node.remove_child(existing_level_node.get_child(0)) # Assumes only one child
			existing_level_node.add_child(mesh_instance)
		else:
			# Create a new level node
			var level_node = ChunkLevel.new()
			# We don't set the y position of the chunklevel because that would mess up the mesh placement
			# since the mesh will enhirit the position of the chunklevel. So instead we just save the
			# y_level to the level node. The purpose of this is to allow hiding levels above the player
			level_node.y = y_level
			level_node.name = "Level_" + str(y_level)
			level_node.add_child(mesh_instance)
			add_child.call_deferred(level_node) # Add the level node to the chunk
			# Store the reference to the new level node
			level_nodes[y_level] = level_node


# Rebuilds the navigationmesh for all blocks in the chunk
# We can't do this for a specific level, since we have 1 navigationmesh
# If we had multiple navigationmeshes, we could create one per level, which is more optimized
func update_all_navigation_data():
	for key in block_positions.keys():
		var block_data: Dictionary = block_positions[key]
		var pos_array = key.split(",")
		var block_position = Vector3(float(pos_array[0]), float(pos_array[1]), float(pos_array[2]))
		var block_rotation = block_data.rotation
		var block_shape = block_data.get("shape", "cube")
		#var block_shape = Gamedata.get_data_by_id(Gamedata.data.tiles, block_data.id).shape
		
		add_mesh_to_navigation_data(block_position, block_rotation, block_shape)
	update_navigation_mesh()


# Creates the vertices for a mesh that makes up a cube
# Couldn't get it to work with a for-loop, so every side is explicitly defined
# TODO: instead of making all the faces, only add them if there is no neighboring cube
# We can do this by checking the neighbor:
	# Directions corresponding to the faces
	#var directions = [
		#Vector3(0, 0, -1), # Front
		#Vector3(1, 0, 0),  # Right
		#Vector3(0, 0, 1),  # Back
		#Vector3(-1, 0, 0), # Left
		#Vector3(0, 1, 0),  # Top
	#]
	#var neighbor_pos = pos + directions[i]
	#var neighbor_key = "%s,%s,%s" % [neighbor_pos.x, neighbor_pos.y, neighbor_pos.z]
	#if not block_positions.has(neighbor_key): # Check if there is no block at the neighbor position
# If it does not have a neighbor, we would add the face.
func setup_cube(pos: Vector3, blockrotation: int, verts, uvs, normals, indices, top_face_uv):
	var half_block = 0.5

	# Top face vertices
	var top_verts = [
		Vector3(-half_block, half_block, -half_block) + pos,  # top-left-front
		Vector3(half_block, half_block, -half_block) + pos,   # top-right-front
		Vector3(half_block, half_block, half_block) + pos,    # top-right-back
		Vector3(-half_block, half_block, half_block) + pos    # top-left-back
	]

	# Left face vertices
	var left_verts = [
		Vector3(-half_block, half_block, -half_block) + pos,  # top-left-front
		Vector3(-half_block, half_block, half_block) + pos,   # top-left-back
		Vector3(-half_block, -half_block, half_block) + pos,  # bottom-left-back
		Vector3(-half_block, -half_block, -half_block) + pos  # bottom-left-front
	]
	
	# Right face vertices (x value set to half_block for all, adjusted order)
	var right_verts = [
		Vector3(half_block, half_block, half_block) + pos,   # top-right-back
		Vector3(half_block, half_block, -half_block) + pos,  # top-right-front
		Vector3(half_block, -half_block, -half_block) + pos, # bottom-right-front
		Vector3(half_block, -half_block, half_block) + pos   # bottom-right-back
	]

	# Front face vertices (z value set to -half_block for all, adjusted order)
	var front_verts = [
		Vector3(half_block, half_block, -half_block) + pos,   # top-right-front
		Vector3(-half_block, half_block, -half_block) + pos,  # top-left-front
		Vector3(-half_block, -half_block, -half_block) + pos, # bottom-left-front
		Vector3(half_block, -half_block, -half_block) + pos   # bottom-right-front
	]

	# Back face vertices (z value set to half_block for all)
	var back_verts = [
		Vector3(-half_block, half_block, half_block) + pos,   # top-left-back
		Vector3(half_block, half_block, half_block) + pos,    # top-right-back
		Vector3(half_block, -half_block, half_block) + pos,   # bottom-right-back
		Vector3(-half_block, -half_block, half_block) + pos   # bottom-left-back
	]

	# Rotate only the top-face vertices by blockrotation around the Y axis at position
	var rotated_top_verts = []
	for vertex in top_verts:
		rotated_top_verts.append(rotate_vertex_y(vertex - pos, blockrotation) + pos)

	# Add vertices to arrays
	verts.append_array(rotated_top_verts)
	verts.append_array(left_verts)
	verts.append_array(right_verts)
	verts.append_array(front_verts)        # Front face
	verts.append_array(back_verts)        # back face

	# Append UVs for each face
	uvs.append_array(top_face_uv)   # Assuming top_face_uv is already defined
	uvs.append_array(top_face_uv)  # We won't see the left face, so we can just apply the top face uvs
	uvs.append_array(top_face_uv)  # We won't see the right face, so we can just apply the top face uvs
	uvs.append_array(top_face_uv)  # We won't see the front face, so we can just apply the top face uvs
	uvs.append_array(top_face_uv)  # We won't see the back face, so we can just apply the top face uvs

	# Add normals (assuming flat shading and orthogonal faces)
	for _i in range(4): 
		normals.append(Vector3(0, 1, 0))  # Top face
	for _i in range(4): 
		normals.append(Vector3(-1, 0, 0))  # west-facing face
	for _i in range(4): 
		normals.append(Vector3(1, 0, 0))   # east-facing face
	for _i in range(4):
		normals.append(Vector3(0, 0, -1))   # north-facing face
	for _i in range(4):
		normals.append(Vector3(0, 0, 1))  # south-facing face

	# Add indices for top, left, and right faces
	var top_base_index = verts.size() - 20
	var left_base_index = verts.size() - 16
	var right_base_index = verts.size() - 12
	var front_base_index = verts.size() - 8
	var back_base_index = verts.size() - 4
	indices.append_array([
		top_base_index, top_base_index + 1, top_base_index + 2,
		top_base_index, top_base_index + 2, top_base_index + 3
	])
	indices.append_array([
		left_base_index, left_base_index + 1, left_base_index + 2,
		left_base_index, left_base_index + 2, left_base_index + 3
	])
	indices.append_array([
		right_base_index, right_base_index + 1, right_base_index + 2,
		right_base_index, right_base_index + 2, right_base_index + 3
	])
	indices.append_array([
		front_base_index, front_base_index + 1, front_base_index + 2,
		front_base_index, front_base_index + 2, front_base_index + 3
	])
	indices.append_array([
		back_base_index, back_base_index + 1, back_base_index + 2,
		back_base_index, back_base_index + 2, back_base_index + 3
	])



# This function will loop over all levels and rotate them if they contain tile data.

func rotate_map(mapsegmentData: Dictionary) -> void:
	for i in range(len(mapsegmentData.levels)):
		var level_data = mapsegmentData.levels[i]
		mapsegmentData.levels[i] = rotate_level_clockwise(level_data)


# Function to rotate a single level's data 90 degrees clockwise
func rotate_level_clockwise(level_data: Array) -> Array:
	if level_data.size() == 0:
		return level_data

	var new_level_data: Array[Dictionary] = []
	# Initialize new_level_data with empty dictionaries
	for i in range(LEVEL_WIDTH * LEVEL_HEIGHT):
		new_level_data.append({})

	for y in range(LEVEL_HEIGHT):
		for x in range(LEVEL_WIDTH):
			var old_index = y * LEVEL_WIDTH + x
			var new_x = LEVEL_HEIGHT - y - 1
			var new_y = x
			var new_index = new_y * LEVEL_WIDTH + new_x
			new_level_data[new_index] = level_data[old_index].duplicate(true)

			# Add rotation to the tile's data if it has an "id"
			if new_level_data[new_index].has("id"):
				var tile_rotation = int(new_level_data[new_index].get("rotation", 0))
				new_level_data[new_index]["rotation"] = (tile_rotation + 90) % 360
			
			# Rotate furniture if present, initializing rotation to 0 if not set
			if new_level_data[new_index].has("furniture"):
				var furniture_rotation = int(new_level_data[new_index]["furniture"].get("rotation", 0))
				new_level_data[new_index]["furniture"]["rotation"] = (furniture_rotation + 90) % 360

	return new_level_data
