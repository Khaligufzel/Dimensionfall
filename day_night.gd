extends CanvasModulate
@onready var ani_player = $AnimationPlayer
@onready var timer = $Timer

func _process(delta) -> void:
	var time_passed = timer.wait_time - timer.time_left
	var animation_frame = remap(time_passed, 0, timer.wait_time, 0, 24)
	print(animation_frame)
	ani_player.play("daynight")
	ani_player.seek(animation_frame)
