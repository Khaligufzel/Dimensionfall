extends Area3D


func _on_area_entered(area):
	if area.get_owner().is_in_group("Containers"):
		Helper.signal_broker.container_entered_proximity.emit(area.get_owner())


func _on_area_exited(area):
	var areaowner = area.get_owner()
	if areaowner:
		if areaowner.is_in_group("Containers"):
			Helper.signal_broker.container_exited_proximity.emit(area.get_owner())
