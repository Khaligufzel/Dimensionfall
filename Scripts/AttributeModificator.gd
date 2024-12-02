extends GridContainer

@export var attribute_name_label : Label
@export var attribute_value_label : Label
@export var attribute_modifier_label : Label

var attribute_base_value : int
var attribute_modifier : int



func _ready() -> void:
	attribute_name_label.text = "report me"
	attribute_value_label.text = "report me"
	attribute_modifier_label.text = "I'm a bug"


func modify_attribute() -> void:

	pass

	


func update_attribute_label() -> void:







	pass
