extends GutTest

var test_container: ContainerItem
	
# Runs before each test.
func before_all():
	var custom_mods: Array[DMod] = [Gamedata.mods.by_id("Core"), Gamedata.mods.by_id("Test")]
	Runtimedata.reconstruct(custom_mods)
	await get_tree().process_frame 

func before_each():
	test_container = ContainerItem.new({
		"global_position_x": 1,
		"global_position_y": 1,
		"global_position_z": 1,
		"itemgroups": ["generic_test_itemgroup"]
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
	
	# Test that all the relevant data is retrieved
	var container_data: Dictionary = test_container.get_data()
	assert_has(container_data,"global_position_x", "When getting data, cannot find global_position_x")
	assert_has(container_data,"global_position_y", "When getting data, cannot find global_position_y")
	assert_has(container_data,"global_position_z", "When getting data, cannot find global_position_z")
	
	assert_eq(container_data.get("global_position_x", 0), 1.0, "Position differs from actual position")
	assert_eq(container_data.get("global_position_y", 0), 1.0, "Position differs from actual position")
	assert_eq(container_data.get("global_position_z", 0), 1.0, "Position differs from actual position")


# Test that we can apply the itemgroup that was passed as test data
func test_container_create_loot()->void:
	assert_eq(test_container.itemgroup, "generic_test_itemgroup", "Itemgroup differs from expectation")
	
	# Test that the itemgoup conforms to expectation
	var test_itemgroup: RItemgroup = Runtimedata.itemgroups.by_id("generic_test_itemgroup")
	var first_item: RItemgroup.Item = test_itemgroup.items[0] # Itemgroup should have 1 item
	assert_eq(first_item.probability, 100, "Itemgroup's propability isn't 100")
	assert_eq(test_container.ritemgroup, test_itemgroup, "Itemgroup differs from expectation")
	await get_tree().process_frame
	# Check that the inventory actually has the item from the itemgroup
	assert_eq(test_container.inventory.has_item_by_id("generic_test_item"), true, "Failed to add item from itemgroup")


# Tests that the inventory is properly created
func test_container_inventory()->void:
	assert_not_null(test_container.inventory, "No inventory present")

	# Tests that the item that is inserted is actually added to the container inventory.
	test_container.add_item("generic_add_item")
	await get_tree().process_frame
	assert_eq(test_container.inventory.has_item_by_id("generic_add_item"), true, "Failed to add item to container")
	# Since one item was added from generic_test_itemgroup and we also added generic_add_item, we have 2 items
	assert_eq(test_container.get_items().size(), 2, "Too few or too many items in inventory")

	# Test that all the relevant data is retrieved
	var container_data: Dictionary = test_container.get_data()
	assert_has(container_data,"inventory", "When getting data, cannot find inventory")
	var container_inventory_data: Dictionary = container_data.get("inventory", {})
	assert_has(container_inventory_data,"items", "Container inventory data has no items property")
	var container_inventory_items_data: Array = container_inventory_data.get("items", [])
	assert_eq(container_inventory_items_data.size(), 2, "Inventory data has more then 2 or less then 2 items")
