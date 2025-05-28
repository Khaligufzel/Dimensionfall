extends GutTest

# This script is used to test the player

var scene_selector 
var players: Array # Variable for all existing players, just one for now
var player: Player
var test_chunk: Chunk
var mock_level_manager: Node3D
var mock_level_generator: Node3D


#Basic unit test for player
func before_all():
	var custom_mods: Array[DMod] = [Gamedata.mods.by_id("Core"), Gamedata.mods.by_id("Test")]
	Runtimedata.reconstruct(custom_mods)
	await get_tree().process_frame


# Runs before each test.
func before_each():
	const PLAYER = preload("res://Scenes/player.tscn")
	test_chunk = Chunk.new()
	mock_level_manager = Node3D.new()
	mock_level_generator = Node3D.new()
	player = PLAYER.instantiate()
	player.testing = true

	test_chunk.level_manager = mock_level_manager
	test_chunk.level_generator = mock_level_generator
	add_child(mock_level_manager)
	add_child(mock_level_generator)
	add_child(player)
	# We expect the player to start here, just like in level_generation.tscn
	player.global_position = Vector3(0, 1.5, 15)

	test_chunk.mypos = Vector3(0, 0, 0) # Example position (chunk (1, 2) with 32x32 blocks)


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

	var mobs: Array = get_tree().get_nodes_in_group("mobs") 
	assert_eq(mobs.size(),0,"too many mobs")
	
	if test_chunk and is_instance_valid(test_chunk):
		test_chunk.queue_free()
	if mock_level_manager:
		mock_level_manager.queue_free()
	if mock_level_generator:
		mock_level_generator.queue_free()
	if player:
		player.queue_free()
	await get_tree().process_frame


#Function tests for the presence of a player
func test_player_basics()->void:
	test_chunk.chunk_data = {"id": "basic_test_map","rotation": 0}
	add_child(test_chunk)
	await get_tree().process_frame
	# Test if chunk state is set correctly
	assert_eq(test_chunk.load_state, Chunk.LoadStates.LOADING, "Chunk did not start in LOADING state.")
	# Wait for `chunk_generated` signal before verifying post-generation state
	assert_true(await wait_for_signal(test_chunk.chunk_generated, 5), "Chunk should have emitted chunk_generated signal.")
	
	# Start testing the player basics
	players = get_tree().get_nodes_in_group("Players") 
	assert_eq(players.size(),1,"too many or not enough players")
	
	assert_true(player.is_alive,"Oops player spawned dead")
	assert_eq(player.current_stamina, player.max_stamina, "Stamina is loading incorrectly!")
	assert_eq(player.global_position, Vector3(0, 1.5, 15), "Player spawned in the wrong location!")
	assert_false(player.knockback_active,"Player spawned with knockback error")


# Test knockback mechanics
func test_knockback():
	test_chunk.chunk_data = {"id": "basic_test_map","rotation": 0}
	add_child(test_chunk)
	await get_tree().process_frame
	# Test if chunk state is set correctly
	assert_eq(test_chunk.load_state, Chunk.LoadStates.LOADING, "Chunk did not start in LOADING state.")
	# Wait for `chunk_generated` signal before verifying post-generation state
	assert_true(await wait_for_signal(test_chunk.chunk_generated, 5), "Chunk should have emitted chunk_generated signal.")
	
	var player_can_move = func():
		return player.time_since_ready > player.delay_before_movement
	assert_true(await wait_until(player_can_move, 3, 1),"Player should be able to move in 3 seconds")

	var initial_position = player.global_position
	player._perform_knockback(5.0, initial_position + Vector3(-1, 0, 0))
	assert_true(player.knockback_active, "Knockback should be active after calling _perform_knockback.")
	await wait_frames(10)
	assert_true(player.global_position != initial_position, "Player should have moved due to knockback.")


# Test stun effect
func test_stun_effect():
	test_chunk.chunk_data = {"id": "basic_test_map","rotation": 0}
	add_child(test_chunk)
	await get_tree().process_frame
	# Test if chunk state is set correctly
	assert_eq(test_chunk.load_state, Chunk.LoadStates.LOADING, "Chunk did not start in LOADING state.")
	# Wait for `chunk_generated` signal before verifying post-generation state
	assert_true(await wait_for_signal(test_chunk.chunk_generated, 5), "Chunk should have emitted chunk_generated signal.")
	
	player.delay_before_movement = 0 # Make sure the player is processing in time
	player.add_stun(5.0)
	assert_true(player.is_stunned(), "Player should be stunned after receiving stun.")
	
	await wait_frames(60)  # Allow stun to wear off
	assert_false(player.is_stunned(), "Player should recover from stun over time.")


