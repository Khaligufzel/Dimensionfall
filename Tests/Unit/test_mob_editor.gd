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
		"melee_range": 2.0,
		"melee_cooldown": 1.5,
		"melee_knockback": 3.0,
		"ranged_range": 15.0,
		"ranged_cooldown": 2.5,
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

	# Melee values
	assert_eq(editor_instance.melee_range_numedit.value, 2.0, "Expected melee_range to load")
	assert_eq(editor_instance.melee_cooldown_spinbox.value, 1.5, "Expected melee_cooldown to load")
	assert_eq(editor_instance.melee_knockback_spinbox.value, 3.0, "Expected melee_knockback to load")

	# Ranged values
	assert_eq(editor_instance.ranged_range_spin_box.value, 15.0, "Expected ranged_range to load")
	assert_eq(editor_instance.ranged_cooldown_spin_box.value, 2.5, "Expected ranged_cooldown to load")

	# Attack type selection should be "Ranged" because ranged_range > 0
	assert_eq(editor_instance.attack_type_option_button.get_item_text(editor_instance.attack_type_option_button.selected), "Ranged")

	# Check visibility
	assert_true(editor_instance.ranged_h_box_container.visible, "Expected ranged container to be visible")
	assert_false(editor_instance.melee_h_box_container.visible, "Expected melee container to be hidden")


func test_attack_type_switching():
	# Switch to Melee
	editor_instance.attack_type_option_button.select(0)
	editor_instance._on_attack_type_option_button_item_selected(0)

	assert_true(editor_instance.melee_h_box_container.visible, "Expected melee container to be visible after switching to Melee")
	assert_false(editor_instance.ranged_h_box_container.visible, "Expected ranged container to be hidden after switching to Melee")

	# Switch to Ranged
	editor_instance.attack_type_option_button.select(1)
	editor_instance._on_attack_type_option_button_item_selected(1)

	assert_true(editor_instance.ranged_h_box_container.visible, "Expected ranged container to be visible after switching to Ranged")
	assert_false(editor_instance.melee_h_box_container.visible, "Expected melee container to be hidden after switching to Ranged")


func test_saving_melee_data():
	editor_instance.attack_type_option_button.select(0)
	editor_instance._on_attack_type_option_button_item_selected(0)

	editor_instance.melee_range_numedit.value = 3.5
	editor_instance.melee_cooldown_spinbox.value = 2.0
	editor_instance.melee_knockback_spinbox.value = 1.0

	editor_instance._on_save_button_button_up()

	assert_eq(test_mob.melee_range, 3.5, "Expected melee_range to be saved")
	assert_eq(test_mob.melee_cooldown, 2.0, "Expected melee_cooldown to be saved")
	assert_eq(test_mob.melee_knockback, 1.0, "Expected melee_knockback to be saved")

	assert_eq(test_mob.ranged_range, -1.0, "Expected ranged_range to be -1 when saving Melee")
	assert_eq(test_mob.ranged_cooldown, -1.0, "Expected ranged_cooldown to be -1 when saving Melee")


func test_saving_ranged_data():
	editor_instance.attack_type_option_button.select(1)
	editor_instance._on_attack_type_option_button_item_selected(1)

	editor_instance.ranged_range_spin_box.value = 20.0
	editor_instance.ranged_cooldown_spin_box.value = 1.1

	editor_instance._on_save_button_button_up()

	assert_eq(test_mob.ranged_range, 20.0, "Expected ranged_range to be saved")
	print_debug("Actual ranged_cooldown:", test_mob.ranged_cooldown)
	var is_equal_to: bool = test_mob.ranged_cooldown == 1.1
	print_debug("Actual is_equal_to:", str(is_equal_to))
	assert_eq(test_mob.ranged_cooldown, 1.1, "Expected ranged_cooldown to be saved")

	assert_eq(test_mob.melee_range, -1.0, "Expected melee_range to be -1 when saving Ranged")
	assert_eq(test_mob.melee_cooldown, -1.0, "Expected melee_cooldown to be -1 when saving Ranged")
	assert_eq(test_mob.melee_knockback, -1.0, "Expected melee_knockback to be -1 when saving Ranged")


func test_faction_selection():
	# Assuming the faction_option_button is populated from the mod's factions
	editor_instance.faction_option_button.select(0)
	var selected_faction = editor_instance.faction_option_button.get_item_text(0)

	editor_instance._on_save_button_button_up()

	assert_eq(test_mob.faction_id, selected_faction, "Expected faction_id to match selected faction in option button")
