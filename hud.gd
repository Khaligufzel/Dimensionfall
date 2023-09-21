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

@export var building_menu: NodePath

var is_building_menu_open = false

signal construction_chosen


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
		

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


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


func _on_player_shooting_ammo_changed(current_ammo, max_ammo):
	get_node(ammo_HUD).text = str(current_ammo) + "/" + str(max_ammo)