# Test skill progression
func test_skill_progression():
	test_chunk.chunk_data = {"id": "basic_test_map","rotation": 0}
	add_child(test_chunk)
	await get_tree().process_frame
	# Test if chunk state is set correctly
	assert_eq(test_chunk.load_state, Chunk.LoadStates.LOADING, "Chunk did not start in LOADING state.")
	# Wait for `chunk_generated` signal before verifying post-generation state
	assert_true(await wait_for_signal(test_chunk.chunk_generated, 5), "Chunk should have emitted chunk_generated signal.")
	
	var initial_level = player.get_skill_level("athletics")
	player.add_skill_xp("athletics", 200)  # Should level up twice
	
	assert_true(player.get_skill_level("athletics") > initial_level, "Skill level should increase after gaining XP.")


# Test player state saving and loading
func test_player_state_save_load():
	test_chunk.chunk_data = {"id": "basic_test_map","rotation": 0}
	add_child(test_chunk)
	await get_tree().process_frame
	# Test if chunk state is set correctly
	assert_eq(test_chunk.load_state, Chunk.LoadStates.LOADING, "Chunk did not start in LOADING state.")
	# Wait for `chunk_generated` signal before verifying post-generation state
	assert_true(await wait_for_signal(test_chunk.chunk_generated, 5), "Chunk should have emitted chunk_generated signal.")
	
	player.current_stamina = 50
	player.current_nutrition = 70
	var saved_state = player.get_state()
	
	# Reset and reload state
	player.set_state({"stamina": 100, "nutrition": 30})
	assert_eq(player.current_stamina, 100, "Stamina should be set to 100.")
	assert_eq(player.current_nutrition, 30, "Nutrition should be set to 30.")

	# Restore saved state
	player.set_state(saved_state)
	assert_eq(player.current_stamina, 50, "Stamina should be restored from save state.")
	assert_eq(player.current_nutrition, 70, "Nutrition should be restored from save state.")


# Test player state saving and loading
func test_player_vs_melee_mob():
	# Target manager is required for the mob to start targeting
	const TargetManager = preload("res://Scripts/target_manager.gd")
	var mock_target_manager = TargetManager.new()
	mock_target_manager.name = "TargetManager"
	add_child(mock_target_manager)
	
	test_chunk.chunk_data = {"id": "basic_mob_test_map","rotation": 0}
	add_child(test_chunk)
	await get_tree().process_frame
	# Test if chunk state is set correctly
	assert_eq(test_chunk.load_state, Chunk.LoadStates.LOADING, "Chunk did not start in LOADING state.")
	# Wait for `chunk_generated` signal before verifying post-generation state
	assert_true(await wait_for_signal(test_chunk.chunk_generated, 5), "Chunk should have emitted chunk_generated signal.")
	
	# Start testing the player basics
	players = get_tree().get_nodes_in_group("Players") 
	assert_eq(players.size(),1,"too many or not enough players")
	player.global_position = Vector3(13,1.5,15)
	
	var mobs: Array = get_tree().get_nodes_in_group("mobs") 
	assert_eq(mobs.size(),1,"too many or not enough mobs")
	var first_mob: Mob = mobs[0]
	assert_eq(first_mob.rmob.id,"generic_test_mob","A different mob spawned then expected")
	assert_eq(first_mob.mobPosition,Vector3(15.5,2.0,15.5),"Mob spawned somewhere else")
	
	# Test that the mob transitions into the mob attack state
	var first_state: State = first_mob.get_current_state()
	assert_not_null(first_state, "Mob has no state")
	assert_is(first_state,MobFollow,"Mob should have MobFollow state")

	# Check that the mob has the required attack and that the player has the relevant attribute
	var mobattack: Dictionary = first_mob.get_attack_of_type("melee")
	assert_eq(mobattack.id,"generic_melee_attack","Mob doesn't have the required attack")
	var playerattribute: PlayerAttribute = player.attributes.get("generic_test_attribute", null)
	assert_not_null(playerattribute, "Player lacks the required attribute")
	assert_true(playerattribute.default_mode.is_at_max(), "Player should have max of attribute")
	
	# Wait for the mob to change to MobAttack
	assert_true(await wait_for_signal(first_state.Transistioned, 5), "Mob doesn't transition")
	first_state = first_mob.get_current_state()
	var mob_has_transitioned = func():
		return first_state is MobAttack
	assert_true(await wait_until(mob_has_transitioned, 10, 1),"Mob should have transitioned")
	
	var player_has_taken_damage = func():
		return not playerattribute.default_mode.is_at_max()
	assert_true(await wait_until(player_has_taken_damage, 10, 1),"Player should have taken damage")
	
	# Kill first_mob. Alternatively, wait for one to kill the other but that will take time
	first_mob.get_hit({"attack": {"id": "generic_melee_attack", "damage_multiplier": 100, "type": "melee"},"hit_chance":100})
	
	await get_tree().process_frame
	Helper.player = null
