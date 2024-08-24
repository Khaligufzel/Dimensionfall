extends Control

# This scene is intended to be used inside the item editor
# It is supposed to edit exactly one magazine


# Form elements
@export var UsedAmmoTextEdit: TextEdit = null
@export var MaxAmmoNumberBox: SpinBox = null
@export var CurrentAmmoNumberBox: SpinBox = null


var ditem: DItem = null:
	set(value):
		if not value:
			return
		ditem = value
		load_properties()

func save_properties() -> void:
	ditem.magazine.used_ammo = UsedAmmoTextEdit.text
	ditem.magazine.max_ammo = int(MaxAmmoNumberBox.value)
	ditem.magazine.current_ammo = int(CurrentAmmoNumberBox.value)

func load_properties() -> void:
	if not ditem.magazine:
		print_debug("ditem.magazine is null, skipping property loading.")
		return
	UsedAmmoTextEdit.text = ditem.magazine.used_ammo
	MaxAmmoNumberBox.value = ditem.magazine.max_ammo
	CurrentAmmoNumberBox.value = ditem.magazine.current_ammo
