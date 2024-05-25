extends Camera3D

var can_zoom: bool = true

func _ready():
	# We connect to the inventory visibility change to interrupt zooming
	Helper.signal_broker.inventory_window_visibility_changed.connect(_on_inventory_visibility_change)

func _input(event):
	if event.is_action_pressed("zoom_in") and can_zoom:
		if(fov > 10):
			fov -= 5
			
	if event.is_action_pressed("zoom_out") and can_zoom:
		if(fov < 75):
			fov += 5

# When the inventory is opened, stop zooming
func _on_inventory_visibility_change(inventoryWindow):
	can_zoom = not inventoryWindow.visible
