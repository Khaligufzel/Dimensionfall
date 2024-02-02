extends Node

var playerInventory: InventoryStacked = null


func _ready():
	playerInventory = InventoryStacked.new()
	playerInventory.capacity = 1000
	playerInventory.item_protoset = load("res://ItemProtosets.tres")
	create_starting_items()
	

func create_starting_items():
	if playerInventory.get_children() == []:
		playerInventory.create_and_add_item("pistol_9mm")
		playerInventory.create_and_add_item("pistol_9mm")
		playerInventory.create_and_add_item("bullet_9mm")
		playerInventory.create_and_add_item("pistol_magazine")
		playerInventory.create_and_add_item("pistol_magazine")
		playerInventory.create_and_add_item("pistol_magazine")
		playerInventory.create_and_add_item("rifle_m4a1")
