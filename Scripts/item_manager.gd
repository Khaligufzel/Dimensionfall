extends Node

var item_id_to_assign = 0

var items
var item_json_as_text

var item_protoset : ItemProtoset

@onready var weapon = {
		"id_string": "test_pistol",
		"name": "Pistol",
		"description": "Gun for testing",
		"used_ammo": "9mm",
		"used_magazine": ["pistol_magazine", "another_pistol_magazine"],
		"range": "1000",
		"spread": "5",
		"sway": "5",
		"recoil": "20",
		"used_skill": "short_guns",
		"reload_speed": "2.5",
		"firing_speed": "0.25",
		"flags" : ["ranged_weapon"]
	}
@onready var magazine = {
		"id_string": "pistol_magazine",
		"name": "Pistol magazine",
		"description": "Magazine pistol for testing",
		"used_ammo": "9mm",
		"max_ammo": "20"
	}
@onready var ammo = {
		"id_string": "9mm",
		"name": "9mm",
		"description": "Typical 9mm ammo",
		"damage": "25"
	}

# Called when the node enters the scene tree for the first time.
func _ready():
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
	
func assign_id():
	item_id_to_assign += 1
	return item_id_to_assign
	
func get_weapons_from_json():
	pass
	
func save_weapons_in_json():
	
	var weapons_file = FileAccess.open("user://weapons.json", FileAccess.WRITE)
	var data_to_send = weapon
	#var json_string = JSON.stringify(data_to_send)
	weapons_file.store_line(JSON.stringify(data_to_send, "\t"))
	
	weapons_file.close()
	
	
func get_items_from_json():
	var file = "user://items.json"
	item_json_as_text = FileAccess.get_file_as_string(file)
	var json_as_dict = JSON.parse_string(item_json_as_text)
	items = json_as_dict
	
func create_item_protoset(protoset):
	item_protoset = protoset
	get_items_from_json()
	item_protoset.parse(item_json_as_text)
