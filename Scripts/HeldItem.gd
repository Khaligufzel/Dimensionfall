extends Node2D

var weapon = {}
var magazine = {}
var ammo = {}



# Called when the node enters the scene tree for the first time.
func _ready():
	weapon = ItemManager.weapon
	magazine = ItemManager.magazine
	ammo = ItemManager.ammo


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
