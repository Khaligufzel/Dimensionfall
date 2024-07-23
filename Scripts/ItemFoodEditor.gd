extends Control

# This scene is intended to be used inside the item editor
# It is supposed to edit exactly one type of food


# Form elements
@export var HealthNumberBox: SpinBox = null

var ditem: DItem = null:
	set(value):
		ditem = value
		load_properties()

func save_properties() -> void:
	ditem.food.health = int(HealthNumberBox.value)

func load_properties() -> void:
	HealthNumberBox.value = ditem.food.health
