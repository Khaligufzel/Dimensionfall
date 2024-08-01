extends State
class_name MobTerminate

# This script is an extention of State. It's a state that a mob can be in.
# This is the final state of the mob and it will not transition back to another state
# This is useful to disable the mob before queueing it free


var mob: CharacterBody3D # The mob we provide terminate behavour for

func Enter():
	print("Entering MobTerminate state")
	# Disable navigation and any other behaviors

func Exit():
	pass

func Physics_Update(_delta: float):
	pass

func _on_detection_player_spotted(_player):
	pass
