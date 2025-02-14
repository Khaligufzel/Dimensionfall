extends GutTest

var test_container: ContainerItem
	
# Runs before each test.
func before_all():
	var custom_mods = [Gamedata.mods.by_id("Core"), Gamedata.mods.by_id("SomeOtherMod")]
	Runtimedata.reconstruct(custom_mods)
	await get_tree().process_frame 

func before_each():
	test_container = ContainerItem.new({
		"global_position_x": 1,
		"global_position_y": 1,
		"global_position_z": 1,
		"itemgroups": ["starting_items"]
	})
	add_child(test_container)
	await get_tree().process_frame

func after_each():
	if test_container:
		test_container.queue_free()

func after_all():
	Runtimedata.reset()
	
#Function tests for the presence of a container
func test_container_is_there()->void:
	var containers: Array = get_tree().get_nodes_in_group("Containers") 
	assert_eq(containers.size(),1,"too many or not enough containers")

# Tests that the provided position is correctly set to the variables
func test_container_position()->void:
	assert_eq(test_container.containerpos,Vector3(1,1,1),"containerpos differs from initial value")
	assert_eq(test_container.position,Vector3(1,1,1),"position differs from initial value")

# Tests that the inventory is properly created
func test_container_has_inventory()->void:
	assert_not_null(test_container.inventory, "No inventory present")

# Tests that the item that is inserted is actually added to the container inventory.
func test_add_item():
	test_container.add_item("long_stick")
	await get_tree().process_frame
	assert_eq(test_container.inventory.has_item_by_id("long_stick"), true, "Failed to add item to container")
