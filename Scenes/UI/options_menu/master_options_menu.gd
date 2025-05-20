extends MasterOptionsMenu
# This export variable is overwritten in the escape menu scene
@export var settings_location: String = "Settings menu"

# We can access the options menu from the main menu and the escape menu
# Handle the back button response based on where we access the options menu from
func _on_back_button_pressed():
	if settings_location == "Escape menu":
		hide()
	elif settings_location == "Settings menu": # Default value
		get_tree().change_scene_to_file("res://scene_selector.tscn")
		
