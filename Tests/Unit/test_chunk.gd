extends GutTest

var test_chunk: Chunk
var mock_level_manager: Node3D
var mock_level_generator: Node3D

# Runs before all tests.
func before_all():
	var custom_mods: Array[DMod] = [Gamedata.mods.by_id("Core"), Gamedata.mods.by_id("Test")]
	Runtimedata.reconstruct(custom_mods)
	await get_tree().process_frame

# Runs before each test.
func before_each():
	test_chunk = Chunk.new()
	mock_level_manager = Node3D.new()
	mock_level_generator = Node3D.new()

	test_chunk.level_manager = mock_level_manager
	test_chunk.level_generator = mock_level_generator

	test_chunk.mypos = Vector3(32, 0, 64) # Example position (chunk (1, 2) with 32x32 blocks)
	test_chunk.chunk_data = {
		"id": "basic_test_map",
		"rotation": 0
	}

	add_child(mock_level_manager)
	add_child(mock_level_generator)
	add_child(test_chunk)

	await get_tree().process_frame

# Runs after each test.
func after_each():
	if test_chunk and is_instance_valid(test_chunk):
		test_chunk.queue_free()
	if mock_level_manager:
		mock_level_manager.queue_free()
	if mock_level_generator:
		mock_level_generator.queue_free()

# Runs after all tests.
func after_all():
	Runtimedata.reset()

# Test if the chunk initializes and spawns correctly.
func test_chunk_load_unload():
	# Test that the chunk is part of the 'chunks' group
	assert_true(test_chunk.is_in_group("chunks"), "Chunk is not added to 'chunks' group.")

	# Test if chunk state is set correctly
	assert_eq(test_chunk.load_state, Chunk.LoadStates.LOADING, "Chunk did not start in LOADING state.")

	# Wait for `chunk_generated` signal before verifying post-generation state
	assert_true(await wait_for_signal(test_chunk.chunk_generated, 5), "Chunk should have emitted chunk_generated signal.")

	# Verify the state reset after generation
	assert_eq(test_chunk.load_state, Chunk.LoadStates.NEITHER, "Chunk should have reset to NEITHER state after generation.")
	
	assert_eq(test_chunk.mypos, Vector3(32, 0, 64), "Chunk position is not set correctly.")
	assert_eq(test_chunk.level_manager, mock_level_manager, "Level manager is not set correctly.")
	assert_eq(test_chunk.level_generator, mock_level_generator, "Level generator is not set correctly.")
	assert_has(test_chunk.chunk_data, "id", "Chunk data does not contain 'id' key.")
	assert_eq(test_chunk.chunk_data["id"], "basic_test_map", "Chunk data ID is not correct.")
	
	# Validate specific blocks on level 0 (which is ground floor)
	var level_index = 0

	# Check (0, 0) -> "dot_tile", rotation 0 --> top-left block
	var block_00 = test_chunk.get_block_at(level_index, Vector2i(0, 0))
	assert_eq(block_00.get("id", ""), "dot_tile", "Block at (0, 0) is not 'dot_tile'.")
	assert_eq(block_00.get("rotation", 0.0), 0.0, "Block at (0, 0) does not have rotation 0.")

	# Check (0, 31) -> "dot_tile", rotation 270 --> bottom-left block
	var block_031 = test_chunk.get_block_at(level_index, Vector2i(0, 31))
	assert_eq(block_031.get("id", ""), "dot_tile", "Block at (0, 31) is not 'dot_tile'.")
	assert_eq(block_031.get("rotation", 0.0), 270.0, "Block at (0, 31) does not have rotation 270.")

	# Check (31, 0) -> "dot_tile", rotation 90 --> top-right block
	var block_310 = test_chunk.get_block_at(level_index, Vector2i(31, 0))
	assert_eq(block_310.get("id", ""), "dot_tile", "Block at (31, 0) is not 'dot_tile'.")
	assert_eq(block_310.get("rotation", 0.0), 90.0, "Block at (31, 0) does not have rotation 90.")

	# Check (31, 31) -> "dot_tile", rotation 180 --> bottom-right block
	var block_3131 = test_chunk.get_block_at(level_index, Vector2i(31, 31))
	assert_eq(block_3131.get("id", ""), "dot_tile", "Block at (31, 31) is not 'dot_tile'.")
	assert_eq(block_3131.get("rotation", 0.0), 180.0, "Block at (31, 31) does not have rotation 180.")


	# Call `unload_chunk` and wait for the chunk to be null
	# Awaiting the `chunk_unloaded` signal will produce an error in GUT somehow, so don't do that
	test_chunk.unload_chunk()
	# Verify that the load state is `UNLOADING`)
	assert_eq(test_chunk.load_state, Chunk.LoadStates.UNLOADING, "Chunk load_state should be UNLOADING.")
	var chunk_is_unloaded = func():
		return test_chunk == null
	# Calls chunk_is_unloaded every second until it returns true and asserts on the returned value
	assert_true(await wait_until(chunk_is_unloaded, 10, 1),"Chunk should be unloaded in 10 seconds")
