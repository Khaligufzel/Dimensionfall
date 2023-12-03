extends CanvasLayer

@export var head_health: NodePath
@export var right_arm_health: NodePath
@export var left_arm_health: NodePath
@export var torso_health: NodePath
@export var right_leg_health: NodePath
@export var left_leg_health: NodePath

@export var stamina_HUD: NodePath

@export var ammo_HUD: NodePath

@export var healthy_color: Color
@export var damaged_color: Color

@export var proximity_inventory: NodePath
@export var proximity_inventory_control: NodePath

@export var inventory_control : NodePath
@export var inventory : NodePath

@export var building_menu: NodePath
@export var crafting_menu : NodePath
@export var overmap: Control

var is_building_menu_open = false

@export var tooltip: NodePath
var is_showing_tooltip = false
@export var tooltip_item_name : NodePath
@export var tooltip_item_description : NodePath


@export var progress_bar : NodePath
@export var progress_bar_filling : NodePath
@export var progress_bar_timer : NodePath
var progress_bar_timer_max_time : float

var is_progress_bar_well_progressing_i_guess = false

signal construction_chosen



@export var item_protoset : ItemProtoset

func test():
	print("TESTING 123 123!")


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
		get_node(inventory_control).visible = !get_node(inventory_control).visible
		get_node(proximity_inventory_control).visible = !get_node(proximity_inventory_control).visible
	
	if event.is_action_pressed("crafting_menu"):
		get_node(crafting_menu).visible = !get_node(crafting_menu).visible
	if event.is_action_pressed("overmap"):
		if overmap.visible:
			overmap.hide()
		else:
			overmap.show()
		

# Called when the node enters the scene tree for the first time.
func _ready():
	#temporary hack
	ItemManager.create_item_protoset(item_protoset)
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if is_showing_tooltip:
		get_node(tooltip).visible = true
		get_node(tooltip).global_position = get_node(tooltip).get_global_mouse_position() + Vector2(0, -5 - get_node(tooltip).size.y)
	else:
		get_node(tooltip).visible = false
		
		
		
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




func _on_item_detector_add_to_proximity_inventory(items):
	var duplicated_items = items
	
	for item in duplicated_items:
		var duplicated_item = item.duplicate()
		#duplicated_item.get_parent().remove_child(item)
		get_node(proximity_inventory).add_child(duplicated_item)

	#get_node(proximity_inventory_control).refresh()


func _on_item_detector_remove_from_proximity_inventory(items):
#	for prox_item in get_node(proximity_inventory).get_children():
#		print("test")
#		if prox_item in items:
#			prox_item.queue_free()

	for prox_item in get_node(proximity_inventory).get_children():
		for item in items:
			if item.get_property("assigned_id") == prox_item.get_property("assigned_id"):
				prox_item.queue_free()


func _on_concrete_button_down():
	construction_chosen.emit("concrete_wall")


#func _on_player_shooting_ammo_changed(current_ammo, max_ammo):
#	get_node(ammo_HUD).text = str(current_ammo) + "/" + str(max_ammo)


func _on_inventory_item_mouse_entered(item):
	is_showing_tooltip = true
	get_node(tooltip_item_name).text = str(item.get_property("name", ""))
	get_node(tooltip_item_description).text = item.get_property("description", "")
	
func _on_inventory_item_mouse_exited(item):
	is_showing_tooltip = false

func check_if_resources_are_available(item_id, amount_to_spend: int):
	
	var inventory_node = get_node(inventory)
	print("checking if we have the item id in inv")
	if inventory_node.get_item_by_id(item_id):
		print("we have the item id")
		var item_total_amount : int
		var current_amount_to_spend = amount_to_spend
		var items = inventory_node.get_items_by_id(item_id)
		
		for item in items:
			item_total_amount += inventory_node.get_item_stack_size(item)
			
		if item_total_amount >= current_amount_to_spend:
			return true
		
	return false

func try_to_spend_item(item_id, amount_to_spend : int):
	var inventory_node = get_node(inventory)
	if inventory_node.get_item_by_id(item_id):
		var item_total_amount : int
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
		item = get_node(inventory).create_and_add_item(recipe["crafts"])
		get_node(inventory).set_item_stack_size(item, recipe["craft_amount"])
		


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


func _on_shooting_ammo_changed(current_ammo, max_ammo):
	get_node(ammo_HUD).text = str(current_ammo) + "/" + str(max_ammo)
