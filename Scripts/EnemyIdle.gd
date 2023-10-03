extends State
class_name EnemyIdle

var idle_speed

@export var nav_agent: NavigationAgent3D
@export var stats: NodePath
@export var enemy: NodePath
@export var move_distance: float

@export var moving_timer: Timer


@onready var target_location

var is_looking_to_move = false

var rng = RandomNumberGenerator.new()


func Enter():
	print("Enemy idle")
	idle_speed = get_node(stats).idle_move_speed
	moving_timer.start()
	
func Exit():
	moving_timer.stop()
	
func Physics_Update(delta: float):
	if is_looking_to_move:
		var dir = get_node(enemy).to_local(nav_agent.get_next_path_position()).normalized()
		get_node(enemy).velocity = dir * get_node(stats).current_idle_move_speed
		get_node(enemy).move_and_slide()

	
		if Vector3(get_node(enemy).global_position).distance_to(target_location) <= 0.5:
			is_looking_to_move = false
	


func _on_detection_player_spotted(player):
	Transistioned.emit(self, "enemyfollow")
	

func makepath() -> void:
	nav_agent.target_position = target_location
	#print(nav_agent.target_position)

func _on_moving_cooldown_timeout():
	
	var space_state = get_world_3d().direct_space_state
	var random_dir = Vector3(rng.randf_range(-1,1), get_node(enemy).global_position.y, rng.randf_range(-1, 1))
	var query = PhysicsRayQueryParameters3D.create(get_node(enemy).global_position, get_node(enemy).global_position + (random_dir * move_distance), pow(2, 1-1) + pow(2, 3-1),[self])

	var result = space_state.intersect_ray(query)
	if !result:
		is_looking_to_move = true
		target_location = get_node(enemy).global_position + (random_dir * move_distance)
		makepath()

