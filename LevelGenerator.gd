extends Node3D


var map_save_folder: String

# The amount of blocks that make up a level
var level_width : int = 32
var level_height : int = 32

@export var level_manager : Node3D
@export var chunkScene: PackedScene = null
@export_file var default_level_json


# Parameters for dynamic chunk loading
var creation_radius = 1
var survival_radius = 2
var loaded_chunks = {} # Dictionary to store loaded chunks with their positions as keys
var player_position = Vector2.ZERO # Player's position, updated regularly
# Chunks are loaded and unloaded one at a time. The load_queue will be processed before the unload_queue
# Chunks that should be loaded and unloaded are stored inside these variables
var load_queue = []
var unload_queue = []
# Enforces loading or unloading one chunk at a time
var is_processing_chunk = false


# Called when the node enters the scene tree for the first time.
func _ready():
	initialize_map_data()
	
	# Start a loop to update chunks based on player position
	start_timer()


# Function to create and start a timer that will generate chunks every 1 second if applicable
func start_timer():
	var my_timer = Timer.new() # Create a new Timer instance
	my_timer.wait_time = 1 # Timer will tick every 1 second
	my_timer.one_shot = false # False means the timer will repeat
	add_child(my_timer) # Add the Timer to the scene as a child of this node
	my_timer.timeout.connect(_on_Timer_timeout) # Connect the timeout signal
	my_timer.start() # Start the timer


# This will start the chunk loading and unloading if the player has moved and no chunk
# is currently being loaded or unloaded
func _on_Timer_timeout():
	if is_processing_chunk:
		return  # Wait until the current chunk operation is finished

	var player = get_tree().get_first_node_in_group("Players")
	var new_position = Vector2(player.global_transform.origin.x, player.global_transform.origin.z) / Vector2(level_width, level_height)
	if new_position != player_position:
		player_position = new_position
		_chunk_management_logic()
		process_next_chunk()


# We store the level map width and height
# If the map has been previously saved, load the saved chunks into memory
func initialize_map_data():
	map_save_folder = Helper.save_helper.get_saved_map_folder(Helper.current_level_pos)
	var level_name: String = Helper.current_level_name
	var tacticalMapJSON: Dictionary = {}
	if map_save_folder == "":
		# In this case we need to make a new map based on it's json definition
		tacticalMapJSON = Helper.json_helper.load_json_dictionary_file(\
		Gamedata.data.tacticalmaps.dataPath + level_name)
		Helper.loaded_chunk_data.mapheight = tacticalMapJSON.mapheight
		Helper.loaded_chunk_data.mapwidth = tacticalMapJSON.mapwidth
	else:
		# In this case we load the map json from disk
		tacticalMapJSON = Helper.json_helper.load_json_dictionary_file(\
		map_save_folder + "/map.json")
		var loadingchunks: Dictionary = {}

		# Since the chunk positions are no longer a Vector2 in JSON, 
		# we have to transform it back into a Vector2
		var chunk_data = tacticalMapJSON["chunks"]
		for key_str in chunk_data:
			var key_parts = key_str.split(",")
			if key_parts.size() == 2:
				var key_x = int(key_parts[0])
				var key_y = int(key_parts[1])
				var key = Vector2(key_x, key_y) # Use integers for Vector2 to avoid hash collisions
				loadingchunks[key] = chunk_data[key_str]
		Helper.loaded_chunk_data = tacticalMapJSON
		Helper.loaded_chunk_data.chunks = loadingchunks


# Called when no data has been put into memory yet in loaded_chunk_data
# Will get the chunk data from map json definition to create a brand new chunk
func get_chunk_data_at_position(mypos: Vector2) -> Dictionary:
	var tacticalMapJSON = Helper.json_helper.load_json_dictionary_file(\
		Gamedata.data.tacticalmaps.dataPath + Helper.current_level_name)
	var y: int = int(mypos.y)
	var x: int = int(mypos.x)
	var index: int = y * Helper.loaded_chunk_data.mapwidth + x
	if index >= 0 and index < (Helper.loaded_chunk_data.mapwidth*Helper.loaded_chunk_data.mapheight):
		return tacticalMapJSON.chunks[index]
	else:
		print("Position out of bounds or invalid index.")
		return {}


