extends CanvasLayer

@export var head_health: NodePath
@export var right_arm_health: NodePath
@export var left_arm_health: NodePath
@export var torso_health: NodePath
@export var right_leg_health: NodePath
@export var left_leg_health: NodePath

@export var stamina_HUD: NodePath

@export var healthy_color: Color
@export var damaged_color: Color

@export var proximity_inventory: NodePath
@export var proximity_inventory_control: NodePath


func test():
	print("TESTING 123 123!")


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
	var duplicated_items = items.duplicate()
	
	for item in duplicated_items:
		item.get_parent().remove_child(item)
		get_node(proximity_inventory).add_child(item)

	#get_node(proximity_inventory_control).refresh()


func _on_item_detector_remove_from_proximity_inventory(items):
#	for prox_item in get_node(proximity_inventory).get_children():
#		print("test")
#		if prox_item in items:
#			prox_item.queue_free()
	pass
			
	

		
