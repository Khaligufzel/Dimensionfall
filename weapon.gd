extends Node
class_name Weapon

var id_string
var displayed_name
var description
var used_ammo
var used_magazine
var range
var spread
var sway
var recoil
var used_skill
var reload_speed
var firing_speed
var flags


func create(weapon):
	id_string = weapon["id_string"]
	displayed_name = weapon["displayed_name"]
	description = weapon["description"]
	used_ammo = weapon["used_ammo"]
	used_magazine = weapon["used_magazine"]
	range = weapon["range"]
	spread = weapon["spread"]
	sway = weapon["sway"]
	recoil = weapon["recoil"]
	used_skill = weapon["used_skill"]
	reload_speed = weapon["reload_speed"]
	firing_speed = weapon["firing_speed"]
	flags = weapon["flags"]



# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