# Return an array of chunks that fall inside the creation radius
# We only return chunks that have it's coordinate in the tacticalmap, so we don't go out of bounds
func calculate_chunks_to_load(player_chunk_pos: Vector2) -> Array:
	var chunks_to_load = []
	for x in range(player_chunk_pos.x - creation_radius, player_chunk_pos.x + creation_radius + 1):
		for y in range(player_chunk_pos.y - creation_radius, player_chunk_pos.y + creation_radius + 1):
			var chunk_pos = Vector2(x, y)
			# Check if chunk_pos is within the map dimensions
			if is_pos_in_map(x,y) and not loaded_chunks.has(chunk_pos):
				chunks_to_load.append(chunk_pos)
	return chunks_to_load


# Returns if the provided position falls within the tacticalmap dimensions
func is_pos_in_map(x, y) -> bool:
	return x >= 0 and x < Helper.loaded_chunk_data.mapwidth and y >= 0 and y < Helper.loaded_chunk_data.mapheight


# Returns chunks that are loaded but outside of the survival radius
func calculate_chunks_to_unload(player_chunk_pos: Vector2) -> Array:
	var chunks_to_unload = []
	for chunk_pos in loaded_chunks.keys():
		if chunk_pos.distance_to(player_chunk_pos) > survival_radius:
			chunks_to_unload.append(chunk_pos)
	return chunks_to_unload


# Loads a chunk into existence. If it has been previously loaded, we get the data from loaded_chunk_data
# If it has not been previously loaded, we get it from the map json definition
func load_chunk(chunk_pos: Vector2):
	var newChunk = Chunk.new()
	newChunk.mypos = Vector3(chunk_pos.x * level_width, 0, chunk_pos.y * level_height)
	newChunk.level_manager = level_manager
	newChunk.level_generator = self
	newChunk.chunk_loaded.connect(_on_chunk_un_loaded)
	newChunk.chunk_unloaded.connect(_on_chunk_un_loaded)
	if Helper.loaded_chunk_data.chunks.has(chunk_pos):
		# If the chunk has been loaded before, we use that data
		newChunk.chunk_data = Helper.loaded_chunk_data.chunks[chunk_pos]
	else:
		# This chunk has not been loaded before, so we need to use the chunk data definition instead
		newChunk.chunk_data = get_chunk_data_at_position(chunk_pos)
	level_manager.add_child.call_deferred(newChunk)
	loaded_chunks[chunk_pos] = newChunk


# When we unload the chunk, we save it's data into memory so we can re-use it later
func unload_chunk(chunk_pos: Vector2):
	if loaded_chunks.has(chunk_pos):
		var chunk = loaded_chunks[chunk_pos]
		chunk.unload_chunk.call_deferred()
		loaded_chunks.erase(chunk_pos)


# This function is called when a chunk is loaded or unloaded
# We set the is_processing_chunk to false so we can start processing another chunk
func _on_chunk_un_loaded():
	is_processing_chunk = false


# Calculates which chunks should be loaded and unloaded
func _chunk_management_logic():
	var current_player_chunk = player_position.floor()
	
	# Calculate potential chunks for load and unload
	var potential_loads = calculate_chunks_to_load(current_player_chunk)
	var potential_unloads = calculate_chunks_to_unload(current_player_chunk)
	
	# Update queues with new chunks ensuring no duplicates across both queues
	update_queues(potential_loads, potential_unloads)


# Update load and unload queues
func update_queues(potential_loads, potential_unloads):
	for chunk_pos in potential_loads:
		if not load_queue.has(chunk_pos) and not unload_queue.has(chunk_pos):
			load_queue.append(chunk_pos)

	for chunk_pos in potential_unloads:
		if not unload_queue.has(chunk_pos) and not load_queue.has(chunk_pos):
			unload_queue.append(chunk_pos)

	# Remove chunks from the unload queue if they are now within the load radius
	for chunk_pos in unload_queue.duplicate():
		if chunk_pos.distance_to(player_position.floor()) <= creation_radius:
			unload_queue.erase(chunk_pos)


# This function will either load or unlaod a chunk if there are any to load or unload
func process_next_chunk():
	if load_queue.size() > 0:
		var chunk_pos = load_queue.pop_front()
		is_processing_chunk = true
		load_chunk(chunk_pos)
	elif unload_queue.size() > 0:
		var chunk_pos = unload_queue.pop_front()
		is_processing_chunk = true
		unload_chunk(chunk_pos)
