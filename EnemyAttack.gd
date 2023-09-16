extends State
class_name EnemyAttack

@export var stats: NodePath
@export var attack_timer: Timer
@export var enemy: NodePath
@export var enemy_sprite: NodePath

var tween: Tween

var targeted_player

var is_in_attack_mode = false

func Enter():
	attack_timer.start()
	print("ENTERING BATTLE MODE")
	
func Exit():
	pass
	
func Physics_Update(delta: float):
	
	
	var space_state = get_world_2d().direct_space_state
	# TO-DO Change playerCol to group of players
	var query = PhysicsRayQueryParameters2D.create(get_node(enemy).global_position, targeted_player.global_position, pow(2, 1-1) + pow(2, 3-1), [self])
	var result = space_state.intersect_ray(query)
	

	if result:

		if result.collider.is_in_group("Players") && Vector2(get_node(enemy).global_position).distance_to(targeted_player.global_position) <= get_node(stats).melee_range:

			if !is_in_attack_mode:
				is_in_attack_mode = true
				try_to_attack()			
		else:
			is_in_attack_mode = false
			stop_attacking()
	else:
		is_in_attack_mode = false
		stop_attacking()
		
func try_to_attack():
	print("Trying to attack...")
	attack_timer.start()


func attack():
	print("Attacking!")
	
	tween = create_tween()
	tween.tween_property(get_node(enemy_sprite), "position", Vector2(20,0), 0.1 )
	tween.tween_property(get_node(enemy_sprite), "position", Vector2(0,0), 0.1 )
	
	
func stop_attacking():
	print("I stopped attacking")
	attack_timer.stop()
	Transistioned.emit(self, "enemyfollow")


func _on_detection_player_spotted(player):
	targeted_player = player # Replace with function body.


func _on_attack_cooldown_timeout():
	attack()
