extends SpotLight3D

# This script is used in the main player light that allows him to see
# Here we manipulate the brightness to simulate the time of day.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	%FrontLight.light_color = $day_night.color
