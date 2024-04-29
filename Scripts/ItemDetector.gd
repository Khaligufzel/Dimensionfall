extends Area3D

signal add_to_proximity_inventory
signal remove_from_proximity_inventory


func _on_area_entered(area):
	if area.get_owner().is_in_group("Containers"):
		add_to_proximity_inventory.emit(area.get_owner())


func _on_area_exited(area):
	var areaowner = area.get_owner()
	if areaowner:
		if areaowner.is_in_group("Containers"):
			remove_from_proximity_inventory.emit(area.get_owner())
