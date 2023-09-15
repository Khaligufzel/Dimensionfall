extends State
class_name EnemyFollow



@export var nav_agent: NavigationAgent2D
@export var enemy: CharacterBody2D
@export var stats: NodePath

@onready var target_location = enemy.position


func Enter():
	print("DUPA")


func Physics_Update(delta: float):
	var dir = enemy.to_local(nav_agent.get_next_path_position()).normalized()
	enemy.velocity = dir * get_node(stats).current_move_speed
	enemy.move_and_slide()
	
func makepath() -> void:
	nav_agent.target_position = target_location
	
func _on_timer_timeout():
	makepath()



func _on_detection_player_spotted(player):
	target_location = player.position
