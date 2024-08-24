extends Control

# This scene is intended to be used inside the item editor
# It is supposed to edit exactly one type of ammo


# Form elements
@export var DamageNumberBox: SpinBox = null


var ditem: DItem = null:
	set(value):
		if not value:
			return
		ditem = value
		load_properties()

func save_properties() -> void:
	ditem.ammo.damage = int(DamageNumberBox.value)

func load_properties() -> void:
	if not ditem.ammo:
		print_debug("ditem.ammo is null, skipping property loading.")
		return
	DamageNumberBox.value = ditem.ammo.damage
