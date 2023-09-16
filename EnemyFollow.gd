extends State
class_name EnemyFollow



@export var nav_agent: NavigationAgent2D
@export var enemy: CharacterBody2D
@export var stats: NodePath
@export var pathfinding_timer: Timer

@onready var target_location = enemy.position


func Enter():
	print("Following the player")
	pathfinding_timer.start()
	makepath()

func Exit():
	pathfinding_timer.stop()

func Physics_Update(delta: float):
	var dir = enemy.to_local(nav_agent.get_next_path_position()).normalized()
	enemy.velocity = dir * get_node(stats).current_move_speed
	enemy.move_and_slide()
	
	if Vector2(enemy.global_position).distance_to(target_location) <= 0.5:
		Transistioned.emit(self, "enemyidle") 
	
	
	
func makepath() -> void:
	nav_agent.target_position = target_location
#	print("From follow: ", target_location)
	
func _on_timer_timeout():
	makepath()

func _on_detection_player_spotted(player):
	target_location = player.position
