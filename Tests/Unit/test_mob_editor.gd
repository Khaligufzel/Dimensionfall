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


func test_editor_loads_attacks():
	# Set up test data with a melee and ranged attack
	test_mob.attacks = {
		"melee": [{"id": "claw_attack", "damage_multiplier": 1.0}],
		"ranged": [{"id": "fireball", "damage_multiplier": 0.8}]
	}

	editor_instance.dmob = test_mob
	await get_tree().process_frame

	# Get children of attack grid container
	var children = editor_instance.attacks_grid_container.get_children()
	assert_eq(children.size(), 6, "Expected two attack entries (each with ID, Label, and SpinBox)")

	# Validate the first attack (melee)
	assert_eq(children[0].text, "claw_attack", "Expected melee attack ID to be loaded")
	assert_eq(children[2].value, 1.0, "Expected melee attack multiplier to be loaded")

	# Validate the second attack (ranged)
	assert_eq(children[3].text, "fireball", "Expected ranged attack ID to be loaded")
	assert_eq(children[5].value, 0.8, "Expected ranged attack multiplier to be loaded")


func test_editor_saves_attacks():
	# Simulate attacks being added in the UI
	editor_instance._add_attack_to_grid({"id": "claw_attack", "damage_multiplier": 1.0, "type": "melee"})
	editor_instance._add_attack_to_grid({"id": "fireball", "damage_multiplier": 0.8, "type": "ranged"})

	editor_instance._on_save_button_button_up()

	# Validate that test_mob now contains the updated attacks
	assert_eq(test_mob.attacks["melee"].size(), 1, "Expected one melee attack")
	assert_eq(test_mob.attacks["ranged"].size(), 1, "Expected one ranged attack")

	assert_eq(test_mob.attacks["melee"][0]["id"], "claw_attack", "Expected melee attack ID to be saved")
	assert_eq(test_mob.attacks["melee"][0]["damage_multiplier"], 1.0, "Expected melee attack multiplier to be saved")

	assert_eq(test_mob.attacks["ranged"][0]["id"], "fireball", "Expected ranged attack ID to be saved")
	assert_eq(test_mob.attacks["ranged"][0]["damage_multiplier"], 0.8, "Expected ranged attack multiplier to be saved")


func test_editor_toggles_dash_ability():
	# Initially, dash should be disabled
	assert_eq(editor_instance.dash_check_box.button_pressed, false, "Dash should be disabled by default")

	# Enable dash and set values
	editor_instance.dash_check_box.button_pressed = true
	editor_instance.dash_speed_multiplier_spin_box.value = 3.0
	editor_instance.dash_duration_spin_box.value = 1.0
	editor_instance.dash_cooldown_spin_box.value = 5

	editor_instance._on_save_button_button_up()

	# Validate that test_mob.special_moves now contains dash data
	assert_eq(test_mob.special_moves.has("dash"), true, "Expected dash ability to be saved")
	assert_eq(test_mob.special_moves["dash"]["speed_multiplier"], 3.0, "Expected correct dash speed multiplier")
	assert_eq(test_mob.special_moves["dash"]["duration"], 1.0, "Expected correct dash duration")
	assert_eq(test_mob.special_moves["dash"]["cooldown"], 5, "Expected correct dash cooldown")


func test_editor_saves_mob_attributes():
	# Modify attributes in UI
	editor_instance.health_numedit.value = 150
	editor_instance.moveSpeed_numedit.value = 3.5
	editor_instance.sightRange_numedit.value = 25.0

	editor_instance._on_save_button_button_up()

	# Validate saved values
	assert_eq(test_mob.health, 150, "Expected health to be saved")
	assert_eq(test_mob.move_speed, 3.5, "Expected move speed to be saved")
	assert_eq(test_mob.sight_range, 25.0, "Expected sight range to be saved")


func test_editor_preserves_attack_metadata():
	# Simulate attack added to UI
	editor_instance._add_attack_to_grid({"id": "claw_attack", "damage_multiplier": 1.5, "type": "melee"})
	editor_instance._on_save_button_button_up()

	# Check that at least one melee attack exists
	assert_gt(test_mob.attacks["melee"].size(), 0, "Expected at least one melee attack to be saved")
