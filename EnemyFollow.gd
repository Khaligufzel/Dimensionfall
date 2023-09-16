extends State
class_name EnemyFollow



@export var nav_agent: NavigationAgent2D
@export var enemy: CharacterBody2D
@export var enemyCol: NodePath
@export var stats: NodePath
@export var pathfinding_timer: Timer

var targeted_player

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
	
	
	var space_state = get_world_2d().direct_space_state
	# TO-DO Change playerCol to group of players
	var query = PhysicsRayQueryParameters2D.create(get_node(enemyCol).global_position, targeted_player.global_position, pow(2, 1-1) + pow(2, 3-1),[self])
	var result = space_state.intersect_ray(query)
	
	
	if result:
		
		if result.collider.is_in_group("Players")&& Vector2(get_node(enemyCol).global_position).distance_to(targeted_player.global_position) <= get_node(stats).melee_range / 2:
			print("changing state to enemyattack...")
			Transistioned.emit(self, "enemyattack")
	
	
	
	
	if Vector2(enemy.global_position).distance_to(target_location) <= 0.5:
		Transistioned.emit(self, "enemyidle") 
	
	
	
func makepath() -> void:
	nav_agent.target_position = target_location
#	print("From follow: ", target_location)
	
func _on_timer_timeout():
	makepath()

func _on_detection_player_spotted(player):
	target_location = player.position
	targeted_player = player
