extends Node

var item_id_to_assign = 0



# Called when the node enters the scene tree for the first time.
func _ready():
	save_weapons_in_json()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
	
func assign_id():
	item_id_to_assign += 1
	return item_id_to_assign
	
func get_weapons_from_json():
	pass
	
func save_weapons_in_json():
	
	var weapon = {
		"name": "Pistol",
		"description": "Gun for testing",
		"used_ammo": "9mm",
		"used_magazine": ["Pistol magazine", "Another pistol magazine"],
		"range": "1000",
		"fire_speed": "50",
		"spread": "5",
		"sway": "5",
		"recoil": "20"
	}
	
	
	var weapons_file = FileAccess.open("user://weapons.json", FileAccess.WRITE)
	var data_to_send = weapon
	#var json_string = JSON.stringify(data_to_send)
	weapons_file.store_line(JSON.stringify(data_to_send, "\t"))
	
	weapons_file.close()
	
	
