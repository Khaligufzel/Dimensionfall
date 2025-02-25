extends GutTest

var mob_editor_scene: PackedScene = preload("res://Scenes/ContentManager/Custom_Editors/MobEditor.tscn")
var editor_instance: Control = null
var test_mob: DMob = null

func before_all():
	var custom_mods: Array[DMod] = [Gamedata.mods.by_id("Core"), Gamedata.mods.by_id("Test")]
	Runtimedata.reconstruct(custom_mods)
	await get_tree().process_frame 

func before_each():
	# Set up a test DMob instance with sample data
	test_mob = DMob.new({
		"id": "test_mob",
		"name": "Test Mob",
		"health": 100,
		"faction_id": "default"
	}, Gamedata.mods.by_id("Test").mobs)

	editor_instance = mob_editor_scene.instantiate()
	get_tree().root.add_child(editor_instance)
	await get_tree().process_frame

	editor_instance.dmob = test_mob

func after_each():
	if editor_instance:
		editor_instance.queue_free()

func after_all():
	Runtimedata.reset()


# ----------- TESTS -----------

func test_editor_loads_mob_data():
	assert_eq(editor_instance.NameTextEdit.text, "Test Mob", "Expected mob name to be loaded")
	assert_eq(editor_instance.health_numedit.value, 100.0, "Expected health to be loaded")



func test_faction_selection():
	# Assuming the faction_option_button is populated from the mod's factions
	editor_instance.faction_option_button.select(0)
	var selected_faction = editor_instance.faction_option_button.get_item_text(0)

	editor_instance._on_save_button_button_up()

	assert_eq(test_mob.faction_id, selected_faction, "Expected faction_id to match selected faction in option button")
