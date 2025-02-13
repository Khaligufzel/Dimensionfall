extends GutTest
var scene_selector 
var player


#function to get player from scene
func before_all():
	Runtimedata.reconstruct() # Load all mod data in the proper way
	var rng = RandomNumberGenerator.new()
	Helper.mapseed = rng.randi()
	Helper.save_helper.create_new_save()
	Helper.signal_broker.game_started.emit()
	scene_selector = preload("res://level_generation.tscn").instantiate()
	get_tree().root.add_child(scene_selector)
	await get_tree().process_frame 
	#scene_selector = preload("res://scene_selector.tscn").instantiate()
	#get_tree().root.add_child(scene_selector)
	#await get_tree().process_frame 
	#
	#
	#
	#var playbut= scene_selector.get_node("PlayDemo") as Button
	#playbut.emit_signal("pressed")
	
#test this function on the player	
func test_initial_stm() -> void:
	#scene_selector._on_play_demo_pressed()
	gut.p(get_tree().get_current_scene().name)
	player = get_tree().get_nodes_in_group("Players") 
	gut.p(player)
	if player.size() > 0:
		var player = player[0]
		assert_eq(player.current_stamina, player.max_stamina, "Stamina is loading incorrectly!")
	else:
		gut.p("No player was found")


	
