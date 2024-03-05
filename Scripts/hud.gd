extends CanvasLayer

@export var head_health: NodePath
@export var right_arm_health: NodePath
@export var left_arm_health: NodePath
@export var torso_health: NodePath
@export var right_leg_health: NodePath
@export var left_leg_health: NodePath

@export var stamina_HUD: NodePath

@export var ammo_HUD_left: NodePath
@export var ammo_HUD_right: NodePath

@export var healthy_color: Color
@export var damaged_color: Color

# This window shows the inventory to the player
@export var inventoryWindow : Control

@export var building_menu: NodePath
@export var crafting_menu : NodePath
@export var overmap: Control

var is_building_menu_open = false


@export var progress_bar : NodePath
@export var progress_bar_filling : NodePath
@export var progress_bar_timer : NodePath
var progress_bar_timer_max_time : float

var is_progress_bar_well_progressing_i_guess = false

signal construction_chosen
signal item_was_equipped(equippedItem: InventoryItem, slotName: String)
signal item_equipment_slot_was_cleared(slotName: String)



@export var item_protoset : ItemProtoset

func test():
	print("TESTING 123 123!")
	
func _process(_delta):
	if is_progress_bar_well_progressing_i_guess:
		update_progress_bar()


func update_progress_bar():
	var progressBarNode = get_node(progress_bar_filling)
	var timerNode = get_node(progress_bar_timer)
	progressBarNode.scale.x = lerp(1, 0, timerNode.time_left / progress_bar_timer_max_time)

func _input(event):
	if event.is_action_pressed("build_menu"):
		print("Build menu")
		if is_building_menu_open:
			is_building_menu_open = false
			get_node(building_menu).set_visible(false)
		else:
			is_building_menu_open = true
			get_node(building_menu).set_visible(true)
			
	if event.is_action_pressed("toggle_inventory"):
		inventoryWindow.visible = !inventoryWindow.visible

	if event.is_action_pressed("crafting_menu"):
		get_node(crafting_menu).visible = !get_node(crafting_menu).visible
	if event.is_action_pressed("overmap"):
		if overmap.visible:
			overmap.hide()
		else:
			overmap.show()



	if is_progress_bar_well_progressing_i_guess:
		get_node(progress_bar_filling).scale.x = lerp(1, 0, get_node(progress_bar_timer).time_left / progress_bar_timer_max_time)

func _on_player_update_doll(head, right_arm, left_arm, torso, right_leg, left_leg):
	
	get_node(head_health).modulate = lerp(damaged_color, healthy_color, head/100)
	get_node(right_arm_health).modulate = lerp(damaged_color, healthy_color, right_arm/100)
	get_node(left_arm_health).modulate = lerp(damaged_color, healthy_color, left_arm/100)
	get_node(torso_health).modulate = lerp(damaged_color, healthy_color, torso/100)
	get_node(right_leg_health).modulate = lerp(damaged_color, healthy_color, right_leg/100)
	get_node(left_leg_health).modulate = lerp(damaged_color, healthy_color, left_leg/100)

func _on_player_update_stamina_hud(stamina):
	get_node(stamina_HUD).text = str(round(stamina)) + "%"


func _on_concrete_button_down():
	construction_chosen.emit("concrete_wall")


#func _on_player_shooting_ammo_changed(current_ammo, max_ammo):
#	get_node(ammo_HUD).text = str(current_ammo) + "/" + str(max_ammo)

func check_if_resources_are_available(item_id, amount_to_spend: int):
	var inventory_node: InventoryStacked = inventoryWindow.get_inventory()
	print("checking if we have the item id in inv")
	if inventory_node.get_item_by_id(item_id):
		print("we have the item id")
		var item_total_amount : int = 0
		var current_amount_to_spend = amount_to_spend
		var items = inventory_node.get_items_by_id(item_id)
		for item in items:
			item_total_amount += InventoryStacked.get_item_stack_size(item)
		if item_total_amount >= current_amount_to_spend:
			return true
	return false

