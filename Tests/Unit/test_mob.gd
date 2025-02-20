extends GutTest

# This script is used to test the Mob.
# The mob can't really exist outside a chunk, so we need to spawn a chunk too
# This will help the mob to navigate around.
# If some specific situations are needed for the mob, create a new map to set it up.

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
		"id": "basic_mob_test_map",
		"rotation": 0
	}

	add_child(mock_level_manager)
	add_child(mock_level_generator)
	add_child(test_chunk)

	await get_tree().process_frame

# Runs after each test.
func after_each():
	# Call `unload_chunk` and wait for the chunk to be null
	# Awaiting the `chunk_unloaded` signal will produce an error in GUT somehow, so don't do that
	test_chunk.unload_chunk()
	# Verify that the load state is `UNLOADING`)
	assert_eq(test_chunk.load_state, Chunk.LoadStates.UNLOADING, "Chunk load_state should be UNLOADING.")
	var chunk_is_unloaded = func():
		return test_chunk == null
	# Calls chunk_is_unloaded every second until it returns true and asserts on the returned value
	assert_true(await wait_until(chunk_is_unloaded, 10, 1),"Chunk should be unloaded in 10 seconds")

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
func test_mob_spawn():
	# Test if chunk state is set correctly
	assert_eq(test_chunk.load_state, Chunk.LoadStates.LOADING, "Chunk did not start in LOADING state.")

	# Wait for `chunk_generated` signal before verifying post-generation state
	assert_true(await wait_for_signal(test_chunk.chunk_generated, 5), "Chunk should have emitted chunk_generated signal.")

	# Verify the state reset after generation
	assert_eq(test_chunk.load_state, Chunk.LoadStates.NEITHER, "Chunk should have reset to NEITHER state after generation.")
	
	assert_eq(test_chunk.mypos, Vector3(32, 0, 64), "Chunk position is not set correctly.")
	assert_eq(test_chunk.chunk_data["id"], "basic_mob_test_map", "Chunk data ID is not correct.")
	
	var mobs: Array = get_tree().get_nodes_in_group("mobs") 
	assert_eq(mobs.size(),1,"too many or not enough mobs")
	var first_mob: Mob = mobs[0]
	assert_eq(first_mob.rmob.id,"generic_test_mob","A different mob spawned then expected")
	assert_eq(first_mob.mobPosition,Vector3(47,1.5,79),"Mob spawned somewhere else")
	
	# Test that the mob is in idle state, since there is no target
	var current_state: State = first_mob.state_machine.current_state
	assert_is(current_state,MobIdle,"A different state then expected")
	# Check that the mob has a NavigationAgent3D
	assert_not_null(first_mob.nav_agent, "Mob's NavigationAgent3D is null.")
	assert_true(first_mob.nav_agent is NavigationAgent3D, "Mob's nav_agent is not a NavigationAgent3D.")

	# Check that the MobIdle state has an associated Timer and it is running
	var mob_idle: MobIdle = current_state as MobIdle
	assert_not_null(mob_idle.moving_timer, "MobIdle moving_timer is null.")
	assert_true(mob_idle.moving_timer.is_inside_tree(), "MobIdle moving_timer is not added to the tree.")
	assert_true(mob_idle.moving_timer.is_stopped() == false, "MobIdle moving_timer is not running after entering the state.")

	# Validate that the idle speed is set correctly from the mob
	assert_eq(mob_idle.idle_speed, first_mob.idle_move_speed, "MobIdle idle_speed is not set correctly.")

	# Simulate the timer timeout and check if it attempts to move
	mob_idle._on_moving_cooldown_timeout()
	await get_tree().process_frame

	# Verify that target_location is set and is_looking_to_move is true (assuming raycast is clear in your test setup)
	assert_true(mob_idle.is_looking_to_move, "MobIdle did not start moving after cooldown timeout.")
	assert_not_null(mob_idle.target_location, "MobIdle target_location is not set after cooldown timeout.")
	assert_true(mob_idle.target_location != Vector3.ZERO, "MobIdle target_location is still Vector3.ZERO after cooldown timeout.")

	# Mock pathfinding and simulate movement handling
	mob_idle.makepath()
	await get_tree().process_frame

	mob_idle.handle_mob_movement()
	await get_tree().process_frame

	# Verify that velocity is being set when moving
	assert_true(first_mob.velocity.length() > 0.0, "Mob is not moving during idle movement.")
	
	var initial_position = first_mob.last_position
	var mob_has_moved = func():
		return initial_position.distance_to(first_mob.last_position) > 0.01
	assert_true(await wait_until(mob_has_moved, 10, 1),"Mob should have moved in 10 seconds")
