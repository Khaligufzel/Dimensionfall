extends Area2D

signal update_proximity_inventory
# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_area_entered(area):
	
	if area.get_owner().is_in_group("Containers"):
		update_proximity_inventory.emit(area.get_owner().get_items())
		
	#print(area.get_owner().get_items())
		
