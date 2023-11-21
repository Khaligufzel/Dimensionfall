extends Area3D

signal add_to_proximity_inventory
signal remove_from_proximity_inventory
# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


func _on_area_entered(area):
	
	if area.get_owner().is_in_group("Containers"):
		add_to_proximity_inventory.emit(area.get_owner().get_items())
		
	#print(area.get_owner().get_items())

	


func _on_area_exited(area):
	if area.get_owner().is_in_group("Containers"):
		remove_from_proximity_inventory.emit(area.get_owner().get_items())
