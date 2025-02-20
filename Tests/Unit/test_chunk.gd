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
	if test_chunk:
		test_chunk.queue_free()
	if mock_level_manager:
		mock_level_manager.queue_free()
	if mock_level_generator:
		mock_level_generator.queue_free()

# Runs after all tests.
func after_all():
	Runtimedata.reset()

# Test if the chunk initializes and spawns correctly.
func test_chunk_initialization():
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
