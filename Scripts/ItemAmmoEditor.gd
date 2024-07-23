extends Control

# This scene is intended to be used inside the item editor
# It is supposed to edit exactly one type of ammo


# Form elements
@export var DamageNumberBox: SpinBox = null


var ditem: DItem = null:
	set(value):
		ditem = value
		load_properties()

func save_properties() -> void:
	ditem.ammo.damage = int(DamageNumberBox.value)

func load_properties() -> void:
	DamageNumberBox.value = ditem.ammo.damage
