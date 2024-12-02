extends CanvasModulate
@onready var ani_player = $AnimationPlayer
@onready var timer = $Timer

# This script belongs to `day_night.tscn`
# It will animate the daylight color based on the current time of day
# The color is then read by `front_light.gd` that manipulates the lights' color.


func _ready():
	Helper.time_helper.minute_passed.connect(_on_minute_passed)

func _on_minute_passed(current_time: String):
	# Map the current in-game minutes (0 to 1440) to animation frames (0 to 24)
	var animation_frame = Helper.time_helper.get_time_in_hr()
	
	# Seek the animation to the calculated frame. 
	# The animation has a speed of 0 so it doesn't actually play.
	# This is because when we set the animation frame it might skip to another point and
	# you can see the light flicker because of it.
	ani_player.play("daynight", -1, 0.0)
	ani_player.seek(animation_frame, true, true)
