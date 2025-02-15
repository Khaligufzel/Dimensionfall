extends GutTest

var item_wearable_editor: PackedScene = preload("res://Scenes/ContentManager/Custom_Editors/ItemEditor/ItemWearableEditor.tscn")
var editor_instance: Control = null
var myDItem: DItem = null

# Runs before each test.
func before_all():
	var custom_mods: Array[DMod] = [Gamedata.mods.by_id("Core"), Gamedata.mods.by_id("Test")]
	Runtimedata.reconstruct(custom_mods)
	await get_tree().process_frame 

func before_each():
	myDItem = DItem.new({
		"id":"mytestitem",
		"Wearable":{
			"slot":"generic_test_wearable_slot", 
			"player_attributes": [{"id": "generic_test_attribute", "value": 200}]
			}
	}, null)
	
	editor_instance = item_wearable_editor.instantiate()
	get_tree().root.add_child(editor_instance)
	await get_tree().process_frame
	editor_instance.ditem = myDItem

func after_each():
	if editor_instance:
		editor_instance.queue_free()

func after_all():
	Runtimedata.reset()
	
#Function tests for the presence of a container
func test_ditem_is_there()->void:
	# ########################### #
	# ### --- Test basics --- ### #
	
	assert_not_null(editor_instance.ditem, "No ditem present")
	assert_not_null(editor_instance.slot_editor, "No slot_editor present")
	assert_not_null(editor_instance.attributes_container, "No attributes_container present")
	
	# Test that when the DItem is loaded, the slote_editor gets the right value
	assert_eq(editor_instance.slot_editor.get_text(),"generic_test_wearable_slot","expected different slot value")
	# One attribute will create 3 controls, so we check for 3 children
	assert_eq(editor_instance.attributes_container.get_children().size(),3,"No attribute was loaded into the attributes container")
	
	# #####################3################# #
	# ### --- Test dropping slot data --- ### #
	
	# We simulate dropping a wearableslot onto the slot editor
	var dropdata: Dictionary = {
		"id": "drop_test_wearable_slot",
		"text": "Drop test wearable slot",
		"mod_id": "Test",
		"contentType": DMod.ContentType.WEARABLESLOTS
	}
	editor_instance.slot_editor._drop_data(Vector2(0,0),dropdata)
	# Test that when the slot is "dropped", it sets the new slot id
	assert_eq(editor_instance.slot_editor.get_text(),"drop_test_wearable_slot","expected different slot id")
	
	# ################################################### #
	# ### --- Test dropping player attribute data --- ### #
	
	# We simulate dropping a player attribute onto the attribute list
	var attributedropdata: Dictionary = {
		"id": "drop_test_attribute",
		"text": "Drop test attribute",
		"mod_id": "Test",
		"contentType": DMod.ContentType.PLAYERATTRIBUTES
	}
	# The can_drop_attribute should return true
	assert_true(editor_instance.can_drop_attribute(Vector2(0,0),attributedropdata))
	editor_instance.attribute_drop(Vector2(0,0),attributedropdata) # Drop the attribute data
	# One attribute will create 3 controls, so we check for 6 children since we have 2 attributes now
	assert_eq(editor_instance.attributes_container.get_children().size(),6,"Too few attributes in the attributes container")
	
	# ####################################################################### #
	# ### --- Test saving the wearable properties back into the DItem --- ### #
	
	editor_instance.save_properties() # Save the properties from the form into the DItem
	assert_eq(myDItem.wearable.slot,"drop_test_wearable_slot","slot property wasn't saved properly")
	# We initialized with one attribute added one, so we should have 2 now
	assert_eq(myDItem.wearable.player_attributes.size(),2,"Too few attributes in myDItem")
	
	
