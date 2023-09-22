extends Node2D

@export var inventory: NodePath


# Called when the node enters the scene tree for the first time.
func _ready():
	create_random_loot()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
	
	
func create_random_loot():
	if get_node(inventory).get_children() == []:
		var item = get_node(inventory).create_and_add_item("plank")
		item.set_property("assigned_id", ItemManager.assign_id())
		item = get_node(inventory).create_and_add_item("9mm")
		item.set_property("assigned_id", ItemManager.assign_id())
		item = get_node(inventory).create_and_add_item("pistol_magazine")
		item.set_property("assigned_id", ItemManager.assign_id())
		item = get_node(inventory).create_and_add_item("steel_scrap")
		item.set_property("assigned_id", ItemManager.assign_id())



func get_items():
	return get_node(inventory).get_children()
