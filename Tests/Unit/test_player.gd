extends GutTest
var scene_selector 
var player


#Basic unit test for player
func before_all():
	#load data required for scene, scene may need to be refactored to avoid this
	Runtimedata.reconstruct() # Load all mod data in the proper way
	var rng = RandomNumberGenerator.new()
	Helper.mapseed = rng.randi()
	Helper.save_helper.create_new_save()
	Helper.signal_broker.game_started.emit()
	scene_selector = preload("res://level_generation.tscn").instantiate()
	get_tree().root.add_child(scene_selector)
	await get_tree().process_frame 
	
	
#Function tests for the presence of a player
func test_player_is_there()->void:
	player = get_tree().get_nodes_in_group("Players") 
	assert_eq(player.size(),1,"too many or not enough players")
	
	
#Function tests is player is alive when spawned	and sets player to the first player array memeber
func test_living()-> void:
	player = player[0] #now that we know players are here set players to the only player
	assert_true(player.is_alive,"Opps player spawned dead")

#Function tests player stamina 	
func test_initial_stm() -> void:
	assert_eq(player.current_stamina, player.max_stamina, "Stamina is loading incorrectly!")

func test_knockback()->void:
	assert_false(player.knockback_active,"Player spawned with knockback error")#
	


	