func try_to_spend_item(item_id, amount_to_spend : int):
	var inventory_node = inventoryWindow.get_inventory()
	if inventory_node.get_item_by_id(item_id):
		var item_total_amount : int = 0
		var current_amount_to_spend = amount_to_spend
		var items = inventory_node.get_items_by_id(item_id)
		
		for item in items:
			item_total_amount += inventory_node.get_item_stack_size(item)
		
		if item_total_amount >= amount_to_spend:
			merge_items_to_total_amount(items, inventory_node, item_total_amount - current_amount_to_spend)
			return true
		else:
			return false
	else:
		return false

func merge_items_to_total_amount(items, inventory, total_amount : int):
	var current_total_amount = total_amount
	for item in items:
		if inventory.get_item_stack_size(item) < current_total_amount:
			if inventory.get_item_stack_size(item) == item.get_property("max_stack_size"):
				current_total_amount -= inventory.get_item_stack_size(item)
			elif inventory.get_item_stack_size(item) < item.get_property("max_stack_size"):
				current_total_amount -= item.get_property("max_stack_size") - inventory.get_item_stack_size(item)
				inventory.set_item_stack_size(item, item.get_property("max_stack_size"))

		elif inventory.get_item_stack_size(item) == current_total_amount:
			current_total_amount = 0

		elif inventory.get_item_stack_size(item) > current_total_amount:
			inventory.set_item_stack_size(item, current_total_amount)
			current_total_amount = 0

			if inventory.get_item_stack_size(item) == 0:
				inventory.remove_item(item)

func _on_crafting_menu_start_craft(recipe):
	
	if recipe:
		#first we need to use required resources for the recipe
		for required_item in recipe["required_resource"]:
			try_to_spend_item(required_item, recipe["required_resource"][required_item])
			
		#adding a new item(s) to the inventory based on the recipe
		var item
		item = inventoryWindow.get_inventory().create_and_add_item(recipe["crafts"])
		inventoryWindow.get_inventory().set_item_stack_size(item, recipe["craft_amount"])

func start_progress_bar(time : float):
	get_node(progress_bar).visible = true
	get_node(progress_bar_timer).wait_time = time
	get_node(progress_bar_timer).start()
	get_node(progress_bar_filling).scale.x = 0
	progress_bar_timer_max_time = time
	is_progress_bar_well_progressing_i_guess = true
	
	
func interrupt_progress_bar():
	get_node(progress_bar).visible = false
	is_progress_bar_well_progressing_i_guess = false


func _on_progress_bar_timer_timeout():
	interrupt_progress_bar()

func _on_shooting_ammo_changed(current_ammo: int, max_ammo: int, leftHand:bool):
	var ammo_HUD: Label = get_node(ammo_HUD_left)
	var prefix: String = "L: "
	if !leftHand:
		ammo_HUD = get_node(ammo_HUD_right)
		prefix = "R: "
	if current_ammo == -1 and max_ammo == -1:  # Assuming -1 is the value when no weapon is equipped
		ammo_HUD.hide()
	else:
		ammo_HUD.text = prefix + str(current_ammo) + "/" + str(max_ammo)
		ammo_HUD.show()


# Called when the users presses the travel button on the overmap
# We save the player inventory to a autoload singleton so we can load it on the next map
func _on_overmap_change_level_pressed():
	General.player_inventory_dict = inventoryWindow.get_inventory().serialize()
	General.player_equipment_dict = inventoryWindow.get_equipment_dict()

# The parameter container the inventory that has entered proximity
func _on_item_detector_add_to_proximity_inventory(container):
	inventoryWindow._on_item_detector_add_to_proximity_inventory(container)

# The parameter container the inventory that has left proximity
func _on_item_detector_remove_from_proximity_inventory(container):
	inventoryWindow._on_item_detector_remove_from_proximity_inventory(container)

# When an item in the inventorywindow was equipped, we pass on the signal
func _on_inventory_window_item_was_equipped(equippedItem, slotName):
	item_was_equipped.emit(equippedItem, slotName)

# slotName can be "LeftHand" or "RightHand"
func _on_inventory_window_item_was_cleared(slotName: String):
	item_equipment_slot_was_cleared.emit(slotName)
