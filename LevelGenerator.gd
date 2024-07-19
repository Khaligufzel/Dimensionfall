extends Node3D

var map_save_folder: String

# The amount of blocks that make up a level
var level_width : int = 32
var level_height : int = 32

@export var level_manager : Node3D
@export_file var default_level_json


# Parameters for dynamic chunk loading
var creation_radius = 2
var survival_radius = 3
var loaded_chunks = {} # Dictionary to store loaded chunks with their positions as keys
var player_position = Vector2.ZERO # Player's position, updated regularly
# Chunks are loaded and unloaded one at a time. The load_queue will be processed before the unload_queue
# Chunks that should be loaded and unloaded are stored inside these variables
var load_queue = []
var unload_queue = []
# Enforces loading or unloading one chunk at a time
var is_processing_chunk = false

signal all_chunks_unloaded

# Called when the node enters the scene tree for the first time.
func _ready():
	Helper.map_manager.level_generator = self # Register with the map manager
	# Connect to the Helper.signal_broker.game_started signal
	Helper.signal_broker.game_started.connect(_on_game_started)
	Helper.signal_broker.game_ended.connect(_on_game_ended)
	Helper.signal_broker.player_spawned.connect(_on_player_spawned)


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


# Function for handling game started signal
func _on_game_started():
	# To be developed later
	pass

# Function for handling player spawned signal
func _on_player_spawned(playernode):
	initialize_map_data()
	
	load_queue.append(Vector2(0,0))
	# Start a loop to update chunks based on player position
	start_timer()

# Function for handling game ended signal
func _on_game_ended():
	pass

# Updated function to get chunk data at a given position
func get_chunk_data_at_position(mypos: Vector2) -> Dictionary:
	var map_cell = Helper.overmap_manager.get_map_cell_by_local_coordinate(mypos)
	var json_file_path: String = map_cell.map_id
	return {"id":json_file_path, "rotation":0}


# We store the level map width and height
# If the map has been previously saved, load the saved chunks into memory
func initialize_map_data():
	# In this case we load the map json from disk
	Helper.overmap_manager.update_player_position_and_manage_segments(true)


# Return an array of chunks that fall inside the creation radius
# We only return chunks that have it's coordinate in the tacticalmap, so we don't go out of bounds
func calculate_chunks_to_load(player_chunk_pos: Vector2) -> Array:
	var chunks_to_load = []
	for x in range(player_chunk_pos.x - creation_radius, player_chunk_pos.x + creation_radius + 1):
		for y in range(player_chunk_pos.y - creation_radius, player_chunk_pos.y + creation_radius + 1):
			var chunk_pos = Vector2(x, y)
			# Check if chunk_pos is within the map dimensions
			if not loaded_chunks.has(chunk_pos):
				chunks_to_load.append(chunk_pos)
	return chunks_to_load


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
	var new_chunk = Chunk.new()
	new_chunk.mypos = Vector3(chunk_pos.x * level_width, 0, chunk_pos.y * level_height)
	new_chunk.level_manager = level_manager
	new_chunk.level_generator = self
	new_chunk.chunk_ready.connect(_on_chunk_un_loaded)
	new_chunk.chunk_unloaded.connect(_on_chunk_un_loaded)
	if Helper.overmap_manager.loaded_chunk_data.chunks.has(chunk_pos):
		# If the chunk has been loaded before, we use that data
		new_chunk.chunk_data = Helper.overmap_manager.loaded_chunk_data.chunks[chunk_pos]
	else:
		# This chunk has not been loaded before, so we need to use the chunk data definition instead
		new_chunk.chunk_data = get_chunk_data_at_position(chunk_pos)
	level_manager.add_child.call_deferred(new_chunk)
	loaded_chunks[chunk_pos] = new_chunk


# When we unload the chunk, we save its data into memory so we can re-use it later
func unload_chunk(chunk_pos: Vector2):
	#print_debug("Unloading chunk at chunk_pos (" + str(chunk_pos) + ")")
	if loaded_chunks.has(chunk_pos):
		#print_debug("found chunk at chunk_pos (" + str(chunk_pos) + ")")
		var chunk = loaded_chunks[chunk_pos]
		chunk.unload_chunk()
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


# This function will either load or unload a chunk if there are any to load or unload
func process_next_chunk():
	if load_queue.size() > 0:
		var chunk_pos = load_queue.pop_front()
		is_processing_chunk = true
		load_chunk(chunk_pos)
	elif unload_queue.size() > 0:
		var chunk_pos = unload_queue.pop_front()
		is_processing_chunk = true
		unload_chunk(chunk_pos)


# Returns the chunk instance at the given position
# chunk_pos starts at 0,0 and increases like 0,1, 0,2 ... 4,4, 4,5 etc.
func get_chunk(chunk_pos: Vector2) -> Chunk:
	if loaded_chunks.has(chunk_pos):
		var chunk = loaded_chunks[chunk_pos]
		if is_instance_valid(chunk):
			return chunk
		else:
			return null
	else:
		# Handle the case where the chunk is not found.
		print_debug("Chunk at position ", chunk_pos, " not found.")
		return null


# Returns the chunk instance at the given position
# chunk_pos starts at 0,0 and increases like 0,32, 0,64 ... 96,0, 96,32 etc.
func get_global_chunk(chunk_pos: Vector2) -> Chunk:
	# Convert global position to chunk index
	var chunk_index = chunk_pos / Vector2(level_width, level_height)
	chunk_index = chunk_index.floor()  # Ensure index is an integer vector
	return get_chunk(chunk_index)


# Returns which chunk the position is in right now
# position_in_3d_space can be any position, like 12,2,6 or 139,-6,14
func get_chunk_from_position(position_in_3d_space: Vector3) -> Chunk:
	var chunk_x = floor(position_in_3d_space.x / 32) * 32
	var chunk_z = floor(position_in_3d_space.z / 32) * 32
	return get_global_chunk(Vector2(chunk_x, chunk_z))


# Function to get chunk_pos from mypos
func get_chunk_pos_from_mypos(mypos: Vector3) -> Vector2:
	print_debug("Unloading chunk at mypos (" + str(mypos) + ")")
	var chunk_x = mypos.x / level_width
	var chunk_y = mypos.z / level_height
	return Vector2(chunk_x, chunk_y)


# Function to stop the generation of new chunks and unload existing chunks
func unload_all_chunks():
	# Clear load queue to stop generating new chunks
	load_queue.clear()
	is_processing_chunk = true # make sure no new chunks get added to the load queue

	# Start unloading chunks
	handle_chunk_unload()


# Function to handle chunk unloading
func handle_chunk_unload():
		var all_unloaded = true
		# Get all chunks in the group "chunks"
		var chunks = get_tree().get_nodes_in_group("chunks")
		for chunk in chunks:
			if is_instance_valid(chunk): # some might be queue_freed at this point
				match chunk.load_state:
					chunk.LoadStates.NEITHER:
						unload_chunk(get_chunk_pos_from_mypos(chunk.mypos))
						all_unloaded = false  # Wait for state to change
					chunk.LoadStates.LOADING:
						all_unloaded = false  # Wait for state to change
					chunk.LoadStates.UNLOADING:
						all_unloaded = false  # Wait for chunk to unload
		if all_unloaded:
			is_processing_chunk = false
			all_chunks_unloaded.emit()
		else:
			await get_tree().create_timer(0.5).timeout # Wait for a bit before checking again
			handle_chunk_unload()
