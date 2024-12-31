extends GridContainer


var is_building_menu_open = false
signal construction_chosen

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _on_concrete_button_down():
	construction_chosen.emit("concrete_wall")
