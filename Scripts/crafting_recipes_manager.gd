extends Node

var crafting_recipes


# Called when the node enters the scene tree for the first time.
func _ready():
	get_crafting_recipes_from_json()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
	
func get_crafting_recipes_from_json():
	var file = "res://JSON/crafting_recipes.json"
	var json_as_text = FileAccess.get_file_as_string(file)
	var json_as_dict = JSON.parse_string(json_as_text)
	crafting_recipes = json_as_dict
