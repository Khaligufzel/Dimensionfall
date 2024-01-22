extends Node3D

@export var inventory: NodePath


# Called when the node enters the scene tree for the first time.
func _ready():
	create_random_loot()
	
func create_random_loot():
	if get_node(inventory).get_children() == []:
		var item = get_node(inventory).create_and_add_item("plank_2x4")
		item = get_node(inventory).create_and_add_item("bullet_9mm")
		item = get_node(inventory).create_and_add_item("pistol_magazine")
		item = get_node(inventory).create_and_add_item("steel_scrap")


func get_items():
	return get_node(inventory).get_children()

func get_sprite():
	return $Sprite3D.texture
	
func get_inventory():
	return get_node(inventory)
